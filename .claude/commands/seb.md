# Contexto de negócio — Grupo SEB / Dashboard Business Review Premium

Você está trabalhando no dashboard interno do Grupo SEB para Business Review da vertical **Premium**. Este arquivo contém todo o conhecimento institucional necessário para escrever queries Databricks e entender os dados.

---

## Stack

- Backend: Flask (Python) + Databricks SQL
- Frontend: React (Vite)
- Auth/comentários: SQLite
- Queries ficam em `backend/queries/Premium/` — todas usam bound params (`:ano_selecionado`, `:ano_anterior`, `:mes_selecionado`)

---

## Grupo SEB — estrutura de verticais

| Vertical | Holding/CNPJ | Escolas |
|----------|-------------|---------|
| **Premium** | SEB | Pueri Domus (SP), Sphere (SJC), C. Patrício (RJ) |
| **Alta Performance (AP)** | HEB | Sartre, Dom Bosco, SEB Ribeirão, COC Floripa, SEB Maceió, Unimaster, SEB Brasília, etc. |
| **Ensino Superior** | SEB | Faculdade Dom Bosco (1501/1502), EPD (1601) |
| **Vanguarda** | SEB | Concept Ribeirão, Concept SP, Concept Salvador |
| **Maple Bear Escolas Próprias** | SEB | Escolas em Brasília |
| **Franquias** | NWC | Maple Bear Brasil, Sphere Franquias, Luminova |
| **Conexia** | CNX | Plataforma de tecnologia educacional |
| **MBGS** | Outros | Maple Bear Global Schools (40+ países) |

> A coluna `CNPJ` em `d_classunidades` **não é o CNPJ jurídico** — é um código de agrupamento interno (ex: `'HEB'`, `'Pueri Domus'`, `'ESF'`). O filtro `dc.CNPJ != 'HEB'` impede que entidades corporativas da Alta Performance vazem para resultados Premium.

---

## Unidades Premium (idEstFiscal)

```
1012 — Pueri Domus Verbo
1013 — Pueri Domus Aclimação
1014 — Pueri Domus Itaim
1027 — Pueri Domus Perdizes
1039 — Pueri Domus Perdizes II
1040 — Pueri Domus Ipiranga  ← escola pré-operacional (regra especial abaixo)
1901 — Sphere International School 1
1902 — Sphere International School 2
1903 — Sphere International School 3
1904 — Sphere International School 4
3502 — C. Patrício - Recreio
3601 — C. Patrício - Barra da Tijuca (ECRAN)
3602 — C. Patrício - Gente Miúda (ECRAN)
3603 — C. Patrício - Golfe Olímpico (ECRAN)
```

### Regra de Ipiranga (1040)

Escola ainda não abriu. Em **toda query por unidade**:

- Exclui do subtotal Premium
- Exibe como linha separada
- Inclui no total final: `Total = Subtotal Premium + Ipiranga`

Identificação: `Nome_Unidade = 'Pueri Domus Ipiranga'` / `skUnidade IN ('111010011040', '111020011040', '1040')`

---

## Tabelas principais no Databricks (`financeiro.prd.*`)

### `mv_f_apresentacao` — tabela central financeira

Fonte de quase todas as queries. Owner: Jonas Jobel.

| Coluna | Valores | Significado |
|--------|---------|-------------|
| `Vertical` | `'Premium'`, etc. | Filtro de vertical — usar `f.Vertical = 'Premium'` diretamente |
| `Nome_Unidade` | nome da escola | Filtrar exclusões (CSC Local, Diretoria, Ipiranga) |
| `Origem` | `'Resultado'`, `'Ajustes'`, `'Forecast'`, `'Budget'`, `'Alunos'` | Tipo do lançamento |
| `Data_Transacao` | date | Data do lançamento (ano/mês) |
| `Ebitda` | `'Sim'`/`'Não'` | Se entra no escopo do EBITDA |
| `Recorrente` | `'Sim'`/`'Não'` | Se é recorrente (exclui extraordinários) |
| `ROL` | `1`/`0` | Flag de Receita Operacional Líquida |
| `Nome_PnL` | ex: `'FOPAG Direto (CLT- PJ)'` | Linha do DRE |
| `skclasspnl` | ex: `'400000000'` | Chave PnL (`'400000000'` = alunos) |
| `Valor` | numérico | **Receitas armazenadas como negativo** → usar `Valor * -1` |
| `skUnidade` | string | Join 1:1 com `d_classunidades.skunidade` |

**Padrões de filtro:**
- Realizado: `Origem IN ('Resultado', 'Ajustes')`
- Forecast: `Origem = 'Forecast'`
- Budget: `Origem = 'Budget'`
- Alunos: `Origem = 'Alunos'` + `skclasspnl = '400000000'`

**NÃO expõe** `idEstFiscal` nem `CNPJ`.

**Fan-out:** a mv causa duplicação quando feito join com `d_classunidades` via `link_unidades`. Sempre filtrar `f.Vertical = 'Premium'` diretamente na mv, sem fazer join externo para agregar.

### `d_classunidades` — dimensão de unidades

Tem **múltiplas linhas por unidade**: `codPadrao = 'Sim'` (linha principal) + variantes `'Não'` (CSC Local, Diretoria, Franquias).

| Join key | Comportamento |
|----------|--------------|
| `skunidade` | 1:1 com tabelas fato — **preferir sempre** |
| `codPadrao = 'Sim'` | Filtra só linhas primárias — alternativa ao NOT LIKE |
| `idEstFiscal` | N linhas por unidade — usar só com `codPadrao = 'Sim'` |
| `idUnidadeOperacional` | Sempre `11101001` — **nunca usar como join key** |

