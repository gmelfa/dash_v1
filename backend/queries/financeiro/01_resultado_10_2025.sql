-- @id: resultado_10_2025_final_maple_cefic_fix_v2
-- @name: Resumo - Grupo SEB (YTD Outubro)
-- @category: financeiro
-- @order: 1

WITH 
-- ==========================================================
-- 1. FONTE DE DADOS
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
        LOWER(Ebitda) AS is_ebitda,
        LOWER(Recorrente) AS is_recorrente,
        Valor
    FROM financeiro.prd.mv_f_apresentacao
    WHERE 
        ((YEAR(Data_Transacao) = YEAR(CURRENT_DATE) - 1) OR (YEAR(Data_Transacao) = 2025))
        AND MONTH(Data_Transacao) BETWEEN 1 AND 10
        AND Vertical NOT LIKE '%Escolas Próprias%'
        AND Grupo NOT LIKE '%Escolas Próprias%'
        AND Vertical NOT IN ('CDB', 'CSM', 'DEL', 'ESM', 'HEB', 'INT', 'PSM', 'SAR')
),

-- ==========================================================
-- 2. IDENTIFICAÇÃO DO CSC
-- ==========================================================
csc_flagged AS (
    SELECT 
        *,
        CASE 
            WHEN Nome_Unidade = 'Sede Administrativa' AND Nome_PnL NOT IN ('Rateio Corporativo', 'Corporativo BU') THEN 1
            WHEN Nome_Unidade NOT IN ('SEB Matriz', 'Sede Administrativa') AND Nome_PnL IN ('Corporativo BU', 'Rateio Corporativo') THEN 1
            WHEN Grupo = 'Conexia' AND Nome_PnL = 'Aluguel / IPTU' AND Nome_Unidade <> 'Sede Administrativa' THEN 1
            ELSE 0
        END AS is_csc
    FROM source_data
),

-- ==========================================================
-- 3. CLASSIFICAÇÃO UNIFICADA
-- ==========================================================
dados_classificados AS (
    SELECT 
        *,
        CASE 
            -- [BLINDAGEM 1] PREMIUM & VANGUARDA
            WHEN Vertical = 'Premium' THEN 'Premium'
            WHEN Vertical = 'Vanguarda' THEN 'Vanguarda'

            -- [BLINDAGEM 2] SPHERE
            WHEN Nome_Unidade LIKE '%Sphere International School%' THEN 'Sphere School'
            WHEN Grupo LIKE '%Sphere%' OR Nome_Unidade LIKE '%Sphere%' OR Vertical = 'Sphere Franquias' THEN 'Sphere Franquias'

            -- [BLINDAGEM 3] FRANQUIAS
            WHEN Nome_Unidade = 'Maple Bear Brasil' THEN 'Maple Bear Brasil'
            WHEN Nome_Unidade = 'Maple Publicidade' THEN 'Maple Publicidade'
            WHEN Vertical IN ('Franquias', 'Maple LATAM', 'Maple US', 'MBGS') OR Nome_Unidade IN ('Maple Bear Brasil', 'Maple Publicidade') THEN 
                 CASE 
                    WHEN Vertical = 'Maple LATAM' THEN 'Maple LATAM'
                    WHEN Vertical = 'Maple US' THEN 'Maple US'
                    WHEN Vertical = 'MBGS' THEN 'MBGS'
                    ELSE 'Outras Franquias'
                 END

            -- [BLINDAGEM 4] NOVOS NEGÓCIOS
            WHEN Nome_Unidade IN ('Publiseb', 'CEFIC') THEN Nome_Unidade

            -- [CSC]
            WHEN is_csc = 1 THEN 'CSC + Cros'

            -- [RESTO]
            WHEN Nome_Unidade = 'SEB Matriz' THEN 'Estrategico + Presidencia'
            ELSE Vertical 
        END AS Vertical_Calc
    FROM csc_flagged
),

