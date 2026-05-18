-- @id: premium_pcld
-- @name: Premium - PCLD
-- @category: Premium
-- @order: 15
-- @chart_query_id: Premium/premium_pcld_grafico

WITH params AS (
    SELECT
        :ano_selecionado AS ano_atual,
        :ano_anterior    AS ano_anterior,
        :mes_selecionado AS mes_ytd,
        'Premium'        AS vertical
),

pcld_base AS (
    SELECT
        lp.Nome_Conta,
        f.Origem,
        YEAR(f.Data_Transacao) AS ano,
        f.Valor,
        p.ano_atual,
        p.ano_anterior
    FROM financeiro.prd.mv_f_apresentacao f
    JOIN financeiro.prd.link_pnl lp ON f.skclasspnl = lp.skclasspnl
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria%'
      AND YEAR(f.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.Ebitda     = 'Sim'
      AND f.Recorrente = 'Sim'
      AND f.Nome_PnL   = 'PCLD'
),

rol_base AS (
    SELECT
        f.Origem,
        YEAR(f.Data_Transacao) AS ano,
        f.Valor,
        p.ano_atual,
        p.ano_anterior
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria%'
      AND YEAR(f.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.ROL        = 1
      AND f.Ebitda     = 'Sim'
      AND f.Recorrente = 'Sim'
),

metricas AS (
    SELECT
        Nome_Conta,
        SUM(CASE WHEN ano = ano_anterior AND Origem = 'Resultado'               THEN Valor * -1 ELSE 0 END) / 1000 AS ant_r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'                THEN Valor * -1 ELSE 0 END) / 1000 AS atu_f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado', 'Ajustes') THEN Valor * -1 ELSE 0 END) / 1000 AS atu_r
    FROM pcld_base
    GROUP BY Nome_Conta
),

rol AS (
    SELECT
        SUM(CASE WHEN ano = ano_anterior AND Origem = 'Resultado'               THEN Valor * -1 ELSE 0 END) / 1000 AS rol_ant,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'                THEN Valor * -1 ELSE 0 END) / 1000 AS rol_atu_f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado', 'Ajustes') THEN Valor * -1 ELSE 0 END) / 1000 AS rol_atu_r
    FROM rol_base
),

itens AS (
    SELECT
        m.Nome_Conta,
        m.ant_r, m.atu_f, m.atu_r,
        ROUND(m.ant_r, 0)                                                                                            AS `AntR`,
        ROUND(CASE WHEN r.rol_ant   <> 0 THEN m.ant_r / r.rol_ant   * 100 ELSE 0 END, 1)                           AS `pct_ROL_Ant`,
        ROUND(m.atu_f, 0)                                                                                            AS `AtuF`,
        ROUND(CASE WHEN r.rol_atu_f <> 0 THEN m.atu_f / r.rol_atu_f * 100 ELSE 0 END, 1)                          AS `pct_ROL_AtuF`,
        ROUND(m.atu_r, 0)                                                                                            AS `AtuR`,
        ROUND(CASE WHEN r.rol_atu_r <> 0 THEN m.atu_r / r.rol_atu_r * 100 ELSE 0 END, 1)                          AS `pct_ROL_AtuR`,
        ROUND(m.atu_r - m.atu_f, 0)                                                                                  AS `Var_Abs_FcstR`,
        ROUND(CASE WHEN m.atu_f <> 0 THEN (m.atu_r - m.atu_f) / ABS(m.atu_f) * 100 ELSE 0 END, 1)                AS `Var_Pct_FcstR`,
        ROUND(m.atu_r - m.ant_r, 0)                                                                                  AS `Var_Abs_AntR`,
        ROUND(CASE WHEN m.ant_r <> 0 THEN (m.atu_r - m.ant_r) / ABS(m.ant_r) * 100 ELSE 0 END, 1)                AS `Var_Pct_AntR`,
        CASE m.Nome_Conta
            WHEN 'Provisão para Credito Liquidação Duvidosa' THEN 1
            WHEN 'Reversão PCLD'                             THEN 2
            ELSE 50
        END AS sort_order
    FROM metricas m
    CROSS JOIN rol r
)

-- Linhas individuais
SELECT
    Nome_Conta AS Descricao,
    `AntR`, `pct_ROL_Ant`,
    `AtuF`, `pct_ROL_AtuF`,
    `AtuR`, `pct_ROL_AtuR`,
    `Var_Abs_FcstR`, `Var_Pct_FcstR`,
    `Var_Abs_AntR`,  `Var_Pct_AntR`,
    sort_order
FROM itens
WHERE sort_order <> 50

UNION ALL

-- Total PCLD
SELECT
    'PCLD',
    ROUND(SUM(m.ant_r), 0),
    ROUND(CASE WHEN MAX(r.rol_ant)   <> 0 THEN SUM(m.ant_r) / MAX(r.rol_ant)   * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_f), 0),
    ROUND(CASE WHEN MAX(r.rol_atu_f) <> 0 THEN SUM(m.atu_f) / MAX(r.rol_atu_f) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r), 0),
    ROUND(CASE WHEN MAX(r.rol_atu_r) <> 0 THEN SUM(m.atu_r) / MAX(r.rol_atu_r) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r - m.atu_f), 0),
    ROUND(CASE WHEN SUM(m.atu_f) <> 0 THEN (SUM(m.atu_r) - SUM(m.atu_f)) / ABS(SUM(m.atu_f)) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r - m.ant_r), 0),
    ROUND(CASE WHEN SUM(m.ant_r) <> 0 THEN (SUM(m.atu_r) - SUM(m.ant_r)) / ABS(SUM(m.ant_r)) * 100 ELSE 0 END, 1),
    100
FROM metricas m
CROSS JOIN rol r
WHERE m.Nome_Conta IN ('Provisão para Credito Liquidação Duvidosa', 'Reversão PCLD')

ORDER BY sort_order