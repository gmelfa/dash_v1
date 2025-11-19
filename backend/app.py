from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_login import LoginManager
from databricks import sql
import os
import json
from dotenv import load_dotenv
from database import init_db
from models import db, User
from auth import auth_bp
from comments import comments_bp
from export import export_bp

load_dotenv()

app = Flask(__name__)

# Configurar CORS com origem específica para suportar credenciais
CORS(app, 
     origins=['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:5174', 'http://127.0.0.1:5174'],
     supports_credentials=True,
     allow_headers=['Content-Type', 'Authorization'],
     methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])

# Inicializar banco de dados
init_db(app)

# Configurar Flask-Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'auth.login'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Registrar blueprints
app.register_blueprint(auth_bp)
app.register_blueprint(comments_bp)
app.register_blueprint(export_bp)

# Caminho para o arquivo de queries
QUERIES_FILE = os.path.join(os.path.dirname(__file__), 'queries.json')

# Configuração do Databricks
DATABRICKS_SERVER_HOSTNAME = os.getenv('DATABRICKS_SERVER_HOSTNAME')
DATABRICKS_HTTP_PATH = os.getenv('DATABRICKS_HTTP_PATH')
DATABRICKS_TOKEN = os.getenv('DATABRICKS_TOKEN')

def get_databricks_connection():
    """Estabelece conexão com o Databricks"""
    return sql.connect(
        server_hostname=DATABRICKS_SERVER_HOSTNAME,
        http_path=DATABRICKS_HTTP_PATH,
        access_token=DATABRICKS_TOKEN
    )

