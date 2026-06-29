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
    Premium/              # Queries da vertical Premium (01 a 12 + 09b)
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
| 01_premium_principais_metricas_ytd.sql | Métricas YTD consolidadas |
| 02_EBTIDA_por_unidade_YTD.sql | EBITDA por unidade |
| 03_DRE_premium_YTD.sql | DRE Premium YTD |
| 04_historico_alunos_premium.sql | Histórico de alunos (histórico + forecast + realizado) |
| 05_fopag_direta.sql | Folha de pagamento direta |
| 06_fopag_indireta.sql | Folha de pagamento indireta |
| 07_beneficios.sql | Benefícios |
| 08_rateio_corporativo.sql | Rateio corporativo |
| 09_pcld.sql | PCLD tabela |
| 09b_pcld_grafico.sql | PCLD dados para gráfico |
| 10_variacao_orcado.sql | Variação vs orçado |
| 11_capex.sql | CAPEX |
| 12_lucro_liquido_ytd_consolidado.sql | Lucro líquido YTD consolidado |

---

## Como adicionar uma nova query

1. Criar arquivo `.sql` em `backend/queries/<categoria>/NN_nome.sql`
2. O `QueryLoader` carrega automaticamente na inicialização
3. O `id` da query é gerado a partir do nome do arquivo (sem número e extensão)
4. A sidebar do frontend agrupa por `category` (nome da pasta)

---

## Conhecimento institucional — Databricks

Esta seção documenta fatos não-óbvios sobre as tabelas do Databricks que foram descobertos durante o desenvolvimento e NÃO são deriváveis apenas lendo o SQL.

### Estrutura do Grupo SEB — verticais

| Vertical | Holding | Escolas/Entidades |
|----------|---------|-------------------|
| **Premium** | SEB | Pueri Domus (SP), Sphere (SJC), C. Patrício (RJ) |
| **AP - Região 1** | HEB | Sartre (Salvador/BA) |
| **AP - Região 2** | HEB | Dom Bosco (Curitiba), SEB Ribeirão, COC Floripa, AaZ RJ, SEB Rio Preto |
| **AP - Região 3** | HEB | SEB Maceió, SEB Espírito Santo |
| **AP - Região 4** | HEB | Unimaster (BH), Sagrado Coração (BH), Colégio Visão (Goiânia), SEB Brasília |
| **Ensino Superior** | SEB | Faculdade Dom Bosco (1501/1502), EPD (1601) |
| **Vanguarda** | SEB | Concept Ribeirão, Concept SP, Concept Salvador |
| **Maple Bear Escolas Próprias** | SEB | Escolas próprias em Brasília |
| **Franquias** | NWC | Maple Bear Brasil, Sphere Franquias, Luminova |
| **Conexia** | CNX | Plataforma de tecnologia educacional |
| **Luminova** | NWC | Escolas sociais (Sorocaba, Ribeirão, SP) |
| **MBGS** | Outros | Maple Bear Global Schools (40+ países) |
| **IOA** | Outros | Instituto diferente — clínicas (Kefraya, Lapidare) |
| **Holding** | SEB/NWC | Entidades administrativas (Alta Vela, TCA) |

Filtro por vertical no SQL: `dc.Vertical = 'Premium'` / `dc.Holding = 'HEB'` para AP

### Chaves de join na d_classunidades

A tabela tem **múltiplas linhas por unidade**: a linha real (`codPadrao = 'Sim'`) + variantes "CSC Local", "Diretoria", "Franquias" (`codPadrao = 'Não'`). Isso causa fan-out silencioso.

| Chave | Comportamento | Uso correto |
|-------|--------------|-------------|
| `skunidade` | 1:1 com qualquer tabela fato | **Usar sempre que disponível** |
| `codPadrao = 'Sim'` | Filtra só linhas primárias | Alternativa mais robusta ao NOT LIKE '%CSC Local%' |
| `idEstFiscal` | N linhas por unidade | Só usar com `codPadrao = 'Sim'` ou filtros de Nome |
| `idUnidadeOperacional` | Sempre `11101001` em f_alunos — código de sistema | **Nunca usar como join key** |

Nomes de coluna no Databricks (diferem dos aliases no Excel exportado):
- `idEstFiscal` (Excel: `codEstFiscal`)
- `Nome` (Excel: `desNome`)
- `Vertical` (Excel: `desVertical`)
- `Grupo` (Excel: `desGrupo`)
- `skunidade` (Excel: `codUnidade`)
- `CNPJ` (Excel: `desCNPJ`) — **atenção: não é o CNPJ jurídico**, é um código de agrupamento (ex: 'Pueri Domus', 'ESF', 'HEB')

