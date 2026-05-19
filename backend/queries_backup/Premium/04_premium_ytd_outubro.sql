-- backup

WITH 
-- ==========================================================
-- 1. FONTE DE DADOS (JANEIRO A OUTUBRO)
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
        AND MONTH(Data_Transacao) BETWEEN 1 AND 12
        AND Vertical = 'Premium'
        
        -- [FILTROS DE EXCLUSÃO]
        AND Nome_Unidade NOT LIKE '%CSC Local%'
        AND Nome_Unidade NOT LIKE '%Diretoria Premium%'
        AND Nome_Unidade NOT LIKE '%Ipiranga%'
),

-- ==========================================================
-- 2. CLASSIFICAÇÃO (APENAS GRUPO PARA SUBTOTAL)
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
-- 3. CÁLCULO FINANCEIRO (CORREÇÃO: 'Sim')
-- ==========================================================
financials AS (
    SELECT 
        Linha_Relatorio,
        Grupo_Escola,
        
        -- 2024 REALIZADO
        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS ROL_24,

        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS Res_24,

        -- 2025 FORECAST
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN 
            CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS ROL_F25,
        
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN 
            CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS Res_F25,

        -- 2025 REALIZADO
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN ROL=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS ROL_R25,

        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN Ebitda='Sim' AND Recorrente='Sim' THEN Valor * -1 ELSE 0 END
        ELSE 0 END), 0) AS Res_R25

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
        Origem,
        SUM(Valor) AS qtd_alunos
    FROM dados_classificados
    WHERE skclasspnl = '400000000' 
      AND Mes BETWEEN 3 AND 10 
    GROUP BY Linha_Relatorio, Grupo_Escola, Ano, Origem
),

students_avg AS (
    SELECT
        Linha_Relatorio,
        Grupo_Escola,
        SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem = 'Alunos' THEN qtd_alunos ELSE 0 END) / 8.0 AS Alunos_24,
        SUM(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN qtd_alunos ELSE 0 END) / 8.0 AS Alunos_F25,
        SUM(CASE WHEN Ano = 2025 AND Origem = 'Alunos' THEN qtd_alunos ELSE 0 END) / 8.0 AS Alunos_R25
    FROM students_monthly
    GROUP BY Linha_Relatorio, Grupo_Escola
),

base_data AS (
    SELECT 
        COALESCE(f.Linha_Relatorio, s.Linha_Relatorio) AS Linha_Relatorio,
        COALESCE(f.Grupo_Escola, s.Grupo_Escola) AS Grupo_Escola,
        s.Alunos_24, f.ROL_24, f.Res_24,
        s.Alunos_F25, f.ROL_F25, f.Res_F25,
        s.Alunos_R25, f.ROL_R25, f.Res_R25
    FROM financials f
    FULL OUTER JOIN students_avg s ON f.Linha_Relatorio = s.Linha_Relatorio
),