def load_queries():
    """Carrega queries do arquivo JSON"""
    try:
        with open(QUERIES_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Erro ao carregar queries: {e}")
        return []

def save_queries(queries):
    """Salva queries no arquivo JSON"""
    try:
        with open(QUERIES_FILE, 'w', encoding='utf-8') as f:
            json.dump(queries, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Erro ao salvar queries: {e}")
        return False

@app.route('/api/health', methods=['GET'])
def health_check():
    """Endpoint para verificar se o servidor está rodando"""
    return jsonify({'status': 'ok', 'message': 'Backend está rodando'}), 200

@app.route('/api/queries', methods=['GET'])
def get_queries():
    """Retorna lista de todas as queries cadastradas"""
    try:
        queries = load_queries()
        # Filtra apenas queries ativas se solicitado
        active_only = request.args.get('active_only', 'false').lower() == 'true'
        if active_only:
            queries = [q for q in queries if q.get('active', True)]
        
        # Agrupa por categoria se solicitado
        group_by_category = request.args.get('group_by_category', 'false').lower() == 'true'
        if group_by_category:
            categories = {}
            for query in queries:
                category = query.get('category', 'Sem Categoria')
                if category not in categories:
                    categories[category] = []
                categories[category].append(query)
            return jsonify({'queries': categories, 'total': len(queries)}), 200
        
        return jsonify({'queries': queries, 'total': len(queries)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/<query_id>', methods=['GET'])
def get_query_by_id(query_id):
    """Retorna uma query específica pelo ID"""
    try:
        queries = load_queries()
        query = next((q for q in queries if q['id'] == query_id), None)
        
        if not query:
            return jsonify({'error': 'Query não encontrada'}), 404
        
        return jsonify(query), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/<query_id>/execute', methods=['POST'])
def execute_saved_query(query_id):
    """Executa uma query salva pelo ID"""
    try:
        queries = load_queries()
        query_obj = next((q for q in queries if q['id'] == query_id), None)
        
        if not query_obj:
            return jsonify({'error': 'Query não encontrada'}), 404
        
        if not query_obj.get('active', True):
            return jsonify({'error': 'Query está inativa'}), 403
        
        query_sql = query_obj['query']
        
        with get_databricks_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query_sql)
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                
                # Remover coluna sort_order se existir
                sort_order_index = None
                if 'sort_order' in columns:
                    sort_order_index = columns.index('sort_order')
                    columns = [col for col in columns if col != 'sort_order']
                
                # Converter para formato JSON, removendo sort_order
                result = []
                for row in rows:
                    if sort_order_index is not None:
                        row_list = list(row)
                        row_list.pop(sort_order_index)
                        result.append(dict(zip(columns, row_list)))
                    else:
                        result.append(dict(zip(columns, row)))
                
                return jsonify({
                    'queryId': query_id,
                    'title': query_obj['title'],
                    'description': query_obj.get('description', ''),
                    'columns': columns,
                    'data': result,
                    'rowCount': len(result)
                }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries', methods=['POST'])
def add_query():
    """Adiciona uma nova query ao sistema"""
    try:
        data = request.json
        
        # Validação básica
        required_fields = ['id', 'title', 'query']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Campo obrigatório ausente: {field}'}), 400
        
        queries = load_queries()
        
        # Verifica se ID já existe
        if any(q['id'] == data['id'] for q in queries):
            return jsonify({'error': 'ID já existe'}), 400
        
        # Adiciona nova query
        new_query = {
            'id': data['id'],
            'title': data['title'],
            'description': data.get('description', ''),
            'category': data.get('category', 'Geral'),
            'query': data['query'],
            'active': data.get('active', True),
            'created_at': data.get('created_at', '')
        }
        
        queries.append(new_query)
        
        if save_queries(queries):
            return jsonify({'message': 'Query adicionada com sucesso', 'query': new_query}), 201
        else:
            return jsonify({'error': 'Erro ao salvar query'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/<query_id>', methods=['PUT'])
def update_query(query_id):
    """Atualiza uma query existente"""
    try:
        data = request.json
        queries = load_queries()
        
        query_index = next((i for i, q in enumerate(queries) if q['id'] == query_id), None)
        
        if query_index is None:
            return jsonify({'error': 'Query não encontrada'}), 404
        
        # Atualiza campos
        queries[query_index].update({
            'title': data.get('title', queries[query_index]['title']),
            'description': data.get('description', queries[query_index]['description']),
            'category': data.get('category', queries[query_index]['category']),
            'query': data.get('query', queries[query_index]['query']),
            'active': data.get('active', queries[query_index]['active'])
        })
        
        if save_queries(queries):
            return jsonify({'message': 'Query atualizada com sucesso', 'query': queries[query_index]}), 200
        else:
            return jsonify({'error': 'Erro ao salvar query'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/<query_id>', methods=['DELETE'])
def delete_query(query_id):
    """Remove uma query do sistema"""
    try:
        queries = load_queries()
        queries = [q for q in queries if q['id'] != query_id]
        
        if save_queries(queries):
            return jsonify({'message': 'Query removida com sucesso'}), 200
        else:
            return jsonify({'error': 'Erro ao salvar queries'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/tables', methods=['GET'])
def get_tables():
    """Retorna lista de tabelas disponíveis"""
    try:
        with get_databricks_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SHOW TABLES")
                tables = cursor.fetchall()
                table_list = [{'name': table[1], 'database': table[0]} for table in tables]
                return jsonify({'tables': table_list}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/query', methods=['POST'])
def execute_query():
    """Executa uma query no Databricks e retorna os resultados"""
    try:
        data = request.json
        query = data.get('query')
        
        if not query:
            return jsonify({'error': 'Query não fornecida'}), 400
        
        with get_databricks_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query)
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                
                # Converter para formato JSON
                result = [dict(zip(columns, row)) for row in rows]
                
                return jsonify({
                    'columns': columns,
                    'data': result,
                    'rowCount': len(result)
                }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/table/<table_name>', methods=['GET'])
def get_table_data(table_name):
    """Retorna os dados de uma tabela específica"""
    try:
        limit = request.args.get('limit', 100, type=int)
        
        with get_databricks_connection() as connection:
            with connection.cursor() as cursor:
                query = f"SELECT * FROM {table_name} LIMIT {limit}"
                cursor.execute(query)
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                
                # Converter para formato JSON
                result = [dict(zip(columns, row)) for row in rows]
                
                return jsonify({
                    'tableName': table_name,
                    'columns': columns,
                    'data': result,
                    'rowCount': len(result)
                }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
