from app import app, db
from models import User

with app.app_context():
    # Buscar o usuário admin
    admin = User.query.filter_by(username='admin').first()
    
    if admin:
        # Atualizar a senha para 'admin'
        admin.set_password('admin')
        db.session.commit()
        
        print("Senha do usuário admin atualizada com sucesso!")
        print("Username: admin")
        print("Password: admin")
        print(f"Email: {admin.email}")
        print(f"Is Admin: {admin.is_admin}")
    else:
        print("Usuário admin não encontrado!")
