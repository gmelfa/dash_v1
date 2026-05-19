# CLAUDE.md — Dashboard Business Review Premium (Grupo SEB)

Arquivo de contexto para o Claude Code. Leia isso antes de qualquer tarefa.

---

## O que é este projeto

Dashboard interno do Grupo SEB para Business Review Premium. Exibe dados financeiros e operacionais consultados diretamente no Databricks, com sistema de comentários por query, aprovação de usuários e exportação para PowerPoint.

Stack: **Flask (Python)** no backend + **React (Vite)** no frontend + **Databricks SQL** como fonte de dados + **SQLite** para auth e comentários.

---

## Setup em máquina nova

```bash
# 1. Clonar
git clone https://github.com/gmelfa/dash_v1.git
cd dash_v1

# 2. Backend
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
# Criar arquivo .env com as credenciais do Databricks (ver seção abaixo)
python app.py

# 3. Frontend (outro terminal)
cd frontend
npm install
npm run dev
```

### Arquivo `.env` (backend/)

```env
DATABRICKS_SERVER_HOSTNAME=...
DATABRICKS_HTTP_PATH=...
DATABRICKS_TOKEN=...
SECRET_KEY=...   # qualquer string aleatória longa
```

As credenciais reais ficam com o responsável do projeto — nunca commitadas.

Na primeira execução o banco SQLite é criado automaticamente com um usuário `admin` (senha: `admin123`). Troque a senha imediatamente pelo painel de admin.

---

## Estrutura de arquivos

```
backend/
  app.py                  # Flask app principal, rotas de query e Databricks
  auth.py                 # Blueprint de autenticação (/api/auth/*)
  comments.py             # Blueprint de comentários (/api/comments/*)
  export.py               # Export PPTX individual (pptx_service.py)
  export_batch_images.py  # Export PPTX em lote com imagens (rota principal)
  pptx_service.py         # Helpers de geração de PPTX (dev + final)
  models.py               # SQLAlchemy: User, Comment
  database.py             # init_db, migrações, seed do admin
  query_loader.py         # Carrega .sql da pasta queries/ com cache
  queries/
    Premium/              # Queries da vertical Premium (06 a 17)
    financeiro/
    diretorias/
    ...

frontend/
  src/
    App.jsx               # Componente raiz: sidebar, auth, export, gestão de usuários
    App.css
    contexts/
      AuthContext.jsx     # Context de autenticação (login, logout, estado do usuário)
    components/
      Comments/           # CommentList, CommentItem, CommentForm, Comments.css
      Auth/               # Login.jsx, Register.jsx, Auth.css
      DataTable.jsx       # Tabela de resultados de query
      PcldChart.jsx       # Gráfico de PCLD
```

---

## Arquitetura de auth

- Usuários criados pelo admin (não há auto-registro público)
- Campos: `username`, `email`, `password_hash` (bcrypt), `is_admin`, `is_approved`
- Novos usuários via `/api/auth/admin/create-user` já nascem aprovados
- Login aceita username ou email, case-insensitive (exceto senha)
- Sessão de 30 dias com Flask-Login
- Endpoints principais: `/api/auth/login`, `/api/auth/logout`, `/api/auth/me`, `/api/auth/users`, `/api/auth/users/<id>/toggle-admin`

---

## Sistema de comentários

- Comentários por `query_id`, com status: `pending` → `approved` / `rejected`
- Máximo 500 chars por comentário (não-admin)
- Admin pode editar conteúdo (`edited_content`) antes de aprovar
- Apenas comentários `approved` aparecem no export PPTX

---

## Export PPTX (export_batch_images.py)

Rota principal: `POST /api/export/pptx/batch-images`

Layout automático por aspect ratio da imagem capturada:

- **Layout A** (`img_ratio > 1.5`): tabela larga → ocupa largura total, comentários no rodapé
- **Layout B** (`img_ratio ≤ 1.5`): tabela alta/quadrada → título topo (full width) + comentários à esquerda (4") + tabela à direita (≈8")

Configurações relevantes:
- `THRESHOLD_RATIO = 1.5`
- Sidebar: `MAX_CHARS = 140`, `MAX_VISIBLE = 3`
- Footer: `MAX_CHARS_FOOTER = 160`
- Fonte dos comentários: `Pt(11)`

---

## Convenções de SQL

### Estilo humano — não corporativo

- **Sem** separadores decorativos (`-- ===========================`)
- **Sem** nomes genéricos de CTE (`source_data`, `dados_classificados`)
- Usar nomes que reflitam o raciocínio real: `receita_liquida`, `unidades_sem_rateio`
- Comentários explicam o **porquê**, não o quê: `-- excluímos o CSC porque aparece duplicado nas verticais`
- Lógica agrupada naturalmente, sem CTEs desnecessários só para organizar

### Datas dinâmicas — nunca hardcodar anos

Todo CTE `params` deve seguir este padrão:

```sql
with params as (
    select
        year(current_date())     as ano_atual,
        year(current_date()) - 1 as ano_anterior,
        case when month(current_date()) = 1 then 12
             else month(current_date()) - 1 end as mes_ytd,
        '<Vertical>' as vertical
)
```

- Nunca comparar `ano = 2025` ou `ano = 2026` hardcoded
- Usar `ano = ano_anterior` / `ano = ano_atual` nas condições
- Aliases de coluna no SELECT final: `25R`, `26B`, `26F`, `26R`, `Var 26xBgt`, `Var% 26xBgt`
- Para queries por unidade: `25R_Alu`, `25R_ROL`, `25R_EBT`, `25R_Mg`, `26B_Alu`, etc.

### Dúvidas de negócio

**Sempre perguntar** antes de assumir colunas desconhecidas, tipos de dados ou regras de negócio. Nunca adivinhar e construir em cima de suposição.

---

## Queries existentes (Premium)

| Arquivo | Descrição |
|---------|-----------|
| 06_premium_principais_metricas_ytd.sql | Métricas YTD consolidadas |
| 07_EBTIDA_por_unidade_YTD.sql | EBITDA por unidade |
| 08_DRE_premium_YTD.sql | DRE Premium YTD |
| 09_historico_alunos_premium.sql | Histórico de alunos (histórico + forecast + realizado) |
| 10_fopag_direta.sql | Folha de pagamento direta |
| 11_fopag_indireta.sql | Folha de pagamento indireta |
| 12_beneficios.sql | Benefícios |
| 13_rateio_corporativo.sql | Rateio corporativo |
| 14_pcld.sql | PCLD tabela |
| 15_pcld_grafico.sql | PCLD dados para gráfico |
| 16_variacao_orcado.sql | Variação vs orçado |
| 17_capex.sql | CAPEX |

---

## Como adicionar uma nova query

1. Criar arquivo `.sql` em `backend/queries/<categoria>/NN_nome.sql`
2. O `QueryLoader` carrega automaticamente na inicialização
3. O `id` da query é gerado a partir do nome do arquivo (sem número e extensão)
4. A sidebar do frontend agrupa por `category` (nome da pasta)
