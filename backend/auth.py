from flask import Blueprint, request, jsonify
from flask_login import login_user, logout_user, login_required, current_user
from sqlalchemy import func
from models import db, User
import time

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

_login_attempts = {}  # { ip: { 'count': N, 'locked_until': timestamp } }
MAX_ATTEMPTS = 5
LOCKOUT_SECONDS = 15 * 60  # 15 minutos

def _get_ip():
    return request.headers.get('X-Forwarded-For', request.remote_addr).split(',')[0].strip()

def _check_lockout(ip):
    entry = _login_attempts.get(ip)
    if not entry:
        return False
    if entry.get('locked_until') and time.time() < entry['locked_until']:
        return True
    if entry.get('locked_until') and time.time() >= entry['locked_until']:
        del _login_attempts[ip]
    return False

def _register_failure(ip):
    entry = _login_attempts.setdefault(ip, {'count': 0})
    entry['count'] += 1
    if entry['count'] >= MAX_ATTEMPTS:
        entry['locked_until'] = time.time() + LOCKOUT_SECONDS

def _clear_attempts(ip):
    _login_attempts.pop(ip, None)

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
        
        # Criar novo usuário — is_admin e is_approved nunca vêm do request
        user = User(
            username=data['username'],
            email=data['email'],
            is_admin=False,
            is_approved=False
        )
        user.set_password(data['password'])

        db.session.add(user)
        db.session.commit()

        print(f"[DEBUG] Usuário criado, aguardando aprovação: {user.username}")

        return jsonify({
            'message': 'Cadastro realizado. Aguarde a aprovação de um administrador.',
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
        ip = _get_ip()

        if _check_lockout(ip):
            return jsonify({'error': 'Muitas tentativas incorretas. Tente novamente em 15 minutos.'}), 429

        data = request.json
        print(f"[DEBUG] Tentativa de login - dados recebidos: {data}")

        username = data.get('username')
        password = data.get('password')

        if not username or not password:
            print("[DEBUG] Username ou senha não fornecidos")
            return jsonify({'error': 'Username e senha são obrigatórios'}), 400

        # Buscar usuário por username ou email (case-insensitive)
        username_lower = username.lower()
        user = User.query.filter(
            (func.lower(User.username) == username_lower) |
            (func.lower(User.email) == username_lower)
        ).first()
        print(f"[DEBUG] Usuário encontrado: {user.username if user else 'None'}")

        if not user or not user.check_password(password):
            _register_failure(ip)
            attempts = _login_attempts.get(ip, {}).get('count', 0)
            remaining = MAX_ATTEMPTS - attempts
            if remaining <= 0:
                return jsonify({'error': 'Muitas tentativas incorretas. Tente novamente em 15 minutos.'}), 429
            return jsonify({'error': f'Credenciais inválidas. {remaining} tentativa(s) restante(s).'}), 401

        if not user.is_approved:
            return jsonify({'error': 'Conta aguardando aprovação de um administrador.'}), 403

        _clear_attempts(ip)
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

    users = User.query.order_by(User.created_at).all()
    return jsonify({
        'users': [u.to_dict() for u in users],
        'total': len(users)
    }), 200


@auth_bp.route('/users/pending', methods=['GET'])
@login_required
def list_pending_users():
    """Lista usuários aguardando aprovação (apenas admin)"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403

    pending = User.query.filter_by(is_approved=False).order_by(User.created_at).all()
    return jsonify({'users': [u.to_dict() for u in pending]}), 200


@auth_bp.route('/admin/create-user', methods=['POST'])
@login_required
def admin_create_user():
    """Admin cria um usuário já aprovado"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403

    data = request.json or {}
    username = data.get('username', '').strip()
    email = data.get('email', '').strip()
    password = data.get('password', '').strip()
    is_admin = bool(data.get('is_admin', False))

    if not all([username, email, password]):
        return jsonify({'error': 'username, email e password são obrigatórios'}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username já existe'}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Email já cadastrado'}), 400

    user = User(
        username=username,
        email=email,
        is_admin=is_admin,
        is_approved=True
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify({'message': f'Usuário {username} criado com sucesso.', 'user': user.to_dict()}), 201


@auth_bp.route('/users/<int:user_id>/toggle-admin', methods=['POST'])
@login_required
def toggle_admin(user_id):
    """Promove ou rebaixa um usuário para admin (apenas admin)"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403

    if user_id == current_user.id:
        return jsonify({'error': 'Você não pode alterar seu próprio acesso de admin'}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'Usuário não encontrado'}), 404

    user.is_admin = not user.is_admin
    db.session.commit()

    acao = 'promovido a admin' if user.is_admin else 'removido de admin'
    return jsonify({'message': f'{user.username} {acao}.', 'user': user.to_dict()}), 200


@auth_bp.route('/users/<int:user_id>/reset-password', methods=['POST'])
@login_required
def reset_password(user_id):
    """Admin redefine a senha de um usuário"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'Usuário não encontrado'}), 404

    data = request.json or {}
    new_password = data.get('password', '').strip()

    if len(new_password) < 6:
        return jsonify({'error': 'A senha deve ter pelo menos 6 caracteres'}), 400

    user.set_password(new_password)
    db.session.commit()

    return jsonify({'message': f'Senha de {user.username} redefinida com sucesso.'}), 200


@auth_bp.route('/users/<int:user_id>/approve', methods=['POST'])
@login_required
def approve_user(user_id):
    """Aprova ou rejeita um usuário (apenas admin)"""
    if not current_user.is_admin:
        return jsonify({'error': 'Acesso negado'}), 403

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'Usuário não encontrado'}), 404

    data = request.json or {}
    action = data.get('action')  # 'approve' ou 'reject'

    if action == 'approve':
        user.is_approved = True
        db.session.commit()
        return jsonify({'message': f'{user.username} aprovado com sucesso.', 'user': user.to_dict()}), 200
    elif action == 'reject':
        db.session.delete(user)
        db.session.commit()
        return jsonify({'message': f'{user.username} rejeitado e removido.'}), 200
    else:
        return jsonify({'error': 'Ação inválida. Use "approve" ou "reject".'}), 400
