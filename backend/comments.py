from flask import Blueprint, request, jsonify
from flask_login import login_required, current_user
from models import db, Comment
from datetime import datetime

comments_bp = Blueprint('comments', __name__, url_prefix='/api/comments')

@comments_bp.route('/query/<path:query_id>', methods=['GET'])
def get_comments_by_query(query_id):
    """Retorna todos os comentários de uma query"""
    try:
        comments = Comment.query.filter_by(query_id=query_id).order_by(Comment.created_at.desc()).all()
        return jsonify({
            'comments': [comment.to_dict() for comment in comments],
            'total': len(comments)
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@comments_bp.route('/', methods=['POST'])
@login_required
def create_comment():
    """Cria um novo comentário"""
    try:
        data = request.json
        
        # Validação
        if 'query_id' not in data or 'content' not in data:
            return jsonify({'error': 'query_id e content são obrigatórios'}), 400
        
        if not data['content'].strip():
            return jsonify({'error': 'Comentário não pode estar vazio'}), 400
        
        # Criar comentário
        comment = Comment(
            query_id=data['query_id'],
            user_id=current_user.id,
            content=data['content'].strip(),
            status='pending'
        )
        
        db.session.add(comment)
        db.session.commit()
        
        return jsonify({
            'message': 'Comentário criado com sucesso',
            'comment': comment.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@comments_bp.route('/<int:comment_id>', methods=['PUT'])
@login_required
def update_comment(comment_id):
    """Atualiza um comentário (próprio usuário ou admin)"""
    try:
        comment = Comment.query.get(comment_id)
        
        if not comment:
            return jsonify({'error': 'Comentário não encontrado'}), 404
        
        # Verificar permissão
        if comment.user_id != current_user.id and not current_user.is_admin:
            return jsonify({'error': 'Sem permissão para editar este comentário'}), 403
        
        data = request.json
        
        # Usuário normal só pode editar o conteúdo
        if not current_user.is_admin:
            if 'content' in data:
                comment.content = data['content'].strip()
        else:
            # Admin pode editar tudo
            if 'content' in data:
                comment.content = data['content'].strip()
            
            if 'status' in data:
                comment.status = data['status']
            
            if 'edited_content' in data:
                comment.edited_content = data['edited_content'].strip() if data['edited_content'] else None
                comment.edited_by = current_user.id
                comment.edited_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'message': 'Comentário atualizado com sucesso',
            'comment': comment.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@comments_bp.route('/<int:comment_id>', methods=['DELETE'])
@login_required
def delete_comment(comment_id):
    """Deleta um comentário (próprio usuário ou admin)"""
    try:
        comment = Comment.query.get(comment_id)
        
        if not comment:
            return jsonify({'error': 'Comentário não encontrado'}), 404
        
        # Verificar permissão
        if comment.user_id != current_user.id and not current_user.is_admin:
            return jsonify({'error': 'Sem permissão para deletar este comentário'}), 403
        
        db.session.delete(comment)
        db.session.commit()
        
        return jsonify({'message': 'Comentário deletado com sucesso'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@comments_bp.route('/query/<path:query_id>/approved', methods=['GET'])
def get_approved_comments(query_id):
    """Retorna apenas comentários aprovados de uma query"""
    try:
        comments = Comment.query.filter_by(
            query_id=query_id,
            status='approved'
        ).order_by(Comment.created_at).all()
        
        return jsonify({
            'comments': [comment.to_dict() for comment in comments],
            'total': len(comments)
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@comments_bp.route('/query/<path:query_id>/batch-update', methods=['POST'])
@login_required
def batch_update_comments(query_id):
    """Atualiza múltiplos comentários de uma vez (apenas admin)"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403
    
    try:
        data = request.json
        updates = data.get('updates', [])
        
        for update in updates:
            comment_id = update.get('id')
            comment = Comment.query.get(comment_id)
            
            if comment and comment.query_id == query_id:
                if 'status' in update:
                    comment.status = update['status']
                
                if 'edited_content' in update:
                    comment.edited_content = update['edited_content']
                    comment.edited_by = current_user.id
                    comment.edited_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({'message': f'{len(updates)} comentários atualizados'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
