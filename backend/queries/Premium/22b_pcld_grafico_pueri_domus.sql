-- @id: premium_pcld_grafico_pueri_domus
-- @name: Premium - PCLD Gráfico - Pueri Domus
-- @category: Premium
-- @type: chart
-- @order: 22

WITH params AS (
    SELECT
        :ano_selecionado AS ano_atual,
        :ano_anterior    AS ano_anterior,
        :mes_selecionado AS mes_ytd,
        'Premium'        AS vertical
),

-- Histórico (2025R) e Realizado (2026R): com Ebitda/Recorrente, sem flip de sinal
hst_mensal AS (
    SELECT
        YEAR(f.Data_Transacao)  AS ano,
        MONTH(f.Data_Transacao) AS mes,
        f.Origem,
        SUM(f.Valor) AS total
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND f.Grupo = 'Pueri Domus'
      AND f.idEstFiscal != '1040'
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND YEAR(f.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND f.Ebitda   = 'Sim'
      AND f.Recorrente = 'Sim'
      AND f.Nome_PnL = 'PCLD'
      AND f.Origem IN ('Resultado', 'Ajustes')
    GROUP BY YEAR(f.Data_Transacao), MONTH(f.Data_Transacao), f.Origem
),

-- Forecast (2026F): sem Ebitda/Recorrente (fonte fcst_budget), sem flip de sinal
fcst_mensal AS (
    SELECT
        MONTH(f.Data_Transacao) AS mes,
        SUM(f.Valor) AS total
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND f.Grupo = 'Pueri Domus'
      AND f.idEstFiscal != '1040'
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND YEAR(f.Data_Transacao) = p.ano_atual
      AND f.Nome_PnL = 'PCLD'
      AND f.Origem   = 'Forecast'
    GROUP BY MONTH(f.Data_Transacao)
),

meses AS (SELECT explode(sequence(1, 12)) AS mes),

-- Ano anterior soma Resultado+Ajustes; ano atual (realizado) usa só Resultado
ant_agg AS (
    SELECT mes, SUM(total) AS total
    FROM hst_mensal, params p
    WHERE ano = p.ano_anterior
    GROUP BY mes
),
atu_agg AS (
    SELECT mes, SUM(total) AS total
    FROM hst_mensal, params p
    WHERE ano = p.ano_atual
      AND Origem = 'Resultado'
    GROUP BY mes
),

-- Juntar meses com dados mensais de cada série
base_mensal AS (
    SELECT
        m.mes,
        p.mes_ytd,
        COALESCE(ant.total, 0) AS ant_r_mes,
        COALESCE(atu.total, 0) AS atu_r_mes,
        COALESCE(f2.total,  0) AS atu_f_mes
    FROM meses m
    CROSS JOIN params p
    LEFT JOIN ant_agg     ant ON ant.mes = m.mes
    LEFT JOIN atu_agg     atu ON atu.mes = m.mes
    LEFT JOIN fcst_mensal f2  ON f2.mes  = m.mes
)

SELECT
    mes,
    ROUND(SUM(ant_r_mes) OVER (ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000, 0) AS val_ant_r,
    ROUND(SUM(atu_f_mes) OVER (ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000, 0) AS val_atu_f,
    CASE WHEN mes <= mes_ytd
         THEN ROUND(SUM(atu_r_mes) OVER (ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000, 0)
         ELSE NULL
    END AS val_atu_r
FROM base_mensal
ORDER BY mes
