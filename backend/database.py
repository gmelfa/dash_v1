from models import db, User
import os

def init_db(app):
    """Inicializa o banco de dados"""
    # Configuração do SQLAlchemy
    basedir = os.path.abspath(os.path.dirname(__file__))
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(basedir, "database.db")}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    
    # Configurações de sessão para CORS
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
    app.config['SESSION_COOKIE_SECURE'] = False  # True em produção com HTTPS
    app.config['SESSION_COOKIE_HTTPONLY'] = True
    
    db.init_app(app)
    
    with app.app_context():
        # Criar todas as tabelas
        db.create_all()
        
        # Criar usuário admin padrão se não existir
        admin = User.query.filter_by(username='admin').first()
        if not admin:
            admin = User(
                username='admin',
                email='admin@gruposeb.com',
                is_admin=True
            )
            admin.set_password('admin123')  # Trocar na produção!
            db.session.add(admin)
            db.session.commit()
            print("✓ Usuário admin criado (username: admin, password: admin123)")
        
        print("✓ Banco de dados inicializado")
