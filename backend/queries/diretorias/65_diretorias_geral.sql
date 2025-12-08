-- @id: diretorias_geral
-- @name: Corporativo + Estratégico (YTD Outubro)
-- @description: Análise de despesas das diretorias corporativas (Gente e Gestão, Financeira, Digital, Serviços)
-- @category: diretorias
-- @order: 65
-- @tags: diretorias, corporativo, despesas, 2025

WITH dim_diretorias AS (
    SELECT idCentroCustos, Diretoria
    FROM financeiro.prd.d_centrocustosxlsx
    WHERE Diretoria IN (
        'Diretoria de Gente e Gestão',
        'Diretoria Financeira',
        'Diretoria de Digital',
        'Diretoria de Serviços'
    )
),
 
fatos_brutos AS (
    SELECT
        f.Origem,
        f.Valor,
        f.Vertical,
        f.skclasspnl,
        substring(f.skclasspnl, 13, 8) AS join_key_cc
    FROM financeiro.prd.mv_f_apresentacao f
    WHERE YEAR(f.Data_Transacao) = 2025
      AND MONTH(f.Data_Transacao) BETWEEN 1 AND 10
      AND f.Origem IN ('Forecast', 'Resultado', 'Ajustes')
),
 
dados_consolidados AS (
    SELECT
        cc.Diretoria,
        f.Origem,
        f.Valor,
        CASE
            WHEN f.Vertical = 'SSS'
             AND l.Ebitda = 'Sim'
             AND l.Recorrente = 'Sim'
             AND d.Nome NOT IN ('Rateio SSS', 'Rateio Cross')
            THEN 1 ELSE 0
        END AS is_valid_realizado
    FROM fatos_brutos f
    INNER JOIN dim_diretorias cc
        ON f.join_key_cc = cc.idCentroCustos
    LEFT JOIN financeiro.prd.link_PnL l ON l.skclasspnl = f.skclasspnl
    LEFT JOIN financeiro.prd.d_classpnl d ON d.skPnL = l.skPnL
),
 
agregacao_por_diretoria AS (
    SELECT
        Diretoria,
        ROUND(-(SUM(CASE WHEN Origem = 'Forecast' THEN Valor ELSE 0 END) / 1000), 0) AS valor_10m25_f,
        ROUND(-(SUM(CASE
            WHEN Origem IN ('Resultado', 'Ajustes') AND is_valid_realizado = 1
            THEN Valor
            ELSE 0
        END) / 1000), 0) AS valor_10m25_r
    FROM dados_consolidados
    GROUP BY Diretoria
)
 
SELECT
    Diretoria,
    valor_10m25_f AS `10M'25 F`,
    valor_10m25_r AS `10M'25 R`
FROM agregacao_por_diretoria
 
UNION ALL
 
SELECT
    'Diretorias Corporativas' AS Diretoria,
    SUM(valor_10m25_f) AS `10M'25 F`,
    SUM(valor_10m25_r) AS `10M'25 R`
FROM agregacao_por_diretoria
 
ORDER BY
    CASE
        WHEN Diretoria = 'Diretoria de Gente e Gestão' THEN 1
        WHEN Diretoria = 'Diretoria Financeira' THEN 2
        WHEN Diretoria = 'Diretoria de Digital' THEN 3
        WHEN Diretoria = 'Diretoria de Serviços' THEN 4
        WHEN Diretoria = 'Diretorias Corporativas' THEN 5
        ELSE 6
    END
