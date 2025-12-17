from flask import Blueprint, request, jsonify, send_file
from flask_login import login_required
from models import Comment
from io import BytesIO
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from PIL import Image

export_batch_bp = Blueprint('export_batch', __name__, url_prefix='/api/export')

@export_batch_bp.route('/pptx/batch-images', methods=['POST'])
@login_required
def export_batch_with_images():
    """
    Exporta PPTX com Layout Híbrido Automático:
    - Tabelas Largas (> 1.2 aspect ratio) -> Layout Topo (Full Width)
    - Tabelas Altas/Quadradas -> Layout Lateral (Dashboard)
    """
    try:
        query_count = int(request.form.get('query_count', 0))
        
        if query_count == 0:
            return jsonify({'error': 'Nenhuma query fornecida'}), 400
        
        # Criar apresentação
        prs = Presentation()
        prs.slide_width = 9144000   # 10 polegadas (largura)
        prs.slide_height = 6858000  # 7.5 polegadas (altura)
        
        # Slide Ratio (4:3 = 1.333)
        # Se a imagem tiver ratio maior que 1.25, consideramos ela "Larga"
        THRESHOLD_RATIO = 1.25

        for i in range(query_count):
            try:
                query_id = request.form.get(f'query_id_{i}')
                query_title = request.form.get(f'query_title_{i}')
                table_image_file = request.files.get(f'table_image_{i}')
                
                if not all([query_id, query_title, table_image_file]):
                    continue
                
                # Ler imagem e descobrir dimensões
                image_bytes = table_image_file.read()
                image_stream = BytesIO(image_bytes)
                
                with Image.open(image_stream) as img:
                    img_w, img_h = img.size
                    img_ratio = img_w / img_h
                
                # Resetar stream para leitura pelo PPTX
                image_stream.seek(0)
                
                # Adicionar Slide em Branco
                slide = prs.slides.add_slide(prs.slide_layouts[6])

                # --- CAPA ---
                if query_id == 'cover':
                    slide.shapes.add_picture(image_stream, 0, 0, width=prs.slide_width, height=prs.slide_height)
                    continue

                # =========================================================
                # DECISÃO DE LAYOUT BASEADA NA IMAGEM
                # =========================================================
                
                if img_ratio > THRESHOLD_RATIO:
                    # -----------------------------------------------------
                    # LAYOUT A: FULL WIDTH (Para Tabelas Grandes/Largas)
                    # Título no Topo | Tabela no Meio | Comentários no Rodapé
                    # -----------------------------------------------------
                    MARGIN_X = Inches(0.25)
                    TITLE_TOP = Inches(0.15)
                    
                    # 1. Título Topo
                    title_shape = slide.shapes.add_textbox(MARGIN_X, TITLE_TOP, prs.slide_width - (MARGIN_X*2), Inches(0.7))
                    tf = title_shape.text_frame
                    tf.text = query_title
                    p = tf.paragraphs[0]
                    p.font.size = Pt(22)
                    p.font.bold = True
                    p.font.name = 'Arial'
                    p.font.color.rgb = RGBColor(30, 58, 95)
                    p.alignment = PP_ALIGN.LEFT

                    # 2. Tabela Larga
                    TABLE_TOP = Inches(0.9)
                    MAX_H = prs.slide_height - TABLE_TOP - Inches(0.8) # Reserva rodapé
                    
                    pic = slide.shapes.add_picture(image_stream, MARGIN_X, TABLE_TOP, width=prs.slide_width - (MARGIN_X*2))
                    
                    # Ajuste fino se estourar altura
                    if pic.height > MAX_H:
                        pic.height = MAX_H
                        pic.left = int((prs.slide_width - pic.width) / 2)

                    # 3. Comentários Rodapé
                    footer_top = prs.slide_height - Inches(0.7)
                    _add_comments_footer(slide, query_id, MARGIN_X, footer_top, prs.slide_width - (MARGIN_X*2))

                else:
                    # -----------------------------------------------------
                    # LAYOUT B: DASHBOARD LATERAL (Para Tabelas Altas/Quadradas)
                    # Esquerda: Título e Comentários | Direita: Tabela Cheia
                    # -----------------------------------------------------
                    SIDEBAR_W = Inches(2.5)
                    MARGIN = Inches(0.2)
                    
                    # 1. Título Esquerda
                    title_shape = slide.shapes.add_textbox(MARGIN, MARGIN, SIDEBAR_W - MARGIN, Inches(2.0))
                    tf = title_shape.text_frame
                    tf.word_wrap = True
                    tf.text = query_title
                    p = tf.paragraphs[0]
                    p.font.size = Pt(24)
                    p.font.bold = True
                    p.font.name = 'Arial'
                    p.font.color.rgb = RGBColor(30, 58, 95)
                    
                    # 2. Comentários Esquerda (Abaixo do título)
                    _add_comments_sidebar(slide, query_id, MARGIN, Inches(1.8), SIDEBAR_W - MARGIN, prs.slide_height)

                    # 3. Tabela Direita (Ocupando altura máxima)
                    TABLE_LEFT = SIDEBAR_W + MARGIN
                    TABLE_MAX_W = prs.slide_width - SIDEBAR_W - (MARGIN*2)
                    TABLE_MAX_H = prs.slide_height - (MARGIN*2)
                    
                    pic = slide.shapes.add_picture(image_stream, TABLE_LEFT, MARGIN, width=TABLE_MAX_W)
                    
                    # Se estourar altura, ajusta
                    if pic.height > TABLE_MAX_H:
                        pic.height = TABLE_MAX_H
                    
                    # Linha Divisória
                    line = slide.shapes.add_connector(1, SIDEBAR_W, MARGIN, SIDEBAR_W, prs.slide_height - MARGIN)
                    line.line.color.rgb = RGBColor(200, 200, 200)

            except Exception as e:
                print(f"Erro processando query {i}: {e}")
                continue
        
        # Salvar
        pptx_bytes = BytesIO()
        prs.save(pptx_bytes)
        pptx_bytes.seek(0)
        
        return send_file(
            pptx_bytes,
            mimetype='application/vnd.openxmlformats-officedocument.presentationml.presentation',
            as_attachment=True,
            download_name='export_hybrid.pptx'
        )

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Funções Auxiliares para Limpar o Código Principal ---

