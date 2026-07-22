-- @id: premium_beneficios_pueri_domus
-- @name: Premium - Benefícios YTD - Pueri Domus
-- @category: Premium
-- @order: 21

WITH params AS (
    SELECT
        :ano_selecionado AS ano_atual,
        :ano_anterior    AS ano_anterior,
        :mes_selecionado AS mes_ytd,
        'Premium'        AS vertical
),

beneficios_base AS (
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
      AND f.Grupo = 'Pueri Domus'
      AND f.idEstFiscal != '1040'
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria%'
      AND YEAR(f.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.Ebitda     = 'Sim'
      AND f.Recorrente = 'Sim'
      AND f.Nome_PnL   = 'Benefícios'
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
      AND f.Grupo = 'Pueri Domus'
      AND f.idEstFiscal != '1040'
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
        SUM(CASE WHEN ano = ano_anterior AND Origem = 'Ajustes'                 THEN Valor * -1 ELSE 0 END) / 1000 AS ant_adj,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'                THEN Valor * -1 ELSE 0 END) / 1000 AS atu_f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado', 'Ajustes') THEN Valor * -1 ELSE 0 END) / 1000 AS atu_r
    FROM beneficios_base
    GROUP BY Nome_Conta
),

rol AS (
    SELECT
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado', 'Ajustes') THEN Valor * -1 ELSE 0 END) / 1000 AS rol_ant,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'                THEN Valor * -1 ELSE 0 END) / 1000 AS rol_atu_f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado', 'Ajustes') THEN Valor * -1 ELSE 0 END) / 1000 AS rol_atu_r
    FROM rol_base
),

itens AS (
    SELECT
        m.Nome_Conta,
        m.ant_r, m.ant_adj, m.atu_f, m.atu_r,
        ROUND(m.ant_r, 0)                                                                                                                    AS `AntR`,
        ROUND(m.ant_adj, 0)                                                                                                                  AS `Ajustes`,
        ROUND(m.ant_r + m.ant_adj, 0)                                                                                                        AS `AntTotal`,
        ROUND(CASE WHEN r.rol_ant   <> 0 THEN (m.ant_r + m.ant_adj) / r.rol_ant   * 100 ELSE 0 END, 1)                                     AS `pct_ROL_Ant`,
        ROUND(m.atu_f, 0)                                                                                                                    AS `AtuF`,
        ROUND(CASE WHEN r.rol_atu_f <> 0 THEN m.atu_f / r.rol_atu_f * 100 ELSE 0 END, 1)                                                  AS `pct_ROL_AtuF`,
        ROUND(m.atu_r, 0)                                                                                                                    AS `AtuR`,
        ROUND(CASE WHEN r.rol_atu_r <> 0 THEN m.atu_r / r.rol_atu_r * 100 ELSE 0 END, 1)                                                  AS `pct_ROL_AtuR`,
        ROUND(m.atu_r - m.atu_f, 0)                                                                                                         AS `Var_Abs_FcstR`,
        ROUND(CASE WHEN m.atu_f <> 0 THEN (m.atu_r - m.atu_f) / ABS(m.atu_f) * 100 ELSE 0 END, 1)                                        AS `Var_Pct_FcstR`,
        ROUND(m.atu_r - (m.ant_r + m.ant_adj), 0)                                                                                           AS `Var_Abs_AntR`,
        ROUND(CASE WHEN (m.ant_r + m.ant_adj) <> 0 THEN (m.atu_r - (m.ant_r + m.ant_adj)) / ABS(m.ant_r + m.ant_adj) * 100 ELSE 0 END, 1) AS `Var_Pct_AntR`,
        ROUND(
            CASE WHEN r.rol_atu_r <> 0 THEN m.atu_r / r.rol_atu_r * 100 ELSE 0 END -
            CASE WHEN r.rol_atu_f <> 0 THEN m.atu_f / r.rol_atu_f * 100 ELSE 0 END
        , 1)                                                                                                                                  AS `Var_pp_FcstR`,
        CASE m.Nome_Conta
            WHEN 'Programa Aliment. Trabalhador' THEN 1
            WHEN 'Assistência Médica'             THEN 2
            WHEN 'Vale Transporte'                THEN 3
            WHEN 'Assistência Odontologica'        THEN 4
            WHEN 'Seguros de Vida'                THEN 5
            WHEN 'Uniformes'                      THEN 6
            ELSE 50
        END AS sort_order
    FROM metricas m
    CROSS JOIN rol r
)

-- Linhas individuais
SELECT
    Nome_Conta AS Descricao,
    `AntTotal`      AS `3M 25 R`,
    `pct_ROL_Ant`   AS `25R|% ROL`,
    `AtuF`          AS `3M 26 F`,
    `pct_ROL_AtuF`  AS `26F|% ROL`,
    `AtuR`          AS `3M 26 R`,
    `pct_ROL_AtuR`  AS `26R|% ROL`,
    `Var_Abs_FcstR` AS `Var #|26 x Fcst`,
    `Var_Pct_FcstR` AS `Var %|26 x Fcst`,
    `Var_Abs_AntR`  AS `Var #|26 x 25`,
    `Var_Pct_AntR`  AS `Var %|26 x 25`,
    `Var_pp_FcstR`  AS `Var %|p.p.`,
    sort_order
FROM itens
WHERE sort_order <> 50

UNION ALL

-- Total Benefícios
SELECT
    'Benefícios',
    ROUND(SUM(m.ant_r + m.ant_adj), 0),
    ROUND(CASE WHEN MAX(r.rol_ant)   <> 0 THEN SUM(m.ant_r + m.ant_adj) / MAX(r.rol_ant)   * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_f), 0),
    ROUND(CASE WHEN MAX(r.rol_atu_f) <> 0 THEN SUM(m.atu_f)             / MAX(r.rol_atu_f) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r), 0),
    ROUND(CASE WHEN MAX(r.rol_atu_r) <> 0 THEN SUM(m.atu_r)             / MAX(r.rol_atu_r) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r - m.atu_f), 0),
    ROUND(CASE WHEN SUM(m.atu_f) <> 0 THEN (SUM(m.atu_r) - SUM(m.atu_f)) / ABS(SUM(m.atu_f)) * 100 ELSE 0 END, 1),
    ROUND(SUM(m.atu_r - (m.ant_r + m.ant_adj)), 0),
    ROUND(CASE WHEN SUM(m.ant_r + m.ant_adj) <> 0 THEN (SUM(m.atu_r) - SUM(m.ant_r + m.ant_adj)) / ABS(SUM(m.ant_r + m.ant_adj)) * 100 ELSE 0 END, 1),
    ROUND(
        CASE WHEN MAX(r.rol_atu_r) <> 0 THEN SUM(m.atu_r) / MAX(r.rol_atu_r) * 100 ELSE 0 END -
        CASE WHEN MAX(r.rol_atu_f) <> 0 THEN SUM(m.atu_f) / MAX(r.rol_atu_f) * 100 ELSE 0 END
    , 1),
    100
FROM metricas m
CROSS JOIN rol r
WHERE m.Nome_Conta IN (
    'Programa Aliment. Trabalhador', 'Assistência Médica', 'Vale Transporte',
    'Assistência Odontologica', 'Seguros de Vida', 'Uniformes'
)

ORDER BY sort_order
