-- @id: detalhe_premium_escolas_12m_vs_10plus2_v13
-- @name: Resumo - Premium (Rolling Forecast 10 + 2)
-- @category: financeiro
-- @order: 4

WITH 
-- ==========================================================
-- 1. FONTE DE DADOS (JANEIRO A DEZEMBRO - 12 MESES)
-- ==========================================================
source_data AS (
    SELECT 
        YEAR(Data_Transacao) AS Ano,
        MONTH(Data_Transacao) AS Mes,
        Origem,
        skclasspnl,
        Nome_PnL,
        Grupo,
        skUnidade,
        Nome_Unidade,
        Vertical,
        ROL,
        Ebitda,       
        Recorrente,   
        Valor
    FROM financeiro.prd.mv_f_apresentacao
    WHERE 
        ((YEAR(Data_Transacao) = YEAR(CURRENT_DATE) - 1) OR (YEAR(Data_Transacao) = 2025))
        AND MONTH(Data_Transacao) BETWEEN 1 AND 12 -- JANELA 12 MESES
        AND Vertical = 'Premium'
        
        -- [FILTROS DE EXCLUSÃO]
        AND Nome_Unidade NOT LIKE '%CSC Local%'
        AND Nome_Unidade NOT LIKE '%Diretoria Premium%'
        AND Nome_Unidade NOT LIKE '%Ipiranga%'
),

-- ==========================================================
-- 2. CLASSIFICAÇÃO
-- ==========================================================
dados_classificados AS (
    SELECT 
        *,
        Nome_Unidade AS Linha_Relatorio,
        CASE 
            WHEN Nome_Unidade LIKE '%Pueri Domus%' THEN 'Pueri Domus'
            WHEN Nome_Unidade LIKE '%C. Patrício%' OR Nome_Unidade LIKE '%Carolina Patricio%' OR Grupo LIKE '%Ecran%' THEN 'Carolina Patrício'
            WHEN Nome_Unidade LIKE '%Sphere%' THEN 'Sphere'
            ELSE 'Outros'
        END AS Grupo_Escola
    FROM source_data
),

-- ==========================================================
-- 3. CÁLCULO FINANCEIRO (12M24, 12M25F, 10+2)
-- ==========================================================
financials AS (
    SELECT 
        Linha_Relatorio,
        Grupo_Escola,
        
        -- [12M24 R] - REALIZADO 2024 COMPLETO
        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS ROL_24,

        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS Res_24,

        -- [12M25 F] - FORECAST 2025 COMPLETO
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN 
            CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS ROL_F25,
        
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN 
            CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS Res_F25,

        -- [(10+2) 25 RF] - REALIZADO ATÉ OUT + FORECAST NOV/DEZ
        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    -- Meses 1-10: Realizado
                    WHEN Mes <= 10 AND Origem IN ('Resultado', 'Ajustes') THEN 
                        CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
                    -- Meses 11-12: Forecast
                    WHEN Mes > 10 AND Origem = 'Forecast' THEN 
                        CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
                    ELSE 0
                END
            ELSE 0 
        END), 0) AS ROL_RF,

        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    -- Meses 1-10: Realizado
                    WHEN Mes <= 10 AND Origem IN ('Resultado', 'Ajustes') THEN 
                        CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
                    -- Meses 11-12: Forecast
                    WHEN Mes > 10 AND Origem = 'Forecast' THEN 
                        CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
                    ELSE 0
                END
            ELSE 0 
        END), 0) AS Res_RF

    FROM dados_classificados
    GROUP BY Linha_Relatorio, Grupo_Escola
),

-- ==========================================================
-- 4. CÁLCULO ALUNOS
-- ==========================================================
students_monthly AS (
    SELECT 
        Linha_Relatorio,
        Grupo_Escola,
        Ano, 
        Mes,
        
        -- Alunos 24 e F25 (Dados brutos para média anual)
        SUM(CASE WHEN Origem = 'Alunos' THEN Valor ELSE 0 END) AS qtd_realized,
        SUM(CASE WHEN Origem = 'Forecast' THEN Valor ELSE 0 END) AS qtd_forecast,
        
        -- Alunos 10+2 (Apenas Março a Outubro - Regra validada)
        SUM(CASE 
            WHEN Ano = 2025 AND Mes <= 10 AND Origem = 'Alunos' THEN Valor 
            ELSE 0 
        END) AS qtd_ytd_oct
        
    FROM dados_classificados
    WHERE skclasspnl = '400000000' 
      AND Mes BETWEEN 1 AND 12 -- Precisa de 1-12 para os anuais
    GROUP BY Linha_Relatorio, Grupo_Escola, Ano, Mes
),