-- ==========================================================
-- 4. CÁLCULO FINANCEIRO E ALUNOS
-- ==========================================================
financials AS (
    SELECT 
        Vertical_Calc AS Vertical,
        
        -- ROL 2024
        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE 
                WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade <> 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade = 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor
                WHEN Vertical_Calc = 'CEFIC' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 
                WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                ELSE 0 
            END
        ELSE 0 END), 0) AS ROL_2024,

        -- RESULTADO 2024
        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 THEN 
            CASE 
                -- 1. REGRA ESPECIAL: Maple Bear Brasil
                WHEN Vertical_Calc = 'Maple Bear Brasil' THEN
                    CASE 
                        WHEN Origem IN ('Resultado', 'Ajustes') 
                             AND is_ebitda='sim' 
                             AND is_recorrente='sim' 
                             AND Nome_PnL <> 'Intercompany MBC-CAD'
                        THEN Valor * -1 
                        ELSE 0 
                    END

                -- 2. REGRA ESPECIAL: Maple LATAM
                WHEN Vertical_Calc = 'Maple LATAM' THEN
                    CASE 
                        WHEN Origem IN ('Resultado', 'Ajustes') 
                             AND is_ebitda='sim' 
                             AND is_recorrente='sim' 
                             AND Nome_PnL NOT LIKE 'Intercompany%'
                        THEN Valor * -1 
                        ELSE 0 
                    END

                -- 3. REGRA GERAL
                WHEN Origem IN ('Resultado', 'Ajustes') THEN
                    CASE
                        WHEN Vertical IN ('Premium', 'Vanguarda', 'Sphere School', 'Sphere Franquias', 'Maple Publicidade', 'Maple US', 'MBGS') 
                             AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        
                        WHEN Vertical_Calc = 'Sphere School' THEN 0 
                        WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade <> 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade = 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor
                        WHEN Vertical_Calc = 'CEFIC' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 
                        WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        ELSE 0 
                    END
                ELSE 0 
            END
        ELSE 0 END), 0) AS Res_2024,
        
        -- FORECAST 2025
        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    WHEN Vertical_Calc = 'Publiseb' AND Origem = 'Budget' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc <> 'Publiseb' AND Origem = 'Forecast' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc = 'CSC + Cros' AND Origem = 'Forecast' THEN 
                        CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                    ELSE 0 
                END
            ELSE 0 
        END), 0) AS ROL_F,
        
        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    WHEN Vertical_Calc = 'Publiseb' AND Origem = 'Budget' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc <> 'Publiseb' AND Origem = 'Forecast' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc = 'CSC + Cros' AND Origem = 'Forecast' THEN 
                        CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                    ELSE 0 
                END
            ELSE 0 
        END), 0) AS Forecast_F,
        
        -- REALIZADO 2025
        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN Vertical_Calc='CSC + Cros' AND Nome_Unidade='Sede Administrativa' THEN (CASE WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor ELSE 0 END) ELSE (CASE WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE 0 END) END
        ELSE 0 END), 0) AS ROL_R,

        ROUND(SUM(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE WHEN Vertical_Calc='CSC + Cros' AND Nome_Unidade='Sede Administrativa' THEN (CASE WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor ELSE 0 END) ELSE (CASE WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE 0 END) END
        ELSE 0 END), 0) AS Res_R

    FROM dados_classificados
    GROUP BY Vertical_Calc
),

students_monthly AS (
    SELECT 
        Vertical_Calc AS Vertical, Ano, Mes, Origem, SUM(Valor) AS qtd_alunos
    FROM dados_classificados
    WHERE skclasspnl = '400000000' AND Mes BETWEEN 3 AND 10
    GROUP BY Vertical_Calc, Ano, Mes, Origem
),

students_avg AS (
    SELECT
        Vertical,
        AVG(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem = 'Alunos' THEN qtd_alunos END) AS Alunos_2024,
        AVG(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN qtd_alunos END) AS Alunos_F,
        AVG(CASE WHEN Ano = 2025 AND Origem = 'Alunos' THEN qtd_alunos END) AS Alunos_R
    FROM students_monthly
    GROUP BY Vertical
),

base_data AS (
    SELECT 
        COALESCE(f.Vertical, s.Vertical) AS Vertical,
        s.Alunos_2024, f.ROL_2024, f.Res_2024 AS Resultado_2024,
        s.Alunos_F, f.ROL_F, f.Forecast_F,
        s.Alunos_R, f.ROL_R, f.Res_R AS Resultado_R
    FROM financials f
    FULL OUTER JOIN students_avg s ON f.Vertical = s.Vertical
)

-- ==========================================================
-- 5. APRESENTAÇÃO
-- ==========================================================

-- [1] PREMIUM
SELECT 
    'Premium' AS Vertical,
    -- DIVISÃO POR 1000 APLICADA
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)) AS `Alunos (10M24 R)`, 
    ROUND(SUM(ROL_2024)/1000, 0) AS `ROL (10M24 R)`,
    ROUND(SUM(Resultado_2024)/1000, 0) AS `Resultado (10M24 R)`,
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END AS `%Ebtida (10M24 R)`,
    
    -- DIVISÃO POR 1000 APLICADA
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)) AS `Alunos (10M25 F)`,
    ROUND(SUM(ROL_F)/1000, 0) AS `ROL (10M25 F)`,
    ROUND(SUM(Forecast_F)/1000, 0) AS `Forecast (10M25 F)`,
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END AS `%Ebtida (10M25 F)`,
    
    -- DIVISÃO POR 1000 APLICADA
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)) AS `Alunos (10M25 R)`,
    ROUND(SUM(ROL_R)/1000, 0) AS `ROL (10M25 R)`,
    ROUND(SUM(Resultado_R)/1000, 0) AS `Resultado (10M25 R)`,
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END AS `%Ebtida (10M25 R)`,
    
    -- DIVISÃO POR 1000 APLICADA
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)) AS `Var|Alunos`,
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END AS `Var Pct|Alunos`,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0) AS `Var|ROL`,
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END AS `Var Pct|ROL`,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0) AS `Var|EBITDA`,
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END AS `Var Pct|EBITDA`,
    
    1.0 AS sort_order