-- ==========================================================
-- 5. CONSOLIDAÇÃO (COM ORDENAÇÃO FORÇADA)
-- ==========================================================
final_report AS (
    -- [PUERI DOMUS - INDIVIDUAL]
    SELECT 
        Linha_Relatorio AS Vertical,
        CAST(Alunos_24 AS DECIMAL(15,0)) AS `Alunos|10M24 R`, 
        ROUND(ROL_24/1000, 0) AS `ROL|10M24 R`,
        ROUND(Res_24/1000, 0) AS `EBITDA|10M24 R`,
        CASE WHEN ROL_24 = 0 OR ROL_24 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_24 / ROL_24 * 100, 1), 0) END AS `% EBITDA|10M24 R`,

        CAST(Alunos_F25 AS DECIMAL(15,0)) AS `Alunos|10M25 F`, 
        ROUND(ROL_F25/1000, 0) AS `ROL|10M25 F`,
        ROUND(Res_F25/1000, 0) AS `EBITDA|10M25 F`,
        CASE WHEN ROL_F25 = 0 OR ROL_F25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_F25 / ROL_F25 * 100, 1), 0) END AS `% EBITDA|10M25 F`,

        CAST(Alunos_R25 AS DECIMAL(15,0)) AS `Alunos|10M25 R`, 
        ROUND(ROL_R25/1000, 0) AS `ROL|10M25 R`,
        ROUND(Res_R25/1000, 0) AS `EBITDA|10M25 R`,
        CASE WHEN ROL_R25 = 0 OR ROL_R25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_R25 / ROL_R25 * 100, 1), 0) END AS `% EBITDA|10M25 R`,

        CAST((COALESCE(Alunos_R25,0) - COALESCE(Alunos_F25,0)) AS DECIMAL(15,0)) AS `Var|Alunos`,
        CASE WHEN Alunos_F25 = 0 OR Alunos_F25 IS NULL THEN NULL ELSE CAST(((Alunos_R25 - Alunos_F25) / ABS(Alunos_F25)) * 100 AS DECIMAL(15,1)) END AS `Var %|Alunos`,

        ROUND((COALESCE(ROL_R25,0) - COALESCE(ROL_F25,0))/1000, 0) AS `Var|ROL`,
        CASE WHEN ROL_F25 = 0 OR ROL_F25 IS NULL THEN NULL ELSE ROUND(((ROL_R25 - ROL_F25) / ABS(ROL_F25)) * 100, 1) END AS `Var %|ROL`,

        ROUND((COALESCE(Res_R25,0) - COALESCE(Res_F25,0))/1000, 0) AS `Var|EBITDA`,
        CASE WHEN Res_F25 = 0 OR Res_F25 IS NULL THEN NULL ELSE ROUND(((Res_R25 - Res_F25) / ABS(Res_F25)) * 100, 1) END AS `Var %|EBITDA`,
        
        -- ORDENAÇÃO ESPECÍFICA (Verbo -> Aclimação -> Itaim...)
        CASE 
            WHEN Linha_Relatorio LIKE '%Verbo%' THEN 1.1
            WHEN Linha_Relatorio LIKE '%Aclimação%' THEN 1.2
            WHEN Linha_Relatorio LIKE '%Itaim%' THEN 1.3
            WHEN Linha_Relatorio LIKE '%Perdizes%' AND Linha_Relatorio NOT LIKE '%II%' THEN 1.4
            WHEN Linha_Relatorio LIKE '%Perdizes II%' THEN 1.5
            ELSE 1.9 
        END AS sort_order
    FROM base_data 
    WHERE Grupo_Escola = 'Pueri Domus'

    UNION ALL

    -- [SUBTOTAL PUERI DOMUS]
    SELECT 
        'Pueri Domus' AS Vertical,
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), 
        ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_R25) AS DECIMAL(15,0)), ROUND(SUM(ROL_R25)/1000, 0), ROUND(SUM(Res_R25)/1000, 0), CASE WHEN SUM(ROL_R25)=0 OR SUM(ROL_R25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_R25)/SUM(ROL_R25)*100, 1), 0) END,
        CAST((COALESCE(SUM(Alunos_R25),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R25) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_R25),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R25) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_R25),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_R25) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        1.99 -- Logo após as unidades individuais
    FROM base_data 
    WHERE Grupo_Escola = 'Pueri Domus'
    GROUP BY 1

    UNION ALL

    -- [CAROLINA PATRICIO - INDIVIDUAL]
    SELECT 
        Linha_Relatorio,
        CAST(Alunos_24 AS DECIMAL(15,0)), ROUND(ROL_24/1000, 0), ROUND(Res_24/1000, 0), CASE WHEN ROL_24=0 OR ROL_24 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_24/ROL_24*100, 1), 0) END,
        CAST(Alunos_F25 AS DECIMAL(15,0)), ROUND(ROL_F25/1000, 0), ROUND(Res_F25/1000, 0), CASE WHEN ROL_F25=0 OR ROL_F25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_F25/ROL_F25*100, 1), 0) END,
        CAST(Alunos_R25 AS DECIMAL(15,0)), ROUND(ROL_R25/1000, 0), ROUND(Res_R25/1000, 0), CASE WHEN ROL_R25=0 OR ROL_R25 IS NULL THEN NULL ELSE NULLIF(ROUND(Res_R25/ROL_R25*100, 1), 0) END,
        CAST((COALESCE(Alunos_R25,0) - COALESCE(Alunos_F25,0)) AS DECIMAL(15,0)),
        CASE WHEN Alunos_F25=0 OR Alunos_F25 IS NULL THEN NULL ELSE CAST(((Alunos_R25 - Alunos_F25)/ABS(Alunos_F25))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(ROL_R25,0) - COALESCE(ROL_F25,0))/1000, 0),
        CASE WHEN ROL_F25=0 OR ROL_F25 IS NULL THEN NULL ELSE ROUND(((ROL_R25 - ROL_F25)/ABS(ROL_F25))*100, 1) END,
        ROUND((COALESCE(Res_R25,0) - COALESCE(Res_F25,0))/1000, 0),
        CASE WHEN Res_F25=0 OR Res_F25 IS NULL THEN NULL ELSE ROUND(((Res_R25 - Res_F25)/ABS(Res_F25))*100, 1) END,
        
        -- ORDENAÇÃO ESPECÍFICA (Barra -> Gente Miúda -> Golfe)
        CASE 
            WHEN Linha_Relatorio LIKE '%Barra%' THEN 2.1
            WHEN Linha_Relatorio LIKE '%Gente Miúda%' THEN 2.2
            WHEN Linha_Relatorio LIKE '%Golfe%' THEN 2.3
            ELSE 2.9
        END
    FROM base_data 
    WHERE Grupo_Escola = 'Carolina Patrício'

    UNION ALL

    -- [SUBTOTAL CAROLINA PATRICIO]
    SELECT 
        'Carolina Patrício',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_R25) AS DECIMAL(15,0)), ROUND(SUM(ROL_R25)/1000, 0), ROUND(SUM(Res_R25)/1000, 0), CASE WHEN SUM(ROL_R25)=0 OR SUM(ROL_R25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_R25)/SUM(ROL_R25)*100, 1), 0) END,
        CAST((COALESCE(SUM(Alunos_R25),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R25) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_R25),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R25) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_R25),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_R25) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        2.99 -- Logo após as unidades individuais
    FROM base_data 
    WHERE Grupo_Escola = 'Carolina Patrício'
    GROUP BY 1

    UNION ALL

    -- [SPHERE]
    SELECT 
        'Sphere International School',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_R25) AS DECIMAL(15,0)), ROUND(SUM(ROL_R25)/1000, 0), ROUND(SUM(Res_R25)/1000, 0), CASE WHEN SUM(ROL_R25)=0 OR SUM(ROL_R25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_R25)/SUM(ROL_R25)*100, 1), 0) END,
        CAST((COALESCE(SUM(Alunos_R25),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R25) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_R25),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R25) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_R25),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_R25) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        3.0
    FROM base_data 
    WHERE Grupo_Escola = 'Sphere'
    GROUP BY 1

    UNION ALL

    -- [TOTAL PREMIUM]
    SELECT 
        'Premium',
        CAST(SUM(Alunos_24) AS DECIMAL(15,0)), ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
        CAST(SUM(Alunos_F25) AS DECIMAL(15,0)), ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
        CAST(SUM(Alunos_R25) AS DECIMAL(15,0)), ROUND(SUM(ROL_R25)/1000, 0), ROUND(SUM(Res_R25)/1000, 0), CASE WHEN SUM(ROL_R25)=0 OR SUM(ROL_R25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_R25)/SUM(ROL_R25)*100, 1), 0) END,
        CAST((COALESCE(SUM(Alunos_R25),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
        CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R25) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
        ROUND((COALESCE(SUM(ROL_R25),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
        CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R25) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
        ROUND((COALESCE(SUM(Res_R25),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
        CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_R25) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
        4.0
    FROM base_data
    GROUP BY 1
)

SELECT * FROM final_report ORDER BY sort_order, Vertical