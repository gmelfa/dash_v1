-- @id: premium_ebtida_por_unidade_ytd
-- @name: Premium - EBTIDA por Unidade YTD
-- @category: Premium
-- @order: 07

WITH params AS (
    SELECT
        :ano_selecionado     AS ano_atual,
        :ano_anterior        AS ano_anterior,
        :mes_selecionado     AS mes_ytd,
        'Premium'            AS vertical
),

base_dados AS (
    SELECT
        f.Nome_Unidade,
        f.Grupo,
        f.Origem,
        YEAR(f.Data_Transacao)  AS ano,
        MONTH(f.Data_Transacao) AS mes,
        f.skclasspnl,
        f.Ebitda,
        f.Recorrente,
        f.ROL   AS rol_flag,
        f.Valor,
        p.mes_ytd,
        p.ano_atual,
        p.ano_anterior,
        CASE
            WHEN f.Nome_Unidade = 'Pueri Domus Verbo'                      THEN 1
            WHEN f.Nome_Unidade = 'Pueri Domus Aclimação'                  THEN 2
            WHEN f.Nome_Unidade = 'Pueri Domus Itaim'                      THEN 3
            WHEN f.Nome_Unidade = 'Pueri Domus Perdizes'                   THEN 4
            WHEN f.Nome_Unidade = 'Pueri Domus Perdizes II'                THEN 5
            WHEN f.Nome_Unidade = 'C. Patrício - Barra da Tijuca (ECRAN)' THEN 10
            WHEN f.Nome_Unidade = 'C. Patrício - Gente Miúda (ECRAN)'     THEN 11
            WHEN f.Nome_Unidade = 'C. Patrício - Golfe Olímpico (ECRAN)'  THEN 12
            WHEN f.Nome_Unidade = 'C. Patrício - Recreio'                  THEN 13
            WHEN f.Nome_Unidade = 'Sphere International School'            THEN 20
            WHEN f.Nome_Unidade = 'Pueri Domus Ipiranga'                   THEN 30
            ELSE 99
        END AS peso_unidade
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND YEAR(f.Data_Transacao)  IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) <= p.mes_ytd
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria Premium%'
),

metricas_agregadas AS (
    SELECT
        Nome_Unidade, Grupo, peso_unidade, mes_ytd,
        CASE WHEN Nome_Unidade = 'Pueri Domus Ipiranga' THEN 'Novos Negócios' ELSE 'Operações Mantidas' END AS tipo_operacao,
        -- alunos são média mensal: jan-mar = snapshot do mês, abr+ = média acumulada desde março
        CASE WHEN mes_ytd <= 3
             THEN SUM(CASE WHEN ano = ano_anterior AND mes = mes_ytd AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END)
             ELSE SUM(CASE WHEN ano = ano_anterior AND mes >= 3       AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) / (mes_ytd - 2)
        END AS alu_25r,
        CASE WHEN mes_ytd <= 3
             THEN SUM(CASE WHEN ano = ano_atual    AND mes = mes_ytd AND Origem = 'Budget'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END)
             ELSE SUM(CASE WHEN ano = ano_atual    AND mes >= 3       AND Origem = 'Budget'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) / (mes_ytd - 2)
        END AS alu_26b,
        CASE WHEN mes_ytd <= 3
             THEN SUM(CASE WHEN ano = ano_atual    AND mes = mes_ytd AND Origem = 'Forecast' AND skclasspnl = '400000000' THEN Valor ELSE 0 END)
             ELSE SUM(CASE WHEN ano = ano_atual    AND mes >= 3       AND Origem = 'Forecast' AND skclasspnl = '400000000' THEN Valor ELSE 0 END) / (mes_ytd - 2)
        END AS alu_26f,
        CASE WHEN mes_ytd <= 3
             THEN SUM(CASE WHEN ano = ano_atual    AND mes = mes_ytd AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END)
             ELSE SUM(CASE WHEN ano = ano_atual    AND mes >= 3       AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) / (mes_ytd - 2)
        END AS alu_26r,
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND rol_flag = 1 AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS rol_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Budget'                 AND rol_flag = 1 AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS rol_26b,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND rol_flag = 1 AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS rol_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND rol_flag = 1 AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS rol_26r,
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS ebt_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Budget'                 AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS ebt_26b,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS ebt_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda = 'Sim' AND Recorrente = 'Sim' THEN Valor * -1 ELSE 0 END) / 1000 AS ebt_26r
    FROM base_dados
    GROUP BY 1, 2, 3, 4, 5
),

