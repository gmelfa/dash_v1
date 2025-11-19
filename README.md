# Dashboard Databricks - Projeto Interativo

Este projeto é um dashboard interativo que conecta ao Databricks para visualizar e exportar dados.

## 📁 Estrutura do Projeto

```
dash_v1/
├── frontend/          # React + Vite
│   ├── src/
│   ├── public/
│   └── package.json
└── backend/           # Flask + Python
    ├── app.py
    ├── requirements.txt
    └── .env
```

## 🚀 Como Executar

### Backend (Python/Flask)

1. Navegue até a pasta backend:
```bash
cd backend
```

2. Copie o arquivo `.env.example` para `.env` e configure suas credenciais do Databricks:
```bash
copy .env.example .env
```

3. Edite o arquivo `.env` com suas credenciais do Databricks

4. Execute o servidor:
```bash
python app.py
```

O backend estará rodando em `http://localhost:5000`

### Frontend (React/Vite)

1. Navegue até a pasta frontend:
```bash
cd frontend
```

2. Inicie o servidor de desenvolvimento:
```bash
npm run dev
```

O frontend estará rodando em `http://localhost:5173`

## 🔧 Configuração do Databricks

No arquivo `backend/.env`, configure:

- `DATABRICKS_SERVER_HOSTNAME`: URL do seu workspace Databricks
- `DATABRICKS_HTTP_PATH`: Caminho HTTP do SQL Warehouse
- `DATABRICKS_TOKEN`: Token de acesso pessoal

## 📦 Dependências

### Backend
- Flask - Framework web
- Flask-CORS - Suporte para CORS
- databricks-sql-connector - Conector para Databricks
- python-dotenv - Gerenciamento de variáveis de ambiente

### Frontend
- React - Framework UI
- Vite - Build tool
- Axios - Cliente HTTP
- @tanstack/react-table - Tabelas interativas
- Recharts - Gráficos e visualizações
- lucide-react - Ícones

## 🎯 Funcionalidades

- ✅ Conexão com Databricks
- ✅ Listagem de tabelas disponíveis
- ✅ Visualização de dados em tabelas interativas
- ✅ Execução de queries customizadas
- 🔄 Exportação para PowerPoint (em desenvolvimento)

## 📝 API Endpoints

- `GET /api/health` - Verifica status do servidor
- `GET /api/tables` - Lista todas as tabelas disponíveis
- `GET /api/table/<table_name>` - Obtém dados de uma tabela específica
- `POST /api/query` - Executa uma query customizada