### Unidades Premium (idEstFiscal)

```
1012 — Pueri Domus Verbo
1013 — Pueri Domus Aclimação
1014 — Pueri Domus Itaim
1027 — Pueri Domus Perdizes
1039 — Pueri Domus Perdizes II
1040 — Ipiranga (escola ainda não aberta — tratamento especial, ver abaixo)
1901 — Sphere International School (unidade 1)
1902 — Sphere International School (unidade 2)
1903 — Sphere International School (unidade 3)
1904 — Sphere International School (unidade 4 — confirmar se já está ativa nas queries)
3502 — C. Patrício - Recreio
3601 — C. Patrício - Barra da Tijuca (ECRAN)
3602 — C. Patrício - Gente Miúda (ECRAN)
3603 — C. Patrício - Golfe Olímpico (ECRAN)
```

#### Regra de Ipiranga (1040) — escola pré-operacional

**Identificação no banco:** `Nome_Unidade = 'Pueri Domus Ipiranga'`, `skUnidade IN ('111010011040', '111020011040', '1040')`, `idEstFiscal = '1040'`

Ipiranga ainda não abriu. Nas queries por unidade ela deve ser **citada mas não somada no montante Premium**:

- **Excluir do subtotal Premium** — não entra na soma das unidades operacionais
- **Exibir como linha separada** — identificada explicitamente na tabela
- **Incluir no total final** — o total geral = subtotal Premium + Ipiranga

Padrão de output esperado:
```
Unidade A          | valor
Unidade B          | valor
...
Subtotal Premium   | soma (1012–1039, 1901–1903, 3502–3603)
Ipiranga           | valor
Total              | subtotal + Ipiranga
```

Isso se aplica a CAPEX e qualquer outra métrica por unidade que inclua Ipiranga. **Já implementado nas queries existentes** — ao escrever novas queries por unidade, replicar esse padrão.

Exclusão intencional (ensino superior, NÃO são Premium):
```sql
dc.idEstFiscal NOT IN ('1501', '1502', '1601', '5401', '6101')
```

O filtro `dc.CNPJ != 'HEB'` evita que entradas corporativas da HEB (ex: `idEstFiscal 3301`, Alta Vela Educação Básica) vazem para resultados Premium via tabelas fato.

### CNPJ = 'HEB' e a vertical Alta Performance (AP)

O Grupo SEB opera sob múltiplos CNPJs. `HEB` é um deles e agrupa as **escolas de Alta Performance (AP)** — uma vertical distinta da Premium. As queries Premium excluem HEB com `dc.CNPJ != 'HEB'` para não misturar as duas verticais. No futuro, AP terá suas próprias queries (ainda não implementadas).

### `financeiro.prd.f_alunos` — schema completo

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `idUnidadeOperacional` | string | Sempre `11101001` — código de sistema, inútil como join key |
| `idEstFiscal` | string | Código fiscal da unidade — existe na tabela, mas `skunidade` é a join key correta |
| `skUnidade` | string | Surrogate key — join 1:1 com `d_classunidades.skunidade` |
| `Segmento` | string | Nível de ensino (ex: Ensino Fundamental, Ensino Médio) |
| `Curso` | string | Curso específico |
| `Tipo` | string | Tipo de matrícula |
| `Data` | date | Mês de referência |
| `QtdAlunos` | int | Quantidade de alunos |

### mv_f_apresentacao — tabela central de dados financeiros

Apesar do nome "view materializada", é a principal fonte de dados para quase todas as queries financeiras Premium.

- Owner: Jonas Jobel
- Causa fan-out via tabela `link_unidades` quando feito join externo — NÃO usar como base de join para agregar valores com d_classunidades
- Para contornar o fan-out: filtrar por `f.Vertical = 'Premium'` diretamente na mv

**Colunas relevantes:**

| Coluna | Valores | Significado |
|--------|---------|-------------|
| `Vertical` | `'Premium'`, etc. | Filtra a vertical |
| `Nome_Unidade` | nome da escola | Usado para excluir CSC Local, Diretoria, Ipiranga |
| `Origem` | `'Resultado'`, `'Ajustes'`, `'Forecast'`, `'Budget'`, `'Alunos'` | Tipo do lançamento |
| `Data_Transacao` | date | Data do lançamento (ano/mês) |
| `Ebitda` | `'Sim'`/`'Não'` | Se a linha entra no escopo do EBITDA |
| `Recorrente` | `'Sim'`/`'Não'` | Se é recorrente (exclui extraordinários) |
| `ROL` | `1`/`0` | Se entra na Receita Operacional Líquida |
| `Nome_PnL` | ex: `'FOPAG Direto (CLT- PJ)'` | Linha do DRE — nível de agregação |
| `skclasspnl` | ex: `'400000000'` | Chave de classificação PnL (`'400000000'` = alunos) |
| `Valor` | numérico | **Receitas armazenadas como negativo** — sempre usar `Valor * -1` para receitas |
| `skUnidade` | string | Chave de unidade |

