from flask import Blueprint, request, jsonify
from flask_login import login_user, logout_user, login_required, current_user
from models import db, User

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

@auth_bp.route('/register', methods=['POST'])
def register():
    """Registra novo usuário"""
    try:
        data = request.json
        print(f"[DEBUG] Dados recebidos para registro: {data}")
        
        # Validação
        required_fields = ['username', 'email', 'password']
        for field in required_fields:
            if field not in data:
                print(f"[DEBUG] Campo ausente: {field}")
                return jsonify({'error': f'Campo obrigatório: {field}'}), 400
        
        # Verificar se usuário já existe
        if User.query.filter_by(username=data['username']).first():
            print(f"[DEBUG] Username já existe: {data['username']}")
            return jsonify({'error': 'Username já existe'}), 400
        
        if User.query.filter_by(email=data['email']).first():
            print(f"[DEBUG] Email já cadastrado: {data['email']}")
            return jsonify({'error': 'Email já cadastrado'}), 400
        
        # Criar novo usuário
        user = User(
            username=data['username'],
            email=data['email'],
            is_admin=data.get('is_admin', False)  # Apenas admin pode criar outro admin
        )
        user.set_password(data['password'])
        
        db.session.add(user)
        db.session.commit()
        
        print(f"[DEBUG] Usuário criado com sucesso: {user.username}")
        
        return jsonify({
            'message': 'Usuário criado com sucesso',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Erro ao registrar usuário: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/login', methods=['POST'])
def login():
    """Login de usuário"""
    try:
        data = request.json
        print(f"[DEBUG] Tentativa de login - dados recebidos: {data}")
        
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            print("[DEBUG] Username ou senha não fornecidos")
            return jsonify({'error': 'Username e senha são obrigatórios'}), 400
        
        # Buscar usuário por username ou email
        user = User.query.filter(
            (User.username == username) | (User.email == username)
        ).first()
        print(f"[DEBUG] Usuário encontrado: {user.username if user else 'None'}")
        
        if not user:
            print("[DEBUG] Usuário não encontrado")
            return jsonify({'error': 'Credenciais inválidas'}), 401
            
        if not user.check_password(password):
            print(f"[DEBUG] Senha incorreta para usuário: {username}")
            return jsonify({'error': 'Credenciais inválidas'}), 401
        
        # Fazer login
        print(f"[DEBUG] Login bem-sucedido para: {username}")
        login_user(user, remember=True)
        
        return jsonify({
            'message': 'Login realizado com sucesso',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/logout', methods=['POST'])
@login_required
def logout():
    """Logout de usuário"""
    logout_user()
    return jsonify({'message': 'Logout realizado com sucesso'}), 200


@auth_bp.route('/me', methods=['GET'])
@login_required
def get_current_user():
    """Retorna dados do usuário logado"""
    return jsonify({'user': current_user.to_dict()}), 200


@auth_bp.route('/users', methods=['GET'])
@login_required
def list_users():
    """Lista todos os usuários (apenas admin)"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403
    
    users = User.query.all()
    return jsonify({
        'users': [user.to_dict() for user in users],
        'total': len(users)
    }), 200
