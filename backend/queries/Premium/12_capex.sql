-- @id: premium_capex_ytd
-- @name: Premium - CAPEX YTD
-- @category: Premium
-- @type: table
-- @order: 18

WITH params AS (
    SELECT
        :ano_selecionado  AS ano_atual,
        :ano_anterior     AS ano_anterior,
        :mes_selecionado  AS mes_ytd,
        'Premium'         AS vertical
),

-- ROL Premium (Resultado + Ajustes) — denominador correto para %ROL do CAPEX
rol_premium AS (
    SELECT
        SUM(CASE WHEN YEAR(f.Data_Transacao) = p.ano_anterior AND f.Origem IN ('Resultado','Ajustes') AND f.Ebitda = 'Sim' AND f.Recorrente = 'Sim'
             THEN f.Valor * -1 ELSE 0 END) / 1000 AS rol_25r,
        SUM(CASE WHEN YEAR(f.Data_Transacao) = p.ano_atual    AND f.Origem IN ('Resultado','Ajustes') AND f.Ebitda = 'Sim' AND f.Recorrente = 'Sim'
             THEN f.Valor * -1 ELSE 0 END) / 1000 AS rol_26r
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND YEAR(f.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.ROL = 1
),

-- CAPEX Realizado por Grupo_AtivoFixo (f_capex já tem o campo preenchido)
capex_realizado AS (
    SELECT
        fc.Grupo_AtivoFixo,
        SUM(CASE WHEN YEAR(fc.Data_Transacao) = p.ano_anterior THEN fc.Valor_Relatorio ELSE 0 END) / 1000 AS val_25r,
        SUM(CASE WHEN YEAR(fc.Data_Transacao) = p.ano_atual    THEN fc.Valor_Relatorio ELSE 0 END) / 1000 AS val_26r
    FROM financeiro.prd.f_capex fc
    LEFT JOIN financeiro.prd.d_classunidades du ON du.skUnidade = fc.skUnidade
    CROSS JOIN params p
    WHERE (
        du.Vertical = p.vertical
        OR (
            du.skUnidade IS NULL
            AND CAST(fc.skUnidade AS BIGINT) IN (
                SELECT CAST(skUnidade AS BIGINT) % 10000
                FROM financeiro.prd.d_classunidades
                WHERE Vertical = p.vertical
            )
        )
    )
      AND YEAR(fc.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(fc.Data_Transacao) <= p.mes_ytd
      AND fc.Grupo_AtivoFixo IS NOT NULL
      AND fc.Grupo_AtivoFixo != ''
    GROUP BY fc.Grupo_AtivoFixo
),

-- Ajustes CAPEX (f_capexajustes — sem Grupo_AtivoFixo, vai para total)
capex_ajustes AS (
    SELECT
        SUM(CASE WHEN YEAR(fa.Data_Transacao) = p.ano_anterior THEN fa.Valor_Relatorio ELSE 0 END) / 1000 AS ajuste_25r,
        SUM(CASE WHEN YEAR(fa.Data_Transacao) = p.ano_atual    THEN fa.Valor_Relatorio ELSE 0 END) / 1000 AS ajuste_26r
    FROM financeiro.prd.f_capexajustes fa
    LEFT JOIN financeiro.prd.d_classunidades du ON du.skUnidade = fa.skUnidade
    CROSS JOIN params p
    WHERE (
        du.Vertical = p.vertical
        OR (
            du.skUnidade IS NULL
            AND CAST(fa.skUnidade AS BIGINT) IN (
                SELECT CAST(skUnidade AS BIGINT) % 10000
                FROM financeiro.prd.d_classunidades
                WHERE Vertical = p.vertical
            )
        )
    )
      AND YEAR(fa.Data_Transacao) IN (p.ano_atual, p.ano_anterior)
      AND MONTH(fa.Data_Transacao) <= p.mes_ytd
),

-- Forecast por Grupo_AtivoFixo via join idContaContabil (f_orcamentocapex não tem Grupo_AtivoFixo direto)
capex_orcamento AS (
    SELECT
        fc_map.Grupo_AtivoFixo,
        SUM(fo.vlrOrcamento) / 1000 AS val_26f
    FROM financeiro.prd.f_orcamentocapex fo
    LEFT JOIN financeiro.prd.d_classunidades du ON du.skUnidade = fo.skUnidade
    LEFT JOIN (
        SELECT DISTINCT idContaContabil, Grupo_AtivoFixo
        FROM financeiro.prd.f_capex
        WHERE Grupo_AtivoFixo IS NOT NULL AND Grupo_AtivoFixo != ''
    ) fc_map ON fc_map.idContaContabil = fo.idContaContabil
    CROSS JOIN params p
    WHERE du.Vertical = p.vertical
      AND fo.Versao = 'Forecast'
      AND YEAR(fo.Data) = p.ano_atual
      AND MONTH(fo.Data) <= p.mes_ytd
      AND fc_map.Grupo_AtivoFixo IS NOT NULL
    GROUP BY fc_map.Grupo_AtivoFixo
),

capex_display AS (
    SELECT
        CASE r.Grupo_AtivoFixo
            WHEN 'Benf. Imov'  THEN 'Benfeitorias Imóveis Terceiros'
            WHEN 'Biblioteca'  THEN 'Biblioteca'
            WHEN 'Comp. Per'   THEN 'Computadores e Periféricos'
            WHEN 'Const.Anda'  THEN 'Construções em Andamento'
            WHEN 'Eq. Tecnol'  THEN 'Tablets e Equipamentos Tecnológicos'
            WHEN 'Instalac'    THEN 'Instalações'
            WHEN 'Maq. Equip'  THEN 'Máquinas e Equipamentos'
            WHEN 'Mov. Utens'  THEN 'Móveis e Utensílios'
            WHEN 'Software'    THEN 'Softwares'
            ELSE r.Grupo_AtivoFixo
        END AS Descricao,
        CASE r.Grupo_AtivoFixo
            WHEN 'Benf. Imov'  THEN 1
            WHEN 'Biblioteca'  THEN 2
            WHEN 'Comp. Per'   THEN 3
            WHEN 'Const.Anda'  THEN 4
            WHEN 'Eq. Tecnol'  THEN 5
            WHEN 'Instalac'    THEN 6
            WHEN 'Maq. Equip'  THEN 7
            WHEN 'Mov. Utens'  THEN 8
            WHEN 'Software'    THEN 9
            ELSE 10
        END AS sort_order,
        r.val_25r,
        r.val_26r,
        COALESCE(o.val_26f, 0) AS val_26f
    FROM capex_realizado r
    LEFT JOIN capex_orcamento o ON o.Grupo_AtivoFixo = r.Grupo_AtivoFixo
)

SELECT Descricao, val_25r, `%_rol_25r`, val_26f, `%_rol_26f`, val_26r, `%_rol_26r`,
    var_num_26xfcst, `var_%_26xfcst`, var_num_26x25, `var_%_26x25`, var_pp_26xfcst
FROM (

-- Linhas individuais por categoria de ativo
SELECT
    1 AS sort_group,
    d.sort_order,
    d.Descricao,
    ROUND(d.val_25r, 0)                                                                 AS val_25r,
    ROUND(CASE WHEN r.rol_25r <> 0 THEN d.val_25r / r.rol_25r * 100 ELSE NULL END, 1)  AS `%_rol_25r`,
    ROUND(d.val_26f, 0)                                                                 AS val_26f,
    ROUND(CASE WHEN r.rol_26r <> 0 THEN d.val_26f / r.rol_26r * 100 ELSE NULL END, 1)  AS `%_rol_26f`,
    ROUND(d.val_26r, 0)                                                                 AS val_26r,
    ROUND(CASE WHEN r.rol_26r <> 0 THEN d.val_26r / r.rol_26r * 100 ELSE NULL END, 1)  AS `%_rol_26r`,
    ROUND(d.val_26r - d.val_26f, 0)                                                     AS var_num_26xfcst,
    ROUND(CASE WHEN d.val_26f <> 0 THEN (d.val_26r - d.val_26f) / ABS(d.val_26f) * 100 ELSE NULL END, 1) AS `var_%_26xfcst`,
    ROUND(d.val_26r - d.val_25r, 0)                                                     AS var_num_26x25,
    ROUND(CASE WHEN d.val_25r <> 0 THEN (d.val_26r - d.val_25r) / ABS(d.val_25r) * 100 ELSE NULL END, 1) AS `var_%_26x25`,
    ROUND(CASE WHEN r.rol_26r <> 0 THEN (d.val_26r - d.val_26f) / r.rol_26r * 100 ELSE NULL END, 1)      AS var_pp_26xfcst
FROM capex_display d
CROSS JOIN rol_premium r

UNION ALL

-- Total CAPEX (inclui ajustes no total)
SELECT
    2, 1, 'Total CAPEX',
    ROUND(SUM(d.val_25r) + a.ajuste_25r, 0),
    ROUND(CASE WHEN r.rol_25r <> 0 THEN (SUM(d.val_25r) + a.ajuste_25r) / r.rol_25r * 100 ELSE NULL END, 1),
    ROUND(SUM(d.val_26f), 0),
    ROUND(CASE WHEN r.rol_26r <> 0 THEN SUM(d.val_26f) / r.rol_26r * 100 ELSE NULL END, 1),
    ROUND(SUM(d.val_26r) + a.ajuste_26r, 0),
    ROUND(CASE WHEN r.rol_26r <> 0 THEN (SUM(d.val_26r) + a.ajuste_26r) / r.rol_26r * 100 ELSE NULL END, 1),
    ROUND((SUM(d.val_26r) + a.ajuste_26r) - SUM(d.val_26f), 0),
    ROUND(CASE WHEN SUM(d.val_26f) <> 0
        THEN ((SUM(d.val_26r) + a.ajuste_26r) - SUM(d.val_26f)) / ABS(SUM(d.val_26f)) * 100
        ELSE NULL END, 1),
    ROUND((SUM(d.val_26r) + a.ajuste_26r) - (SUM(d.val_25r) + a.ajuste_25r), 0),
    ROUND(CASE WHEN (SUM(d.val_25r) + a.ajuste_25r) <> 0
        THEN ((SUM(d.val_26r) + a.ajuste_26r) - (SUM(d.val_25r) + a.ajuste_25r)) / ABS(SUM(d.val_25r) + a.ajuste_25r) * 100
        ELSE NULL END, 1),
    ROUND(CASE WHEN r.rol_26r <> 0 THEN ((SUM(d.val_26r) + a.ajuste_26r) - SUM(d.val_26f)) / r.rol_26r * 100 ELSE NULL END, 1)
FROM capex_display d
CROSS JOIN rol_premium r
CROSS JOIN capex_ajustes a
GROUP BY r.rol_25r, r.rol_26r, a.ajuste_25r, a.ajuste_26r

) sub
ORDER BY sort_group, sort_order
