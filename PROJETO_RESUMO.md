# Resumo do Projeto — Dashboard Databricks Grupo SEB

## O que é

Dashboard interno corporativo para o **Grupo SEB** (Sociedade Educacional Brasileira), uma holding de escolas de educação básica premium. O sistema permite que gestores executem queries SQL pré-definidas contra o data warehouse Databricks e visualizem os resultados em tabelas interativas, adicionem comentários analíticos, e exportem os dados para PowerPoint para reuniões de resultado.

---

## Contexto de Negócio

O Grupo SEB possui verticais de negócio (ex: **Premium**, **Maple Bear**, **Ânima**) cada uma com dezenas de unidades escolares. O dashboard serve para acompanhamento de performance financeira mensal, com foco em:

- **Alunos** — quantidade de matrículas por unidade/vertical
- **ROL** — Receita Operacional Líquida (em R$ mil)
- **EBITDA** — resultado operacional (em R$ mil)
- **Margem EBITDA** — EBITDA / ROL em %
- **Ticket Médio** — receita de ensino por aluno por mês

Os dados são comparados entre 4 cenários: **Real do ano anterior**, **Budget do ano atual**, **Forecast do ano atual**, e **Real do ano atual**. O período padrão é YTD (acumulado de janeiro até o último mês fechado).

---

## Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Backend | Python 3 + Flask 3.0 |
| Data Warehouse | Databricks (SQL Connector) |
| BD Local | SQLite (usuários e comentários) |
| Exportação | python-pptx |
| Frontend | React 19 + Vite |
| Tabelas | TanStack React Table |
| HTTP | Axios |
| Screenshot | html2canvas |

---

## Arquitetura

```
dash_v1/
├── backend/
│   ├── app.py              # Flask principal, rotas da API
│   ├── query_loader.py     # Carrega arquivos .sql do disco com cache
│   ├── models.py           # ORM SQLAlchemy (User, Comment)
│   ├── auth.py             # Login, registro, sessão
│   ├── comments.py         # CRUD de comentários
│   ├── export.py           # Exportação para PowerPoint
│   └── queries/            # Arquivos .sql organizados por categoria
│       └── Premium/        # Ex: vertical Premium
│           ├── 06_premium_principais_metricas_ytd.sql
│           └── 07_EBTIDA_por_unidade_YTD.sql
└── frontend/
    └── src/
        ├── App.jsx             # Componente raiz
        ├── components/
        │   ├── DataTable.jsx   # Tabela interativa
        │   └── Comments/       # Sistema de comentários
        └── contexts/
            └── AuthContext.jsx
```

---

## Como as Queries Funcionam

Cada query é um arquivo `.sql` na pasta `backend/queries/{categoria}/`. O sistema carrega todos automaticamente. Cada arquivo tem metadados no cabeçalho:

```sql
-- @id: premium_principais_metricas_ytd
-- @name: Premium - Principais Métricas YTD
-- @category: Premium
-- @order: 06
```

### Padrão de estrutura SQL

As queries usam CTEs encadeadas:

1. **`params`** — parâmetros centralizados (ano, mês YTD, vertical). Atualmente dinâmicos via `CURRENT_DATE()` para não precisar de atualização manual.
2. **`base`** / **`base_dados`** — filtra os fatos da tabela principal `financeiro.prd.mv_f_apresentacao`, carregando `ano_atual`, `ano_anterior` e `mes_ytd` para as CTEs seguintes.
3. **CTEs de agregação** — pivotam os dados com `SUM(CASE WHEN ano = ano_atual AND Origem = 'Budget' ...)` para gerar colunas por cenário.
4. **SELECT final** — formata os dados com `ROUND()` e aliases no padrão `25R`, `26B`, `26F`, `26R` (ano + cenário).

### Tabela principal do DW

`financeiro.prd.mv_f_apresentacao` — view materializada com colunas-chave:
- `Nome_Unidade`, `Grupo`, `Vertical`
- `Data_Transacao`
- `Origem` — `'Resultado'`, `'Ajustes'`, `'Budget'`, `'Forecast'`, `'Alunos'`
- `Valor` — valor financeiro (positivo = custo/saída na convenção da base, por isso há inversão `* -1` nas receitas)
- `ROL` — flag booleana (1 = linha entra no ROL)
- `Ebitda` — `'Sim'`/`'Não'`
- `Recorrente` — `'Sim'`/`'Não'`
- `skclasspnl` — código de classificação (`'400000000'` = alunos)
- `Nome_PnL` — linha do P&L (ex: `'Receitas com Ensino Regular'`)

---

## Funcionalidades do Sistema

1. **Autenticação** — login, registro, controle admin/usuário comum
2. **Sidebar de queries** — lista categorizada, clique para executar
3. **Execução de query** — conecta ao Databricks e retorna JSON
4. **Tabela interativa** — paginação, ordenação, busca
5. **Comentários** — usuários comentam por query; admin aprova/rejeita
6. **Exportação PowerPoint** — gera `.pptx` com tabela + comentários aprovados
7. **Exportação em lote** — seleciona múltiplas queries e exporta de uma vez

---

## Estado Atual

- Sistema base 100% funcional (autenticação, queries, comentários, exportação)
- **2 queries implementadas** na vertical Premium
- Estrutura preparada para receber 100+ queries em múltiplas categorias
- Próximo passo: construir as queries das demais verticais e períodos

---

## Queries Premium Implementadas

### 06 — Principais Métricas YTD
Retorna uma tabela onde cada **linha é uma métrica** (Alunos, Ticket Médio, ROL, EBITDA, Margem) e cada coluna é um período/variação. Serve como resumo executivo da vertical Premium.

### 07 — EBITDA por Unidade YTD
Retorna uma tabela onde cada **linha é uma unidade escolar** (ou subtotal de grupo) e as colunas mostram Alunos, ROL e EBITDA para cada cenário. Hierarquia: unidades → subtotais por grupo (Pueri Domus, C. Patrício, Sphere) → Operações Mantidas / Novos Negócios → Total Premium.

---

## Convenções SQL do Projeto

- Aliases de colunas: `25R` (Real ano anterior), `26B` (Budget atual), `26F` (Forecast atual), `26R` (Real atual)
- Margem: sufixo `_Mg`
- Variações: `Var 26xBgt`, `Var% 26xBgt`, `Var 26xFcst`, `Var 26x25`
- CTEs com nomes intuitivos, comentários explicam o "porquê" (não o "o quê")
- Sem separadores decorativos (`---`, `===`) entre seções
- Params sempre dinâmicos via `CURRENT_DATE()`, nunca hardcoded