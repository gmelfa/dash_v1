-- @id: relatorio_rateio_corporativo_final_v1
-- @name: Relatório Rateio Corporativo  -Alta Performance
-- @category: financeiro
-- @order: 66

WITH dados_base AS (
    SELECT 
        Vertical AS Vertical_Tratada,
        Origem,
        MONTH(Data_Transacao) AS Mes,
        Valor
    FROM financeiro.prd.mv_f_apresentacao
    WHERE 
        YEAR(Data_Transacao) = 2025
        AND (
            Nome_PnL = 'Rateio Corporativo'
            OR 
            (Vertical = 'Conexia' AND Nome_PnL = 'Aluguel / IPTU')
        )
        AND Ebitda = 'Sim'
        AND Recorrente = 'Sim'
        AND Vertical NOT IN ('SSS')
),

metricas_por_vertical AS (

    SELECT 
        Vertical_Tratada AS Vertical,
        
        SUM(CASE WHEN Origem = 'Forecast' AND Mes <= 10 THEN Valor ELSE 0 END) / 1000.0 AS F_10M,
        
        SUM(CASE WHEN Origem IN ('Resultado', 'Ajustes') AND Mes <= 10 THEN Valor ELSE 0 END) / 1000.0 AS R_10M,
        
        SUM(CASE WHEN Origem = 'Forecast' THEN Valor ELSE 0 END) / 1000.0 AS F_FY
        
    FROM dados_base
    GROUP BY Vertical_Tratada
),

subtotal_alta_performance AS (
    SELECT 
        'Alta Performance' AS Vertical,
        SUM(F_10M) AS F_10M,
        SUM(R_10M) AS R_10M,
        SUM(F_FY) AS F_FY
    FROM metricas_por_vertical
    WHERE Vertical IN ('Alta Performance 1', 'Alta Performance 2', 'Alta Performance 3')
),

total_geral AS (
    SELECT 
        'Total' AS Vertical,
        SUM(F_10M) AS F_10M,
        SUM(R_10M) AS R_10M,
        SUM(F_FY) AS F_FY
    FROM metricas_por_vertical
),

uniao_final AS (
    
    SELECT * FROM subtotal_alta_performance
    
    UNION ALL
    
    SELECT * FROM metricas_por_vertical 
    WHERE Vertical IN ('Alta Performance 1', 'Alta Performance 2', 'Alta Performance 3')
    
    UNION ALL
    
    SELECT * FROM metricas_por_vertical 
    WHERE Vertical NOT IN ('Alta Performance 1', 'Alta Performance 2', 'Alta Performance 3')
    
    UNION ALL
    
    SELECT * FROM total_geral
)

SELECT 
    Vertical,
    CAST(F_10M AS DECIMAL(15,0)) AS `10M'25|F`,
    CAST(R_10M AS DECIMAL(15,0)) AS `10M'25|R`,
    
    CAST((R_10M - F_10M) AS DECIMAL(15,0)) AS `Var|25 x Fcst`,
    
    CASE 
        WHEN F_10M = 0 THEN NULL 
        ELSE CAST(((R_10M - F_10M) / ABS(F_10M)) * 100 AS DECIMAL(15,1)) 
    END AS `Var Pct|25 x Fcst`,
    
    CAST(F_FY AS DECIMAL(15,0)) AS `FY'25|Forecast`

FROM uniao_final
ORDER BY 
    CASE Vertical
        WHEN 'Alta Performance' THEN 1
        WHEN 'Alta Performance 1' THEN 2
        WHEN 'Alta Performance 2' THEN 3
        WHEN 'Alta Performance 3' THEN 4
        WHEN 'Conexia' THEN 5
        WHEN 'Ensino Superior' THEN 6
        WHEN 'Franquias' THEN 7
        WHEN 'Descontinuada' THEN 8
        WHEN 'Maple Bear Escolas Próprias' THEN 9
        WHEN 'Premium' THEN 10
        WHEN 'Turquesa' THEN 11
        WHEN 'Vanguarda' THEN 12
        WHEN 'Total' THEN 99
        ELSE 50
    END