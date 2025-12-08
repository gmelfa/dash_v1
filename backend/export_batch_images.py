from flask import Blueprint, request, jsonify, send_file
from flask_login import login_required
from models import Comment
from io import BytesIO
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from PIL import Image

export_batch_bp = Blueprint('export_batch', __name__, url_prefix='/api/export')

@export_batch_bp.route('/pptx/batch-images', methods=['POST'])
@login_required
def export_batch_with_images():
    """
    Exporta múltiplas queries em um único PowerPoint usando imagens das tabelas
    Recebe: FormData com query_count, query_id_N, query_title_N, table_image_N
    Retorna: PowerPoint com slide de capa + um slide por query (com imagem)
    """
    try:
        # Obter número de queries
        query_count = int(request.form.get('query_count', 0))
        print(f"DEBUG: Batch export with {query_count} queries")
        
        if query_count == 0:
            return jsonify({'error': 'Nenhuma query fornecida'}), 400
        
        # Criar apresentação
        prs = Presentation()
        prs.slide_width = 9144000   # 10 polegadas em EMU
        prs.slide_height = 6858000  # 7.5 polegadas em EMU
        
        # ===== SLIDE DE CAPA (Removido - vem do frontend) =====
        # O frontend agora envia a capa como o primeiro slide (imagem)
        print("DEBUG: Cover slide will be generated from frontend image")
        
        # ===== PROCESSAR CADA QUERY =====
        for i in range(query_count):
            try:
                query_id = request.form.get(f'query_id_{i}')
                query_title = request.form.get(f'query_title_{i}')
                table_image_file = request.files.get(f'table_image_{i}')
                
                if not all([query_id, query_title, table_image_file]):
                    print(f"WARN: Missing data for query {i}, skipping")
                    continue
                
                print(f"DEBUG: Processing query {i}: {query_id}")
                
                # Ler imagem
                image_bytes = table_image_file.read()
                image_stream = BytesIO(image_bytes)
                
                # Criar slide
                slide_layout = prs.slide_layouts[6]  # Blank
                slide = prs.slides.add_slide(slide_layout)
                
                # Adicionar título
                title_shape = slide.shapes.add_textbox(
                    int(Inches(0.5)), int(Inches(0.3)), 
                    int(Inches(9)), int(Inches(0.5))
                )
                title_frame = title_shape.text_frame
                title_frame.text = query_title
                title_frame.paragraphs[0].font.size = Pt(28)
                title_frame.paragraphs[0].font.bold = True
                title_frame.paragraphs[0].font.color.rgb = RGBColor(30, 58, 95)
                
                # Adicionar imagem da tabela com escala inteligente
                image_stream.seek(0)
                with Image.open(image_stream) as img:
                    img_w, img_h = img.size
                image_stream.seek(0)
                
                # Lógica especial para CAPA (query_id == 'cover')
                if query_id == 'cover':
                    # Capa ocupa o slide todo
                    slide.shapes.add_picture(
                        image_stream,
                        0, 0,
                        width=prs.slide_width,
                        height=prs.slide_height
                    )
                    # Não adiciona título nem comentários na capa
                    continue

                # Lógica para slides normais (com margens seguras)
                max_width = int(Inches(9.5))   # Largura máxima
                max_height = int(Inches(5.0))  # Altura máxima REDUZIDA para evitar corte inferior
                
                # Calcular proporções
                width_ratio = max_width / img_w
                height_ratio = max_height / img_h
                
                # Escolher a menor proporção
                scale = min(width_ratio, height_ratio)
                
                final_width = int(img_w * scale)
                final_height = int(img_h * scale)
                
                # Centralizar horizontalmente
                left = int((prs.slide_width - final_width) / 2)
                top = int(Inches(1.1)) # Logo abaixo do título
                
                slide.shapes.add_picture(
                    image_stream,
                    left, top,
                    width=final_width,
                    height=final_height
                )
                
                # Buscar comentários
                comments = Comment.query.filter_by(query_id=query_id).order_by(Comment.created_at).all()
                
                # Adicionar informação de comentários se houver
                if comments:
                    comment_shape = slide.shapes.add_textbox(
                        int(Inches(0.5)), int(Inches(6.8)), 
                        int(Inches(9)), int(Inches(0.4))
                    )
                    comment_frame = comment_shape.text_frame
                    comment_frame.word_wrap = True
                    
                    # Separar comentários
                    approved_comments = [c for c in comments if c.status == 'approved']
                    pending_or_rejected_count = sum(1 for c in comments if c.status != 'approved')
                    
                    lines = []
                    
                    # 1. Mostrar contagem de não aprovados (se houver)
                    if pending_or_rejected_count > 0:
                        lines.append(f"⚠️ {pending_or_rejected_count} comentário(s) não aprovado(s)")
                    
                    # 2. Mostrar conteúdo dos aprovados
                    for comment in approved_comments:
                        # Formato: "Nome: Conteúdo"
                        author_name = comment.author.username if comment.author else "Desconhecido"
                        lines.append(f"👤 {author_name}: {comment.content}")
                    
                    if not lines:
                        lines.append("Nenhum comentário visível")

                    comment_frame.text = "\n".join(lines)
                    
                    # Ajustar formatação
                    for paragraph in comment_frame.paragraphs:
                        paragraph.font.size = Pt(10)
                        paragraph.font.italic = True
                        paragraph.font.color.rgb = RGBColor(80, 80, 80) # Cinza escuro para leitura melhor
                
                print(f"DEBUG: Slide created for query {query_id}")
                
            except Exception as e:
                print(f"ERROR processing query {i}: {str(e)}")
                import traceback
                traceback.print_exc()
                continue
        
        # Salvar PowerPoint
        pptx_bytes = BytesIO()
        prs.save(pptx_bytes)
        pptx_bytes.seek(0)
        
        print(f"DEBUG: PowerPoint generated, size: {pptx_bytes.getbuffer().nbytes} bytes")
        
        return send_file(
            pptx_bytes,
            mimetype='application/vnd.openxmlformats-officedocument.presentationml.presentation',
            as_attachment=True,
            download_name='export_batch.pptx'
        )
        
    except Exception as e:
        print(f"ERROR in export_batch_with_images: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
