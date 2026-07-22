-- @id: premium_variacao_orcado
-- @name: EBITDA Variações por tema YTD - Consolidado
-- @category: Premium
-- @type: table
-- @order: 03

WITH params AS (
    SELECT
        :ano_selecionado AS ano_atual,
        :mes_selecionado AS mes_ytd,
        'Premium'        AS vertical
),

base AS (
    SELECT
        f.Nome_Unidade,
        f.Nome_PnL,
        SUM(CASE WHEN f.Origem IN ('Resultado', 'Ajustes') THEN f.Valor ELSE 0 END) AS atu_r,
        SUM(CASE WHEN f.Origem = 'Forecast'                THEN f.Valor ELSE 0 END) AS atu_f
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria%'
      AND YEAR(f.Data_Transacao) = p.ano_atual
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.Ebitda     = 'Sim'
      AND f.Recorrente = 'Sim'
    GROUP BY f.Nome_Unidade, f.Nome_PnL
),

-- Valores sem arredondamento por unidade — subtotais arredondam uma vez só (igual ao Excel)
pivot_raw AS (
    SELECT
        Nome_Unidade,
        CASE
            WHEN Nome_Unidade LIKE 'Pueri Domus%'            THEN 'Pueri Domus'
            WHEN Nome_Unidade LIKE 'C. Patrício%'            THEN 'C. Patrício'
            WHEN Nome_Unidade = 'Sphere International School' THEN 'International School'
        END AS grupo,

        SUM(atu_f - atu_r) / 1000 AS ebitda,

        SUM(CASE WHEN Nome_PnL IN (
            'Receitas com Ensino Regular', 'Receitas com UpSelling',
            'Receita com Material Didático', 'Receita com Eventos', 'Outras Receitas',
            'Deduções', 'Descontos Comerciais', 'Descontos Método de Assinatura',
            'Bolsa de Estudos', 'Bolsa de Colaborador'
        ) THEN atu_f - atu_r ELSE 0 END) / 1000 AS rol,

        SUM(CASE WHEN Nome_PnL IN (
            'Custo do Material Físico', 'Custo do Material Dígital', 'Materiais Pedagógicos'
        ) THEN atu_f - atu_r ELSE 0 END) / 1000 AS mat_didatico,

        SUM(CASE WHEN Nome_PnL = 'FOPAG Direto (CLT- PJ)'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS fopag_dir,

        SUM(CASE WHEN Nome_PnL = 'Folha de Pagamento'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS fopag_ind,

        SUM(CASE WHEN Nome_PnL = 'Benefícios'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS beneficios,

        SUM(CASE WHEN Nome_PnL = 'Consultorias e Honorários'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS consultorias,

        SUM(CASE WHEN Nome_PnL = 'Aluguel / IPTU'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS aluguel_iptu,

        SUM(CASE WHEN Nome_PnL = 'Rateio Corporativo'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS rateio_corp,

        SUM(CASE WHEN Nome_PnL = 'Despesas com Marketing'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS marketing,

        SUM(CASE WHEN Nome_PnL = 'PCLD'
            THEN atu_f - atu_r ELSE 0 END) / 1000 AS pcld,

        SUM(CASE WHEN Nome_PnL NOT IN (
            'Receitas com Ensino Regular', 'Receitas com UpSelling',
            'Receita com Material Didático', 'Receita com Eventos', 'Outras Receitas',
            'Deduções', 'Descontos Comerciais', 'Descontos Método de Assinatura',
            'Bolsa de Estudos', 'Bolsa de Colaborador',
            'Custo do Material Físico', 'Custo do Material Dígital', 'Materiais Pedagógicos',
            'FOPAG Direto (CLT- PJ)', 'Folha de Pagamento', 'Benefícios',
            'Consultorias e Honorários', 'Aluguel / IPTU', 'Rateio Corporativo',
            'Despesas com Marketing', 'PCLD'
        ) THEN atu_f - atu_r ELSE 0 END) / 1000 AS outros

    FROM base
    GROUP BY Nome_Unidade,
        CASE
            WHEN Nome_Unidade LIKE 'Pueri Domus%'            THEN 'Pueri Domus'
            WHEN Nome_Unidade LIKE 'C. Patrício%'            THEN 'C. Patrício'
            WHEN Nome_Unidade = 'Sphere International School' THEN 'International School'
        END
)

SELECT unidade, ebitda, rol, mat_didatico, fopag_dir, fopag_ind,
    beneficios, consultorias, aluguel_iptu, rateio_corp, marketing, pcld, outros
FROM (

-- Linhas zeradas: exibidas mas excluídas dos cálculos
SELECT 1 AS sort_group, 1 AS sort_order, 'Diretoria Premium - Pueri Domus' AS unidade,
    0 AS ebitda, 0 AS rol, 0 AS mat_didatico, 0 AS fopag_dir, 0 AS fopag_ind,
    0 AS beneficios, 0 AS consultorias, 0 AS aluguel_iptu, 0 AS rateio_corp,
    0 AS marketing, 0 AS pcld, 0 AS outros

UNION ALL
SELECT 1, 2, 'Pueri Domus - CSC Local',
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

UNION ALL

-- Linhas individuais Pueri Domus
SELECT 1, 10, Nome_Unidade,
    ROUND(ebitda, 0), ROUND(rol, 0), ROUND(mat_didatico, 0), ROUND(fopag_dir, 0),
    ROUND(fopag_ind, 0), ROUND(beneficios, 0), ROUND(consultorias, 0),
    ROUND(aluguel_iptu, 0), ROUND(rateio_corp, 0), ROUND(marketing, 0),
    ROUND(pcld, 0), ROUND(outros, 0)
FROM pivot_raw WHERE grupo = 'Pueri Domus'

UNION ALL

-- Subtotais: somam valores brutos e arredondam uma vez (evita erro de duplo arredondamento)
SELECT 2, 1, 'Pueri Domus',
    ROUND(SUM(ebitda), 0), ROUND(SUM(rol), 0), ROUND(SUM(mat_didatico), 0),
    ROUND(SUM(fopag_dir), 0), ROUND(SUM(fopag_ind), 0), ROUND(SUM(beneficios), 0),
    ROUND(SUM(consultorias), 0), ROUND(SUM(aluguel_iptu), 0), ROUND(SUM(rateio_corp), 0),
    ROUND(SUM(marketing), 0), ROUND(SUM(pcld), 0), ROUND(SUM(outros), 0)
FROM pivot_raw WHERE grupo = 'Pueri Domus'

UNION ALL
SELECT 3, 1, 'C. Patrício',
    ROUND(SUM(ebitda), 0), ROUND(SUM(rol), 0), ROUND(SUM(mat_didatico), 0),
    ROUND(SUM(fopag_dir), 0), ROUND(SUM(fopag_ind), 0), ROUND(SUM(beneficios), 0),
    ROUND(SUM(consultorias), 0), ROUND(SUM(aluguel_iptu), 0), ROUND(SUM(rateio_corp), 0),
    ROUND(SUM(marketing), 0), ROUND(SUM(pcld), 0), ROUND(SUM(outros), 0)
FROM pivot_raw WHERE grupo = 'C. Patrício'

UNION ALL
SELECT 4, 1, 'International School',
    ROUND(SUM(ebitda), 0), ROUND(SUM(rol), 0), ROUND(SUM(mat_didatico), 0),
    ROUND(SUM(fopag_dir), 0), ROUND(SUM(fopag_ind), 0), ROUND(SUM(beneficios), 0),
    ROUND(SUM(consultorias), 0), ROUND(SUM(aluguel_iptu), 0), ROUND(SUM(rateio_corp), 0),
    ROUND(SUM(marketing), 0), ROUND(SUM(pcld), 0), ROUND(SUM(outros), 0)
FROM pivot_raw WHERE grupo = 'International School'

UNION ALL
SELECT 5, 1, 'Total YTD',
    ROUND(SUM(ebitda), 0), ROUND(SUM(rol), 0), ROUND(SUM(mat_didatico), 0),
    ROUND(SUM(fopag_dir), 0), ROUND(SUM(fopag_ind), 0), ROUND(SUM(beneficios), 0),
    ROUND(SUM(consultorias), 0), ROUND(SUM(aluguel_iptu), 0), ROUND(SUM(rateio_corp), 0),
    ROUND(SUM(marketing), 0), ROUND(SUM(pcld), 0), ROUND(SUM(outros), 0)
FROM pivot_raw

) ORDER BY sort_group, sort_order, unidade
