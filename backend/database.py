from models import db, User
from sqlalchemy import text
from datetime import timedelta
import os

def init_db(app):
    """Inicializa o banco de dados"""
    basedir = os.path.abspath(os.path.dirname(__file__))
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(basedir, "database.db")}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')

    # Sessão expira após 30 dias
    app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)

    # Configurações de sessão para CORS
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
    app.config['SESSION_COOKIE_SECURE'] = False  # True em produção com HTTPS
    app.config['SESSION_COOKIE_HTTPONLY'] = True

    db.init_app(app)

    with app.app_context():
        db.create_all()

        # Migração: adicionar is_approved se não existir (banco legado)
        with db.engine.connect() as conn:
            try:
                conn.execute(text('ALTER TABLE users ADD COLUMN is_approved BOOLEAN DEFAULT 0'))
                conn.commit()
                # Aprovar todos os usuários existentes (já estavam ativos antes da feature)
                conn.execute(text('UPDATE users SET is_approved = 1'))
                conn.commit()
                print("✓ Migração: coluna is_approved adicionada e usuários existentes aprovados")
            except Exception:
                pass  # Coluna já existe

        # Criar usuário admin padrão se não existir
        admin = User.query.filter_by(username='admin').first()
        if not admin:
            admin = User(
                username='admin',
                email='admin@gruposeb.com',
                is_admin=True,
                is_approved=True
            )
            admin.set_password('admin123')
            db.session.add(admin)
            db.session.commit()
            print("✓ Usuário admin criado (username: admin, password: admin123)")
        elif not admin.is_approved:
            admin.is_approved = True
            db.session.commit()

        print("[OK] Banco de dados inicializado")
