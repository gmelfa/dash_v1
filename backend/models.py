from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

db = SQLAlchemy()

class User(UserMixin, db.Model):
    """Modelo de usuário para autenticação"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relacionamento com comentários
    comments = db.relationship('Comment', backref='author', lazy=True, foreign_keys='Comment.user_id')
    edited_comments = db.relationship('Comment', backref='editor', lazy=True, foreign_keys='Comment.edited_by')
    
    def set_password(self, password):
        """Hash da senha"""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        """Verifica senha"""
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        """Serializa para JSON"""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'is_admin': self.is_admin,
            'created_at': self.created_at.isoformat()
        }


class Comment(db.Model):
    """Modelo de comentários vinculados a queries"""
    __tablename__ = 'comments'
    
    id = db.Column(db.Integer, primary_key=True)
    query_id = db.Column(db.String(100), nullable=False, index=True)  # ID da query (ex: "resultado_10_2025")
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='pending', index=True)  # pending, approved, rejected
    
    # Campos para edição pelo gestor
    edited_content = db.Column(db.Text, nullable=True)
    edited_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    edited_at = db.Column(db.DateTime, nullable=True)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Índice composto para performance com 100+ queries
    __table_args__ = (
        db.Index('idx_query_status', 'query_id', 'status'),
    )
    
    def to_dict(self):
        """Serializa para JSON"""
        return {
            'id': self.id,
            'query_id': self.query_id,
            'user_id': self.user_id,
            'username': self.author.username,
            'content': self.content,
            'status': self.status,
            'edited_content': self.edited_content,
            'edited_by': self.edited_by,
            'edited_by_username': self.editor.username if self.editor else None,
            'edited_at': self.edited_at.isoformat() if self.edited_at else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