students_avg AS (
    SELECT
        Linha_Relatorio,
        Grupo_Escola,
        
        -- Média 24 (12M): Considera Mar-Dez / 10
        SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Mes >= 3 THEN qtd_realized ELSE 0 END) / 10.0 AS Alunos_24,
        
        -- Média F25 (12M): Considera Mar-Dez / 10
        SUM(CASE WHEN Ano = 2025 AND Mes >= 3 THEN qtd_forecast ELSE 0 END) / 10.0 AS Alunos_F25,
        
        -- Média 10+2 RF: Considera Mar-Out / 8 (Conforme validado anteriormente)
        SUM(CASE WHEN Ano = 2025 AND Mes >= 3 THEN qtd_ytd_oct ELSE 0 END) / 8.0 AS Alunos_RF
        
    FROM students_monthly
    GROUP BY Linha_Relatorio, Grupo_Escola
),

base_data AS (
    SELECT 
        COALESCE(f.Linha_Relatorio, s.Linha_Relatorio) AS Linha_Relatorio,
        COALESCE(f.Grupo_Escola, s.Grupo_Escola) AS Grupo_Escola,
        s.Alunos_24, f.ROL_24, f.Res_24,
        s.Alunos_F25, f.ROL_F25, f.Res_F25,
        s.Alunos_RF, f.ROL_RF, f.Res_RF
    FROM financials f
    FULL OUTER JOIN students_avg s ON f.Linha_Relatorio = s.Linha_Relatorio
),