FROM base_data 
WHERE Vertical = 'Premium'
GROUP BY 1

UNION ALL

-- [VANGUARDA]
SELECT 
    'Vanguarda',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END,
    1.0
FROM base_data 
WHERE Vertical = 'Vanguarda'
GROUP BY 1

UNION ALL

-- [SUBTOTAL ESCOLAS]
SELECT 
    'Operações Premium - Escolas',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END,
    2.0
FROM base_data 
WHERE Vertical IN ('Premium', 'Sphere School', 'Vanguarda')
GROUP BY 1

UNION ALL

-- [FRANQUIAS INDIVIDUAIS]
SELECT 
    Vertical,
    CAST(Alunos_2024 / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_2024/1000, 0), 
    ROUND(Resultado_2024/1000, 0),
    CASE WHEN ROL_2024 = 0 OR ROL_2024 IS NULL THEN NULL ELSE NULLIF(ROUND(Resultado_2024 / ROL_2024 * 100, 0), 0) END,
    
    CAST(Alunos_F / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_F/1000, 0), 
    ROUND(Forecast_F/1000, 0),
    CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE NULLIF(ROUND(Forecast_F / ROL_F * 100, 0), 0) END,
    
    CAST(Alunos_R / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_R/1000, 0), 
    ROUND(Resultado_R/1000, 0),
    CASE WHEN ROL_R = 0 OR ROL_R IS NULL THEN NULL ELSE NULLIF(ROUND(Resultado_R / ROL_R * 100, 0), 0) END,
    
    CAST((Alunos_R - Alunos_F) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN Alunos_F = 0 OR Alunos_F IS NULL THEN NULL ELSE CAST(((Alunos_R - Alunos_F) / ABS(Alunos_F)) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((ROL_R - ROL_F)/1000, 0),
    CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE ROUND(((ROL_R - ROL_F) / ABS(ROL_F)) * 100, 1) END,
    
    ROUND((Resultado_R - Forecast_F)/1000, 0),
    CASE WHEN Forecast_F = 0 OR Forecast_F IS NULL THEN NULL ELSE ROUND(((Resultado_R - Forecast_F) / ABS(Forecast_F)) * 100, 1) END,
    CASE Vertical
        WHEN 'Maple Bear Brasil' THEN 3.1
        WHEN 'Maple Publicidade' THEN 3.2
        WHEN 'Sphere Franquias' THEN 3.3
        WHEN 'Maple LATAM' THEN 3.4
        WHEN 'Maple US' THEN 3.5
        WHEN 'MBGS' THEN 3.6
        ELSE 3.9
    END AS sort_order
FROM base_data 
WHERE Vertical IN ('MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade')

UNION ALL

-- [SUBTOTAL FRANQUIAS]
SELECT 
    'Operações Premium - Franquias',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END,
    4.0
FROM base_data 
WHERE Vertical IN ('MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade')
GROUP BY 1

UNION ALL

-- [TOTAL OP. PREMIUM]
SELECT 
    'Operações Premium',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END,
    5.0
FROM base_data 
WHERE Vertical IN ('Premium', 'Sphere School', 'Vanguarda', 'MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade')
GROUP BY 1

UNION ALL

-- [ESTRATÉGICO INDIVIDUAL]
SELECT 
    Vertical,
    CAST(Alunos_2024 / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_2024/1000, 0), 
    ROUND(Resultado_2024/1000, 0),
    NULL,
    
    CAST(Alunos_F / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_F/1000, 0), 
    ROUND(Forecast_F/1000, 0),
    NULL,
    
    CAST(Alunos_R / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_R/1000, 0), 
    ROUND(Resultado_R/1000, 0),
    NULL,
    
    CAST((Alunos_R - Alunos_F) / 1000.0 AS DECIMAL(15,3)),
    NULL,
    
    ROUND((ROL_R - ROL_F)/1000, 0),
    NULL,
    
    ROUND((Resultado_R - Forecast_F)/1000, 0),
    NULL,
    CASE Vertical
        WHEN 'Estrategico + Presidencia' THEN 5.1
        WHEN 'CSC + Cros' THEN 5.2
        WHEN 'Holding' THEN 5.3
        ELSE 5.9
    END
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding')

UNION ALL

-- [SUBTOTAL ESTRATÉGICO]
SELECT 
    'Estratégico + Presidência + Corporativo',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    NULL,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    NULL,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    NULL,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    NULL,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    NULL,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    NULL,
    5.4
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding')
GROUP BY 1

UNION ALL

-- [NOVOS NEGÓCIOS]
SELECT 
    Vertical,
    CAST(Alunos_2024 / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_2024/1000, 0), 
    ROUND(Resultado_2024/1000, 0),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_2024 = 0 OR ROL_2024 IS NULL THEN NULL ELSE NULLIF(ROUND(Resultado_2024 / ROL_2024 * 100, 0), 0) END END,
    
    CAST(Alunos_F / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_F/1000, 0), 
    ROUND(Forecast_F/1000, 0),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE NULLIF(ROUND(Forecast_F / ROL_F * 100, 0), 0) END END,
    
    CAST(Alunos_R / 1000.0 AS DECIMAL(15,3)), 
    ROUND(ROL_R/1000, 0), 
    ROUND(Resultado_R/1000, 0),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_R = 0 OR ROL_R IS NULL THEN NULL ELSE NULLIF(ROUND(Resultado_R / ROL_R * 100, 0), 0) END END,
    
    CAST((Alunos_R - Alunos_F) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN Alunos_F = 0 OR Alunos_F IS NULL THEN NULL ELSE CAST(((Alunos_R - Alunos_F) / ABS(Alunos_F)) * 100 AS DECIMAL(15,1)) END END,
    
    ROUND((ROL_R - ROL_F)/1000, 0),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE ROUND(((ROL_R - ROL_F) / ABS(ROL_F)) * 100, 1) END END,
    
    ROUND((Resultado_R - Forecast_F)/1000, 0),
    CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN Forecast_F = 0 OR Forecast_F IS NULL THEN NULL ELSE ROUND(((Resultado_R - Forecast_F) / ABS(Forecast_F)) * 100, 1) END END,
    
    CASE Vertical
        WHEN 'Publiseb' THEN 6.1
        WHEN 'CEFIC' THEN 6.2
        ELSE 6.9
    END AS sort_order
FROM base_data 
WHERE Vertical IN ('Publiseb', 'CEFIC')

UNION ALL

-- [TOTAL ESTRATÉGICO]
SELECT 
    'Total Estratégico',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    NULL,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    NULL,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    NULL,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    NULL,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    NULL,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    NULL,
    7.0
FROM base_data 
WHERE Vertical IN ('Publiseb', 'CEFIC', 'Estrategico + Presidencia', 'CSC + Cros', 'Holding')
GROUP BY 1

UNION ALL

-- [TOTAL GERAL]
SELECT 
    'Total Op. Premium',
    CAST(SUM(Alunos_2024) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_2024)/1000, 0), 
    ROUND(SUM(Resultado_2024)/1000, 0),
    CASE WHEN SUM(ROL_2024) = 0 OR SUM(ROL_2024) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_2024) / SUM(ROL_2024) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_F) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F)/1000, 0), 
    ROUND(SUM(Forecast_F)/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Forecast_F) / SUM(ROL_F) * 100, 0), 0) END,
    
    CAST(SUM(Alunos_R) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_R)/1000, 0), 
    ROUND(SUM(Resultado_R)/1000, 0),
    CASE WHEN SUM(ROL_R) = 0 OR SUM(ROL_R) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Resultado_R) / SUM(ROL_R) * 100, 0), 0) END,
    
    CAST((SUM(Alunos_R) - SUM(Alunos_F)) / 1000.0 AS DECIMAL(15,3)),
    CASE WHEN SUM(Alunos_F) = 0 OR SUM(Alunos_F) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_R) - SUM(Alunos_F)) / ABS(SUM(Alunos_F))) * 100 AS DECIMAL(15,1)) END,
    
    ROUND((SUM(ROL_R) - SUM(ROL_F))/1000, 0),
    CASE WHEN SUM(ROL_F) = 0 OR SUM(ROL_F) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_R) - SUM(ROL_F)) / ABS(SUM(ROL_F))) * 100, 1) END,
    
    ROUND((SUM(Resultado_R) - SUM(Forecast_F))/1000, 0),
    CASE WHEN SUM(Forecast_F) = 0 OR SUM(Forecast_F) IS NULL THEN NULL ELSE ROUND(((SUM(Resultado_R) - SUM(Forecast_F)) / ABS(SUM(Forecast_F))) * 100, 1) END,
    8.0
FROM base_data 
WHERE Vertical IN (
    'Premium', 'Sphere School', 'Vanguarda', 
    'MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade',
    'Publiseb', 'CEFIC', 'Estrategico + Presidencia', 'CSC + Cros', 'Holding'
)
GROUP BY 1

ORDER BY sort_order, Vertical