uniao_final AS (
    SELECT Nome_Unidade AS Descricao, peso_unidade, 1 AS nivel, alu_25r, rol_25r, ebt_25r, alu_26b, rol_26b, ebt_26b, alu_26f, rol_26f, ebt_26f, alu_26r, rol_26r, ebt_26r
    FROM metricas_agregadas

    UNION ALL

    SELECT 'Pueri Domus Total', 8, 2, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas WHERE Grupo = 'Pueri Domus' AND tipo_operacao = 'Operações Mantidas'

    UNION ALL

    SELECT 'Carolina Patrício', 15, 2, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas WHERE Grupo = 'Carolina Patrício'

    UNION ALL

    SELECT 'Sphere International School', 21, 2, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas WHERE Grupo = 'Sphere'

    UNION ALL

    SELECT 'Premium - Op. Partidas', 25, 3, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas WHERE tipo_operacao = 'Operações Mantidas'

    UNION ALL

    SELECT 'Premium - Novos Negócios', 35, 3, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas WHERE tipo_operacao = 'Novos Negócios'

    UNION ALL

    SELECT 'Premium', 40, 4, SUM(alu_25r), SUM(rol_25r), SUM(ebt_25r), SUM(alu_26b), SUM(rol_26b), SUM(ebt_26b), SUM(alu_26f), SUM(rol_26f), SUM(ebt_26f), SUM(alu_26r), SUM(rol_26r), SUM(ebt_26r)
    FROM metricas_agregadas
)

SELECT
    Descricao,
    ROUND(alu_25r, 0) AS `25R_Alu`, ROUND(rol_25r, 0) AS `25R_ROL`, ROUND(ebt_25r, 0) AS `25R_EBT`,
    ROUND(CASE WHEN rol_25r <> 0 THEN ebt_25r / rol_25r * 100 ELSE 0 END, 1) AS `25R_%`,
    ROUND(alu_26b, 0) AS `26B_Alu`, ROUND(rol_26b, 0) AS `26B_ROL`, ROUND(ebt_26b, 0) AS `26B_EBT`,
    ROUND(CASE WHEN rol_26b <> 0 THEN ebt_26b / rol_26b * 100 ELSE 0 END, 1) AS `26B_%`,
    ROUND(alu_26f, 0) AS `26F_Alu`, ROUND(rol_26f, 0) AS `26F_ROL`, ROUND(ebt_26f, 0) AS `26F_EBT`,
    ROUND(CASE WHEN rol_26f <> 0 THEN ebt_26f / rol_26f * 100 ELSE 0 END, 1) AS `26F_%`,
    ROUND(alu_26r, 0) AS `26R_Alu`, ROUND(rol_26r, 0) AS `26R_ROL`, ROUND(ebt_26r, 0) AS `26R_EBT`,
    ROUND(CASE WHEN rol_26r <> 0 THEN ebt_26r / rol_26r * 100 ELSE 0 END, 1) AS `26R_%`,
    ROUND(alu_26r - alu_26f, 0)                                                                      AS `Var Alu`,
    ROUND(CASE WHEN alu_26f <> 0 THEN (alu_26r - alu_26f) / alu_26f * 100 ELSE NULL END, 1)         AS `Var % Alu`,
    ROUND(rol_26r - rol_26f, 0)                                                                      AS `Var ROL`,
    ROUND(CASE WHEN rol_26f <> 0 THEN (rol_26r - rol_26f) / rol_26f * 100 ELSE NULL END, 1)         AS `Var % ROL`,
    ROUND(ebt_26r - ebt_26f, 0)                                                                      AS `Var EBT`,
    ROUND(CASE WHEN ebt_26f <> 0 THEN (ebt_26r - ebt_26f) / ebt_26f * 100 ELSE NULL END, 1)         AS `Var % EBT`
FROM uniao_final
ORDER BY peso_unidade