### `link_pnl` — granularidade abaixo de `Nome_PnL`

Join: `lp.skclasspnl = f.skclasspnl` → expõe `lp.Nome_Conta` (ex: Salários, Férias, INSS dentro de FOPAG Direto).

### `f_alunos` — fato de alunos

Colunas: `skUnidade`, `idEstFiscal`, `idUnidadeOperacional`, `Segmento`, `Curso`, `Tipo`, `Data`, `QtdAlunos`.

### `f_orcamentoalunosrollingforecast` — rolling forecast de alunos (queries 01 e 02)

- `Versao`: `'Budget'` (meses 1–12), `'Forecast'` (meses 5–12), `'Realizado'` (meses 1–4)
- Contagem de alunos é **média mensal**, não acumulado:
  - `mes_ytd ≤ 3`: snapshot do mês (`Versao = 'Realizado'`, `month = mes_ytd`)
  - `mes_ytd ≥ 4`: soma mar–mes_ytd ÷ (mes_ytd - 2)

### `f_alunos_forecastrealizado` — histórico de alunos (query 04)

Tabela diferente do rolling forecast. Colunas: `CursoServico`, `Versao`, `month(Data)`, `year(Data)`, `QtdAlunos`, `Vertical`.
Segmento derivado de `CursoServico`: 1ST–5TH = EFI, 6TH–9TH = EFII, 10TH–12TH = EM, resto = EI.

### CAPEX — três tabelas distintas

| Tabela | Conteúdo | Valor |
|--------|---------|-------|
| `f_capex` | Realizado — tem `Grupo_AtivoFixo`, `idContaContabil` | `Valor_Relatorio` |
| `f_capexajustes` | Ajustes — sem `Grupo_AtivoFixo` (só vai ao total) | `Valor_Relatorio` |
| `f_orcamentocapex` | Budget/Forecast — `Versao`, sem `Grupo_AtivoFixo` | `vlrOrcamento` |

Para obter `Grupo_AtivoFixo` do orçamento: `f_orcamentocapex JOIN f_capex ON idContaContabil`.

Categorias: `'Benf. Imov'`, `'Biblioteca'`, `'Comp. Per'`, `'Const.Anda'`, `'Eq. Tecnol'`, `'Instalac'`, `'Maq. Equip'`, `'Mov. Utens'`, `'Software'`.

---

## Estrutura do DRE Premium (`Nome_PnL` → sequência)

**Receitas → ROL:**
Receitas c/ Ensino Regular → Receitas c/ UpSelling → (=) Receita de Ensino Bruta → Bolsa de Estudos → (=) Receita de Ensino → Descontos Assinatura → Mat. Didático + Eventos + Outras Receitas + Bolsa Colaborador → Deduções (ISS, PIS, COFINS) → **(=) ROL** ← base 100% dos percentuais

**CMV:**
Material Físico + Material Digital + Bonificação → (=) Custo com Mercadoria Vendida

**Custos Diretos:**
FOPAG Direto (CLT-PJ) + Eventos SEB + Outros Custos → (=) Total Custo Direto
**(=) Margem de Contribuição** = ROL + CMV + Custo Direto

**Custos e Despesas Fixas:**
FOPAG Indireta + Benefícios + Cursos/Treinamentos + Seg./Limpeza + Consultorias + Aluguel/IPTU + Conservação/Manut. + Tecnologia + Energia/Água + Viagens + CSC Local + Corporativo BU + Rateio Corporativo + Demais → (=) Total Custos Fixas

**Despesas de Vendas:**
Marketing + PCLD + Desp. Bancárias + Isenções + Descontos Comerciais → (=) Total Despesas de Vendas

**(=) EBITDA**

**Abaixo do EBITDA (query 12):**
+ Provisão Contigências + Desp. Indedutiveis + Ganhos/Perdas Equivalência + IFRS16 → **(=) EBITDA Contábil**
+ Depreciação/Amortização → **(=) EBIT**
+ Receita/(Desp.) Financeira → **(=) LAIR**
+ IR/CSLL → **(=) Lucro Líquido**
+ Outros equiv. → **(=) Lucro Líquido Conciliado**

> Itens abaixo do EBITDA **não** usam os flags `Ebitda='Sim'`/`Recorrente='Sim'` — filtram por `Nome_PnL` específico ou `Ebitda='Não'`.

---

## Padrão de params em toda query Premium

```sql
with params as (
    select
        :ano_selecionado  as ano_atual,
        :ano_anterior     as ano_anterior,
        :mes_selecionado  as mes_ytd,
        'Premium'         as vertical
)
```

O frontend envia os três parâmetros em cada chamada de API.

## Aliases de coluna padrão no SELECT final

- Métricas consolidadas: `25R`, `26B`, `26F`, `26R`, `Var 26xBgt`, `Var% 26xBgt`
- Por unidade: `25R_Alu`, `25R_ROL`, `25R_EBT`, `25R_Mg`, `26B_Alu`, etc.

---

## Convenções SQL deste projeto

- Sem separadores decorativos (`-- ===`)
- CTEs com nomes que refletem raciocínio real (`receita_liquida`, não `dados_classificados`)
- Comentários explicam o **porquê**, não o quê
- Nunca hardcodar anos — usar `ano_atual` / `ano_anterior` dos params
- Sempre perguntar antes de assumir colunas desconhecidas ou regras de negócio