def _add_comments_footer(slide, query_id, left, top, width):
    """Adiciona comentários em linha única no rodapé (Layout A)"""
    comments = Comment.query.filter_by(query_id=query_id).order_by(Comment.created_at).all()
    approved = [c for c in comments if c.status == 'approved']
    
    if approved:
        shape = slide.shapes.add_textbox(left, top, width, Inches(0.6))
        tf = shape.text_frame
        tf.word_wrap = True
        
        lines = [f"{c.author.username if c.author else 'User'}: {c.content}" for c in approved]
        text = "  |  ".join(lines)
        
        tf.text = text
        for p in tf.paragraphs:
            p.font.size = Pt(10)
            p.font.color.rgb = RGBColor(100, 100, 100)

def _add_comments_sidebar(slide, query_id, left, top, width, slide_height):
    """Adiciona comentários empilhados na lateral (Layout B)"""
    comments = Comment.query.filter_by(query_id=query_id).order_by(Comment.created_at).all()
    approved = [c for c in comments if c.status == 'approved']
    
    if approved:
        height = slide_height - top - Inches(0.2)
        shape = slide.shapes.add_textbox(left, top, width, height)
        tf = shape.text_frame
        tf.word_wrap = True
        
        p_head = tf.add_paragraph()
        p_head.text = "Comentários:"
        p_head.font.bold = True
        p_head.font.size = Pt(11)
        p_head.font.color.rgb = RGBColor(80, 80, 80)
        p_head.space_after = Pt(6)

        for c in approved:
            author = c.author.username if c.author else "User"
            
            p_auth = tf.add_paragraph()
            p_auth.text = f"👤 {author}:"
            p_auth.font.bold = True
            p_auth.font.size = Pt(10)
            p_auth.font.color.rgb = RGBColor(37, 99, 235)
            
            p_content = tf.add_paragraph()
            p_content.text = c.content
            p_content.font.size = Pt(10)
            p_content.font.color.rgb = RGBColor(60, 60, 60)
            p_content.space_after = Pt(10)