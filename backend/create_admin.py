from app import app, db
from models import User

with app.app_context():
    # Verificar se o usuário admin já existe
    existing_admin = User.query.filter_by(username='admin').first()
    
    if existing_admin:
        print("Usuário admin já existe!")
        print(f"Email: {existing_admin.email}")
        print(f"Is Admin: {existing_admin.is_admin}")
    else:
        # Criar novo usuário admin
        admin = User(
            username='admin',
            email='admin@admin.com',
            is_admin=True
        )
        admin.set_password('admin')
        
        db.session.add(admin)
        db.session.commit()
        
        print("Usuário admin criado com sucesso!")
        print("Username: admin")
        print("Password: admin")
        print("Email: admin@admin.com")
        print("Is Admin: True")
