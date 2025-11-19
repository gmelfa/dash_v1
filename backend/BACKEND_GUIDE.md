# Backend - Sistema de Comentários e Exportação

## ✅ Implementado

### Banco de Dados (SQLite)
- ✅ Modelo `User` - Usuários com autenticação
- ✅ Modelo `Comment` - Comentários vinculados a queries
- ✅ Relacionamentos entre tabelas
- ✅ Usuário admin padrão criado (username: `admin`, password: `admin123`)

### Autenticação (`/api/auth`)
- ✅ `POST /api/auth/register` - Registrar novo usuário
- ✅ `POST /api/auth/login` - Login
- ✅ `POST /api/auth/logout` - Logout
- ✅ `GET /api/auth/me` - Dados do usuário logado
- ✅ `GET /api/auth/users` - Listar usuários (apenas admin)

### Comentários (`/api/comments`)
- ✅ `GET /api/comments/query/<query_id>` - Listar comentários de uma query
- ✅ `POST /api/comments/` - Criar comentário (requer login)
- ✅ `PUT /api/comments/<comment_id>` - Editar comentário
- ✅ `DELETE /api/comments/<comment_id>` - Deletar comentário
- ✅ `GET /api/comments/query/<query_id>/approved` - Apenas comentários aprovados
- ✅ `POST /api/comments/query/<query_id>/batch-update` - Atualizar múltiplos (admin)

### Exportação PowerPoint (`/api/export`)
- ✅ `POST /api/export/pptx/development` - Exporta PPT com imagem da tabela + todos os comentários
- ✅ `POST /api/export/pptx/final` - Exporta PPT com tabela nativa + comentários aprovados

## 📋 Exemplos de Uso

### 1. Registrar Usuário
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "gabriel.melfa",
    "email": "gabriel@gruposeb.com",
    "password": "senha123"
  }'
```

### 2. Fazer Login
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "gabriel.melfa",
    "password": "senha123"
  }'
```

### 3. Criar Comentário
```bash
curl -X POST http://localhost:5000/api/comments/ \
  -H "Content-Type: application/json" \
  -H "Cookie: session=..." \
  -d '{
    "query_id": "resultado_10_2025",
    "content": "Os valores de MBGS estão divergentes do forecast"
  }'
```

### 4. Aprovar Comentário (Admin)
```bash
curl -X PUT http://localhost:5000/api/comments/1 \
  -H "Content-Type: application/json" \
  -H "Cookie: session=..." \
  -d '{
    "status": "approved",
    "edited_content": "Valores de MBGS revisados e ajustados"
  }'
```

### 5. Exportar PowerPoint Development
```bash
curl -X POST http://localhost:5000/api/export/pptx/development \
  -F "query_id=resultado_10_2025" \
  -F "query_title=Resumo - Grupo SEB (YTD Outubro)" \
  -F "table_image=@screenshot.png" \
  -o development.pptx
```

### 6. Exportar PowerPoint Final
```bash
curl -X POST http://localhost:5000/api/export/pptx/final \
  -H "Content-Type: application/json" \
  -d '{
    "query_id": "resultado_10_2025",
    "query_title": "Resumo - Grupo SEB (YTD Outubro)",
    "table_data": [...],
    "columns": [...]
  }' \
  -o final.pptx
```

## 🔒 Permissões

### Usuário Normal
- ✅ Criar comentários
- ✅ Editar/deletar seus próprios comentários
- ✅ Visualizar todos os comentários
- ❌ Aprovar/rejeitar comentários
- ❌ Editar comentários de outros

### Admin
- ✅ Todas as permissões de usuário normal
- ✅ Aprovar/rejeitar qualquer comentário
- ✅ Editar qualquer comentário
- ✅ Atualização em lote
- ✅ Listar todos os usuários

## 🗄️ Estrutura do Banco

### Tabela `users`
```sql
id              INTEGER PRIMARY KEY
username        VARCHAR(80) UNIQUE
email           VARCHAR(120) UNIQUE
password_hash   VARCHAR(255)
is_admin        BOOLEAN DEFAULT FALSE
created_at      DATETIME
```

### Tabela `comments`
```sql
id              INTEGER PRIMARY KEY
query_id        VARCHAR(100)
user_id         INTEGER FK -> users.id
content         TEXT
status          VARCHAR(20)  -- pending, approved, rejected
edited_content  TEXT (nullable)
edited_by       INTEGER FK -> users.id (nullable)
edited_at       DATETIME (nullable)
created_at      DATETIME
updated_at      DATETIME
```

## 📦 Arquivos Criados

- `models.py` - Modelos SQLAlchemy (User, Comment)
- `database.py` - Configuração e inicialização do banco
- `auth.py` - Rotas de autenticação
- `comments.py` - Rotas de comentários (CRUD)
- `pptx_service.py` - Serviço de geração de PowerPoint
- `export.py` - Rotas de exportação
- `database.db` - Banco SQLite (criado automaticamente)

## 🚀 Próximos Passos

Frontend a implementar:
- [ ] Componentes de autenticação (Login/Register)
- [ ] Seção de comentários abaixo da tabela
- [ ] Painel de revisão do gestor
- [ ] Integração com html2canvas para captura de screenshot
- [ ] Botões de exportação Development/Final