**Padrão de filtro para "realizado":** `Origem IN ('Resultado', 'Ajustes')`
**Padrão para Forecast:** `Origem = 'Forecast'`
**Padrão para Budget:** `Origem = 'Budget'`

**NÃO expõe:** `idEstFiscal`, `CNPJ`

### link_pnl — granularidade dentro do Nome_PnL

Join: `f.skclasspnl = lp.skclasspnl` → retorna `lp.Nome_Conta`

Usado quando se precisa de mais detalhe que `Nome_PnL`. Exemplo: dentro de `'FOPAG Direto (CLT- PJ)'`, o `Nome_Conta` diferencia Salários, Férias, INSS, FGTS, etc.

### f_orcamentoalunosrollingforecast (rolling forecast de alunos — query 01 e 02)

- Join com d_classunidades: `dc.skunidade = f.skUnidade` (1:1 para unidades Premium)
- Coluna `Versao`: `'Budget'` (meses 1–12), `'Forecast'` (meses 5–12), `'Realizado'` (meses 1–4)
- Lógica de média YTD (contagem de alunos é média mensal, não acumulado):
  - `mes_ytd ≤ 3` → snapshot do mês atual (`Versao = 'Realizado'`, `month = mes_ytd`)
  - `mes_ytd ≥ 4` → soma desde março / (mes_ytd - 2): Realizado meses 3–4 + Forecast meses 5–mes_ytd

### f_alunos_forecastrealizado (forecast histórico de alunos — query 04)

Tabela diferente da `f_orcamentoalunosrollingforecast`. Usada apenas na query 04 (histórico de alunos).

- Colunas: `CursoServico`, `Versao`, `month(Data)`, `year(Data)`, `QtdAlunos`, `Vertical`
- Filtro: `fr.Vertical = 'Premium'` diretamente na tabela (sem join com d_classunidades)
- Segmento derivado de `CursoServico` por LIKE: 1ST–5TH = EFI, 6TH–9TH = EFII, 10TH–12TH = EM, resto = EI
- Versao usada: `'Forecast'` (a tabela provavelmente tem outros, mas só Forecast é relevante aqui)

### CAPEX — três tabelas distintas

Todas em `financeiro.prd.*`:

| Tabela | Conteúdo | Join key | Coluna de valor |
|--------|---------|----------|-----------------|
| `f_capex` | CAPEX realizado | `skUnidade`, `idContaContabil` | `Valor_Relatorio` |
| `f_capexajustes` | Ajustes de CAPEX (sem Grupo_AtivoFixo) | `skUnidade` | `Valor_Relatorio` |
| `f_orcamentocapex` | Orçamento/Forecast de CAPEX | `skUnidade`, `idContaContabil` | `vlrOrcamento` |

**Grupo_AtivoFixo** — coluna de `f_capex` que categoriza o tipo de ativo. Para obter o grupo do orçamento, fazer: `f_orcamentocapex JOIN f_capex ON idContaContabil` (o f_capex mapeia idContaContabil → Grupo_AtivoFixo).

Categorias (Grupo_AtivoFixo → nome exibido):
```
'Benf. Imov'  → Benfeitorias Imóveis Terceiros
'Biblioteca'  → Biblioteca
'Comp. Per'   → Computadores e Periféricos
'Const.Anda'  → Construções em Andamento
'Eq. Tecnol'  → Tablets e Equipamentos Tecnológicos
'Instalac'    → Instalações
'Maq. Equip'  → Máquinas e Equipamentos
'Mov. Utens'  → Móveis e Utensílios
'Software'    → Softwares
```

**Join com d_classunidades em f_capex:** `du.skUnidade = fc.skUnidade`. Atenção — algumas linhas têm `skUnidade` curto (só os dígitos finais da unidade), exigindo lógica de módulo: `CAST(skUnidade AS BIGINT) IN (SELECT CAST(skUnidade AS BIGINT) % 10000 FROM d_classunidades WHERE Vertical = 'Premium')`.

**Ajustes no total:** `f_capexajustes` não tem `Grupo_AtivoFixo`, portanto seus valores não aparecem nas linhas individuais — entram somente no "Total CAPEX".

### Estrutura do DRE Premium (query 03) — linhas de P&L

Mapa completo de `Nome_PnL` na sequência do DRE:

**Receitas:**
- Receitas com Ensino Regular, Receitas com UpSelling
- (=) Receita de Ensino Bruta
- Bolsa de Estudos
- (=) Receita de Ensino
- Descontos Método de Assinatura
- Receita com Material Didático, Receita com Eventos, Outras Receitas, Bolsa de Colaborador
- Deduções (ISS, PIS, COFINS)
- **(=) ROL** ← base 100% para todos os % no relatório

**Custo com Mercadoria Vendida (CMV):**
- Material Físico, Material Digital, Bonificação
- (=) Custo com Mercadoria Vendida

**Custos Diretos:**
- FOPAG Direto (CLT-PJ), Eventos SEB, Outros Custos (Certificações + Alimentação + Mat. Pedagógico)
- (=) Total Custo Direto
- **(=) Margem de Contribuição** = ROL + CMV + Custo Direto

**Custos e Despesas Fixas:**
- Folha de Pagamento (= FOPAG Indireta), Benefícios, Cursos e Treinamentos
- Segurança e Limpeza, Consultorias e Honorários, Aluguel / IPTU, Conservação e Manutenção
- Tecnologia, Energia Elétrica e Água e Esgoto, Despesas com Viagens
- CSC Local, Corporativo BU, Rateio Corporativo
- Demais (Jurídicas + RPA + Mat. Escritório + Impostos + Demais Custos)
- (=) Total Custos e Despesas Fixas

**Despesas de Vendas:**
- Despesas com Marketing, PCLD, Despesas Bancárias + Isenções, Descontos Comerciais
- (=) Total Despesas de Vendas

**(=) EBITDA** = Margem de Contribuição + Total Custos Fixas + Total Despesas de Vendas

**Abaixo do EBITDA (query 12 — Lucro Líquido):**
- Provisão para Contigências, Despesas Indedutiveis, Ganhos/Perdas – Equivalência, Contratos Arrendamento IFRS16
- **(=) EBITDA Contábil**
- Depreciação/Amortização
- **(=) EBIT**
- Receita/(Despesa) financeira líquida
- **(=) LAIR** (Lucro Antes do IR)
- IR / CSLL
- **(=) Lucro Líquido**
- Outros result. em investimentos avaliados pela equivalência
- **(=) Lucro Líquido Conciliado**

Os itens abaixo do EBITDA **não** usam os flags `Ebitda='Sim'` e `Recorrente='Sim'` — filtram diretamente por `Nome_PnL` ou por `Ebitda='Não'`.

### Parâmetros nas queries — padrão real (bound params)

As queries Premium usam **bound parameters** passados pelo backend, não `year(current_date())` dinâmico:

```sql
with params as (
    select
        :ano_selecionado  as ano_atual,
        :ano_anterior     as ano_anterior,
        :mes_selecionado  as mes_ytd,
        'Premium'         as vertical
)
```

O frontend envia `ano_selecionado`, `ano_anterior`, `mes_selecionado` nas chamadas de API. As convenções de CLAUDE.md sobre aliases de coluna (`25R`, `26B`, `26F`, `26R`) continuam válidas.

### Pastas de queries

As pastas `backend/queries/financeiro/` e `backend/queries/diretorias/` existem mas estão **vazias** — prontas para futuras verticais.

---

## Estado do desenvolvimento (jun/2026)

### Implementações recentes

- **Query 02 — Rolling forecast por unidade**: CTE `fcst_alu_por_unidade` adicionada, fazendo join direto em `f_orcamentoalunosrollingforecast` via `skunidade` (contorna fan-out da mv_f_apresentacao). Lógica de snapshot vs. acumulado implementada.

### Débitos técnicos conhecidos

- **Query 01 — leve discrepância**: ROL/EBITDA retorna ~135.423 vs. ~136.881 no Excel de referência. Diferença não investigada — pode ser filtro de unidade ou período.
- **mv_f_apresentacao sem idEstFiscal/CNPJ**: Para adicionar essas colunas à view materializada é necessário coordenar com Jonas Jobel (owner). Até lá, queries que precisam dessas colunas devem fazer join direto na `d_classunidades`.

### DataTable.jsx — comportamentos não-óbvios

- Limita a **19 colunas** (slice hardcoded)
- Remove colunas `sort_order`, `sort_order ` (com espaço) e `id` automaticamente
- Linhas com "Maple Bear Escolas Próprias" em Vertical/Diretoria são **filtradas silenciosamente**
- Linhas com "Operações", "Total", "Corporativas" no campo vertical recebem estilo `subtotal-row`
- Separadores visuais nas colunas de índice: 1, 5, 9, 13, 15, 17
