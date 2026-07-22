# Graph Report - dash_v1  (2026-07-22)

## Corpus Check
- 43 files · ~47,677 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 313 nodes · 351 edges · 41 communities (34 shown, 7 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 34 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `187b64da`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Flask App Routes & Query API
- Query Loader Service
- Auth/Comments Data Models
- Frontend App & Components
- Databricks Data Model (CLAUDE.md)
- Frontend Runtime Dependencies
- Frontend Dev Tooling
- Auth Endpoints
- PPTX Export (Single)
- Backend Dependencies & Architecture
- Batch PPTX Export with Images
- Student Budget Migration Debt
- Frontend Entry & DataTable Quirks
- SQL Style Conventions
- Ipiranga Special Rule
- Databricks Connection
- Query 07 - Beneficios
- Query 08 - Rateio Corporativo
- SQLite Storage
- Favicon Asset
- Vite Logo Asset
- React Logo Asset
- prune_graphify_backups.sh

## God Nodes (most connected - your core abstractions)
1. `QueryLoader` - 15 edges
2. `mv_f_apresentacao` - 10 edges
3. `User` - 9 edges
4. `load_queries()` - 8 edges
5. `d_classunidades` - 8 edges
6. `useAuth()` - 7 edges
7. `f_resultado` - 7 edges
8. `get_databricks_connection()` - 6 edges
9. `save_queries()` - 5 edges
10. `execute_saved_query()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `SQL Convention (seb.md)` --semantically_similar_to--> `Human-Style SQL Convention`  [INFERRED] [semantically similar]
  .claude/commands/seb.md → CLAUDE.md
- `Bound Params Pattern (seb.md)` --semantically_similar_to--> `Bound Params Pattern (real implementation)`  [INFERRED] [semantically similar]
  .claude/commands/seb.md → CLAUDE.md
- `Vertical Premium (seb.md)` --semantically_similar_to--> `Vertical Premium`  [INFERRED] [semantically similar]
  .claude/commands/seb.md → CLAUDE.md
- `Vertical Alta Performance (seb.md)` --semantically_similar_to--> `Vertical Alta Performance (HEB)`  [INFERRED] [semantically similar]
  .claude/commands/seb.md → CLAUDE.md
- `mv_f_apresentacao (seb.md)` --semantically_similar_to--> `mv_f_apresentacao`  [INFERRED] [semantically similar]
  .claude/commands/seb.md → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Dashboard Tech Stack** — claude_flask_backend, claude_react_frontend, claude_sqlite_storage, claude_databricks_sql_source, backend_requirements_flask, backend_requirements_databricks_sql_connector [INFERRED 0.85]
- **mv_f_apresentacao UNION ALL Sources** — claude_mv_f_apresentacao, claude_f_resultado, claude_f_ajustes, claude_f_orcamento, claude_f_alunos, claude_f_orcamentoalunos [EXTRACTED 1.00]
- **Premium Vertical Business Rules** — claude_vertical_premium, claude_ipiranga_rule, claude_vertical_ap, claude_d_classunidades [EXTRACTED 1.00]

## Communities (41 total, 7 thin omitted)

### Community 0 - "Flask App Routes & Query API"
Cohesion: 0.07
Nodes (38): add_query(), delete_query(), execute_query(), execute_saved_query(), get_databricks_connection(), get_queries(), get_query_by_id(), get_query_categories() (+30 more)

### Community 1 - "Query Loader Service"
Cohesion: 0.08
Nodes (20): Any, QueryLoader, QueryMetadata, Query Loader Module - Sistema de Gerenciamento de Queries com Cache SQLite  Es, Calcula hash MD5 de um arquivo, Extrai metadados de um arquivo SQL                  Procura por comentários es, Varre o diretório de queries e retorna lista de metadados, Carrega todas as queries do diretório para o cache SQLite                  Arg (+12 more)

### Community 2 - "Auth/Comments Data Models"
Cohesion: 0.07
Nodes (23): admin_create_user(), Admin cria um usuário já aprovado, Registra novo usuário, register(), batch_update_comments(), create_comment(), delete_comment(), get_approved_comments() (+15 more)

### Community 3 - "Frontend App & Components"
Cohesion: 0.20
Nodes (8): Login(), Register(), CommentForm(), CommentItem(), CommentList(), CommentsSection(), AuthContext, useAuth()

### Community 4 - "Databricks Data Model (CLAUDE.md)"
Cohesion: 0.11
Nodes (26): CAPEX Tables (seb.md), d_classunidades (seb.md), DRE Premium Structure (seb.md), f_alunos (seb.md), link_pnl (seb.md), mv_f_apresentacao (seb.md), Vertical Alta Performance (seb.md), CAPEX Tables (f_capex, f_capexajustes, f_orcamentocapex) (+18 more)

### Community 5 - "Frontend Runtime Dependencies"
Cohesion: 0.08
Nodes (24): axios, dependencies, axios, html2canvas, lucide-react, react, react-dom, recharts (+16 more)

### Community 6 - "Frontend Dev Tooling"
Cohesion: 0.10
Nodes (21): baseline-browser-mapping, eslint, @eslint/js, eslint-plugin-react-hooks, eslint-plugin-react-refresh, devDependencies, baseline-browser-mapping, eslint (+13 more)

### Community 7 - "Auth Endpoints"
Cohesion: 0.13
Nodes (17): approve_user(), _check_lockout(), _clear_attempts(), get_current_user(), _get_ip(), list_pending_users(), list_users(), login() (+9 more)

### Community 8 - "PPTX Export (Single)"
Cohesion: 0.17
Nodes (14): export_batch(), export_development(), export_final(), Exporta múltiplas queries em um único PowerPoint     Recebe: query_ids (array d, Exporta PowerPoint de desenvolvimento     Recebe: query_id, query_title, table_, Exporta PowerPoint final (apenas comentários aprovados com tabela nativa)     R, add_comments_section(), create_development_pptx() (+6 more)

### Community 9 - "Backend Dependencies & Architecture"
Cohesion: 0.14
Nodes (14): flask==3.0.0, flask-cors==4.0.0, flask-login==0.6.3, flask-sqlalchemy==3.1.1, pillow==12.0.0, python-dotenv==1.0.0, python-pptx==0.6.23, tabulate==0.9.0 (+6 more)

### Community 10 - "Batch PPTX Export with Images"
Cohesion: 0.33
Nodes (8): _add_comments_footer(), _add_comments_sidebar(), export_batch_with_images(), _get_comment_text(), Exporta PPTX com Layout Híbrido Automático e Algoritmo Best-Fit:     - Tabelas, Retorna edited_content se existir, senão content original., Adiciona comentários empilhados no rodapé (Layout A) — um por linha., Adiciona comentários no painel esquerdo (Layout B) com truncamento controlado.

### Community 11 - "Student Budget Migration Debt"
Cohesion: 0.33
Nodes (6): f_alunos_forecastrealizado (seb.md), f_orcamentoalunosrollingforecast (seb.md), f_alunos_forecastrealizado, f_orcamentoalunos, f_orcamentoalunosrollingforecast (deprecated), Query 02 Migration Debt

### Community 12 - "Frontend Entry & DataTable Quirks"
Cohesion: 0.33
Nodes (6): DataTable.jsx Non-Obvious Behaviors, Frontend File Structure (frontend/src/), React (Vite) Frontend, Script Tag /src/main.jsx, Page Title: Dashboard Databricks - Grupo SEB, #root Mount Div

### Community 13 - "SQL Style Conventions"
Cohesion: 0.40
Nodes (5): Bound Params Pattern (seb.md), SQL Convention (seb.md), Bound Params Pattern (real implementation), Dynamic Date Params Rule (never hardcode years), Human-Style SQL Convention

### Community 14 - "Ipiranga Special Rule"
Cohesion: 0.67
Nodes (4): Ipiranga Rule (seb.md), Vertical Premium (seb.md), Ipiranga (1040) Special Rule, Vertical Premium

### Community 22 - "Query 07 - Beneficios"
Cohesion: 0.36
Nodes (5): App(), AppContent(), getDefaultPeriod(), MESES, useTheme()

## Knowledge Gaps
- **57 isolated node(s):** `MESES`, `name`, `private`, `version`, `type` (+52 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `devDependencies` connect `Frontend Dev Tooling` to `Frontend Runtime Dependencies`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `User` (e.g. with `admin_create_user()` and `register()`) actually correct?**
  _`User` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `MESES`, `name`, `private` to the rest of the system?**
  _57 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Flask App Routes & Query API` be split into smaller, more focused modules?**
  _Cohesion score 0.06504065040650407 - nodes in this community are weakly interconnected._
- **Should `Query Loader Service` be split into smaller, more focused modules?**
  _Cohesion score 0.0773109243697479 - nodes in this community are weakly interconnected._
- **Should `Auth/Comments Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.07126436781609195 - nodes in this community are weakly interconnected._
- **Should `Databricks Data Model (CLAUDE.md)` be split into smaller, more focused modules?**
  _Cohesion score 0.1076923076923077 - nodes in this community are weakly interconnected._