-- ==========================================================
-- 5. CONSOLIDAÇÃO DO RELATÓRIO
-- ==========================================================
final_report AS (
    -- [PUERI DOMUS - INDIVIDUAL]
    SELECT 
        Linha_Relatorio AS Vertical,
        -- 12M24 R
        CAST(Alunos_24 AS DECIMAL(15,0)) AS `Alunos|12M24 R`, 
        ROUND(ROL_24/1000, 0) AS `ROL|12M24 R`,
        ROUND(Res_24/1000, 0) AS `EBITDA|12M24 R`,
        CASE WHEN ROL_24 = 0 OR ROL_24 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_24 / ROL_24 * 100, 1), 0) END AS `% EBITDA|12M24 R`,

        -- 12M25 F
        CAST(Alunos_F25 AS DECIMAL(15,0)) AS `Alunos|12M25 F`, 
        ROUND(ROL_F25/1000, 0) AS `ROL|12M25 F`,
        ROUND(Res_F25/1000, 0) AS `EBITDA|12M25 F`,
        CASE WHEN ROL_F25 = 0 OR ROL_F25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_F25 / ROL_F25 * 100, 1), 0) END AS `% EBITDA|12M25 F`,

        -- (10+2) 25 RF
        CAST(Alunos_RF AS DECIMAL(15,0)) AS `Alunos|(10+2) 25 RF`, 
        ROUND(ROL_RF/1000, 0) AS `ROL|(10+2) 25 RF`,
        ROUND(Res_RF/1000, 0) AS `EBITDA|(10+2) 25 RF`,
        CASE WHEN ROL_RF = 0 OR ROL_RF IS NULL THEN NULL ELSE NULLIF(ROUND(Res_RF / ROL_RF * 100, 1), 0) END AS `% EBITDA|(10+2) 25 RF`,

        -- VARIAÇÃO: (10+2) vs Forecast 12M
        CAST((COALESCE(Alunos_RF,0) - COALESCE(Alunos_F25,0)) AS DECIMAL(15,0)) AS `Var. 25 x Fcst|Alunos`,
        CASE WHEN Alunos_F25 = 0 OR Alunos_F25 IS NULL THEN NULL ELSE CAST(((Alunos_RF - Alunos_F25) / ABS(Alunos_F25)) * 100 AS DECIMAL(15,1)) END AS `Var % 25 x Fcst|Alunos`,

        ROUND((COALESCE(ROL_RF,0) - COALESCE(ROL_F25,0))/1000, 0) AS `Var. 25 x Fcst|ROL`,
        CASE WHEN ROL_F25 = 0 OR ROL_F25 IS NULL THEN NULL ELSE ROUND(((ROL_RF - ROL_F25) / ABS(ROL_F25)) * 100, 1) END AS `Var % 25 x Fcst|ROL`,

        ROUND((COALESCE(Res_RF,0) - COALESCE(Res_F25,0))/1000, 0) AS `Var. 25 x Fcst|EBITDA`,
        CASE WHEN Res_F25 = 0 OR Res_F25 IS NULL THEN NULL ELSE ROUND(((Res_RF - Res_F25) / ABS(Res_F25)) * 100, 1) END AS `Var % 25 x Fcst|EBITDA`,
        
        1.0 AS sort_order
    FROM base_data 
    WHERE Grupo_Escola = 'Pueri Domus'

    UNION ALL

    -- [SUBTOTAL PUERI DOMUS]
    SELECT 
        'Pueri Domus',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_RF) AS DECIMAL(15,0)), ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
        
        CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        2.0
    FROM base_data 
    WHERE Grupo_Escola = 'Pueri Domus'
    GROUP BY 1

    UNION ALL

    -- [CAROLINA PATRICIO - INDIVIDUAL]
    SELECT 
        Linha_Relatorio,
        CAST(Alunos_24 AS DECIMAL(15,0)), ROUND(ROL_24/1000, 0), ROUND(Res_24/1000, 0), CASE WHEN ROL_24=0 OR ROL_24 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_24/ROL_24*100, 1), 0) END,
        CAST(Alunos_F25 AS DECIMAL(15,0)), ROUND(ROL_F25/1000, 0), ROUND(Res_F25/1000, 0), CASE WHEN ROL_F25=0 OR ROL_F25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_F25/ROL_F25*100, 1), 0) END,
        CAST(Alunos_RF AS DECIMAL(15,0)), ROUND(ROL_RF/1000, 0), ROUND(Res_RF/1000, 0), CASE WHEN ROL_RF=0 OR ROL_RF IS NULL THEN NULL ELSE NULLIF(ROUND(Res_RF/ROL_RF*100, 1), 0) END,
        
        CAST((COALESCE(Alunos_RF,0) - COALESCE(Alunos_F25,0)) AS DECIMAL(15,0)),
        CASE WHEN Alunos_F25=0 OR Alunos_F25 IS NULL THEN NULL ELSE CAST(((Alunos_RF - Alunos_F25)/ABS(Alunos_F25))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(ROL_RF,0) - COALESCE(ROL_F25,0))/1000, 0),
        CASE WHEN ROL_F25=0 OR ROL_F25 IS NULL THEN NULL ELSE ROUND(((ROL_RF - ROL_F25)/ABS(ROL_F25))*100, 1) END,
        ROUND((COALESCE(Res_RF,0) - COALESCE(Res_F25,0))/1000, 0),
        CASE WHEN Res_F25=0 OR Res_F25 IS NULL THEN NULL ELSE ROUND(((Res_RF - Res_F25)/ABS(Res_F25))*100, 1) END,
        3.0
    FROM base_data 
    WHERE Grupo_Escola = 'Carolina Patrício'

    UNION ALL

    -- [SUBTOTAL CAROLINA PATRICIO]
    SELECT 
        'Carolina Patrício',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_RF) AS DECIMAL(15,0)), ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
        
        CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        4.0
    FROM base_data 
    WHERE Grupo_Escola = 'Carolina Patrício'
    GROUP BY 1

    UNION ALL

    -- [SPHERE]
    SELECT 
        'Sphere International School',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_RF) AS DECIMAL(15,0)), ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
        
        CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        5.0
    FROM base_data 
    WHERE Grupo_Escola = 'Sphere'
    GROUP BY 1

    UNION ALL

    -- [TOTAL PREMIUM]
    SELECT 
        'Premium',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_RF) AS DECIMAL(15,0)), ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
        
        CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        6.0
    FROM base_data
    GROUP BY 1
)

SELECT * FROM final_report 
ORDER BY 
    sort_order, 
    -- Ordenação secundária para garantir ordem das escolas dentro do grupo Pueri e Carolina
    CASE 
        WHEN Vertical LIKE '%Verbo%' THEN 1
        WHEN Vertical LIKE '%Aclimação%' THEN 2
        WHEN Vertical LIKE '%Itaim%' THEN 3
        WHEN Vertical LIKE '%Perdizes%' AND Vertical NOT LIKE '%II%' THEN 4
        WHEN Vertical LIKE '%Perdizes II%' THEN 5
        WHEN Vertical LIKE '%Barra%' THEN 1
        WHEN Vertical LIKE '%Gente%' THEN 2
        WHEN Vertical LIKE '%Golfe%' THEN 3
        ELSE 99 
    END