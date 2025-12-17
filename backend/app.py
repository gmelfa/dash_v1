from flask import Flask, jsonify, request, g
import time
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
from export_batch_images import export_batch_bp
from query_loader import QueryLoader

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

@app.before_request
def start_timer():
    g.start = time.time()

@app.after_request
def log_request(response):
    if hasattr(g, 'start'):
        diff = time.time() - g.start
        # Adicionar header com tempo de resposta
        response.headers['X-Response-Time'] = str(diff)
        # Logar requisições lentas (> 1s)
        if diff > 1:
            print(f"[SLOW REQUEST] {request.method} {request.path} took {diff:.4f}s")
    return response

# Registrar blueprints
app.register_blueprint(auth_bp)
app.register_blueprint(comments_bp)
app.register_blueprint(export_bp)
app.register_blueprint(export_batch_bp)

# Caminho para o arquivo de queries (mantido para compatibilidade)
QUERIES_FILE = os.path.join(os.path.dirname(__file__), 'queries.json')

# Inicializar Query Loader com cache SQLite
query_loader = QueryLoader(queries_dir='queries', db_path=':memory:')
print("Carregando queries do diretorio...")
query_loader.load_all_queries()
print(f"[OK] Sistema de queries inicializado com {query_loader.get_stats()['total_queries']} queries")

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
    """Carrega queries usando QueryLoader (novo sistema)"""
    try:
        # Verificar se há atualizações nos arquivos (hot reload)
        query_loader.check_for_updates()
        
        # Buscar todas as queries do cache SQLite
        queries_data = query_loader.list_queries()
        
        # Converter para formato compatível com sistema antigo
        queries = []
        for q in queries_data:
            queries.append({
                'id': q['id'],
                'title': q['name'],
                'description': q['description'],
                'category': q['category'],
                'query': q['sql_content'],
                'active': True,
                'tags': q.get('tags', '').split(',') if q.get('tags') else []
            })
        
        return queries
    except Exception as e:
        print(f"Erro ao carregar queries: {e}")
        return []

def load_queries_categorized():
    """Carrega queries no formato categorizado usando QueryLoader"""
    try:
        # Verificar atualizações
        query_loader.check_for_updates()
        
        # Buscar categorias
        categories_data = query_loader.get_categories()
        
        # Construir estrutura categorizada
        categories = []
        for cat in categories_data:
            cat_name = cat['category']
            cat_queries = query_loader.list_queries(category=cat_name)
            
            # Converter queries para formato compatível
            queries = []
            for q in cat_queries:
                queries.append({
                    'id': q['id'],
                    'title': q['name'],
                    'description': q['description'],
                    'category': q['category'],
                    'query': q['sql_content'],
                    'active': True
                })
            
            categories.append({
                'id': cat_name.lower().replace(' ', '_'),
                'name': cat_name.title(),
                'icon': '📊',
                'description': f'{cat["count"]} queries',
                'queries': queries
            })
        
        return {'categories': categories}
    except Exception as e:
        print(f"Erro ao carregar queries categorizadas: {e}")
        return {'categories': []}

def save_queries(queries):
    """Salva queries no arquivo JSON (mantido para compatibilidade, mas não usado)"""
    print("AVISO: save_queries() chamado, mas queries agora são gerenciadas via arquivos SQL")
    return True

@app.route('/api/health', methods=['GET'])
def health_check():
    """Endpoint para verificar se o servidor está rodando"""
    return jsonify({'status': 'ok', 'message': 'Backend está rodando'}), 200

@app.route('/api/queries/stats', methods=['GET'])
def get_query_stats():
    """Retorna estatísticas do sistema de queries"""
    try:
        stats = query_loader.get_stats()
        return jsonify(stats), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/categories', methods=['GET'])
def get_query_categories():
    """Retorna lista de categorias disponíveis"""
    try:
        categories = query_loader.get_categories()
        return jsonify({'categories': categories}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/search', methods=['GET'])
def search_queries():
    """Busca queries por termo"""
    try:
        search_term = request.args.get('q', '')
        if not search_term:
            return jsonify({'error': 'Parâmetro de busca "q" é obrigatório'}), 400
        
        results = query_loader.search_queries(search_term)
        
        # Converter para formato compatível
        queries = []
        for q in results:
            queries.append({
                'id': q['id'],
                'title': q['name'],
                'description': q['description'],
                'category': q['category'],
                'query': q['sql_content'],
                'active': True
            })
        
        return jsonify({'queries': queries, 'total': len(queries)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/queries/reload', methods=['POST'])
def reload_queries():
    """Força reload de todas as queries do diretório"""
    try:
        count = query_loader.load_all_queries(force_reload=True)
        stats = query_loader.get_stats()
        return jsonify({
            'message': f'Queries recarregadas com sucesso',
            'loaded': count,
            'total': stats['total_queries']
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/queries', methods=['GET'])
def get_queries():
    """Retorna lista de todas as queries cadastradas"""
    try:
        # Verificar se deve retornar formato categorizado
        categorized = request.args.get('categorized', 'false').lower() == 'true'
        
        if categorized:
            data = load_queries_categorized()
            return jsonify(data), 200
        
        # Formato antigo (flat array)
        queries = load_queries()
        
        # Filtra apenas queries ativas se solicitado
        active_only = request.args.get('active_only', 'false').lower() == 'true'
        if active_only:
            queries = [q for q in queries if q.get('active', True)]
        
        # Agrupa por categoria se solicitado (formato antigo de agrupamento)
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

@app.route('/api/queries/<path:query_id>', methods=['GET'])
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

@app.route('/api/queries/<path:query_id>/execute', methods=['POST'])
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
