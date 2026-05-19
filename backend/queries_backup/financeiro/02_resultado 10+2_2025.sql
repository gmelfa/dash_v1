-- backup
WITH 
-- ==========================================================
-- 1. FONTE DE DADOS (JAN-DEZ)
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
        AND MONTH(Data_Transacao) BETWEEN 1 AND 12
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
            -- [1] VERTICAIS PADRÃO
            WHEN Vertical = 'Premium' THEN 'Premium'
            WHEN Vertical = 'Vanguarda' THEN 'Vanguarda'

            -- [2] UNIDADES ESPECÍFICAS
            WHEN Nome_Unidade LIKE '%Sphere International School%' THEN 'Sphere School'
            WHEN Grupo LIKE '%Sphere%' OR Nome_Unidade LIKE '%Sphere%' OR Vertical = 'Sphere Franquias' THEN 'Sphere Franquias'

            WHEN Nome_Unidade = 'Maple Bear Brasil' THEN 'Maple Bear Brasil'
            WHEN Nome_Unidade = 'Maple Publicidade' THEN 'Maple Publicidade'
            
            WHEN Vertical IN ('Franquias', 'Maple LATAM', 'Maple US', 'MBGS') OR Nome_Unidade IN ('Maple Bear Brasil', 'Maple Publicidade') THEN 
                 CASE 
                    WHEN Vertical = 'Maple LATAM' THEN 'Maple LATAM'
                    WHEN Vertical = 'Maple US' THEN 'Maple US'
                    WHEN Vertical = 'MBGS' THEN 'MBGS'
                    ELSE 'Outras Franquias'
                 END

            WHEN Nome_Unidade IN ('Publiseb', 'CEFIC') THEN Nome_Unidade
            WHEN is_csc = 1 THEN 'CSC + Cros'
            WHEN Nome_Unidade = 'SEB Matriz' THEN 'Estrategico + Presidencia'
            ELSE Vertical 
        END AS Vertical_Calc
    FROM csc_flagged
),

-- ==========================================================
-- 4. CÁLCULO FINANCEIRO
-- ==========================================================
financials AS (
    SELECT 
        Vertical_Calc AS Vertical,
        
        -- [12M24 R]
        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN 
            CASE 
                WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade <> 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade = 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor
                WHEN Vertical_Calc = 'CEFIC' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 
                WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                ELSE 0 
            END
        ELSE 0 END), 0) AS ROL_24,

        ROUND(SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 THEN 
            CASE 
                WHEN Vertical_Calc = 'Maple Bear Brasil' THEN
                    CASE WHEN Origem IN ('Resultado', 'Ajustes') AND is_ebitda='sim' AND is_recorrente='sim' AND Nome_PnL <> 'Intercompany MBC-CAD' THEN Valor * -1 ELSE 0 END
                WHEN Vertical_Calc = 'Maple LATAM' THEN
                    CASE WHEN Origem IN ('Resultado', 'Ajustes') AND is_ebitda='sim' AND is_recorrente='sim' AND Nome_PnL NOT LIKE 'Intercompany%' THEN Valor * -1 ELSE 0 END
                WHEN Origem IN ('Resultado', 'Ajustes') THEN
                    CASE
                        WHEN Vertical IN ('Premium', 'Vanguarda', 'Sphere School', 'Sphere Franquias', 'Maple Publicidade', 'Maple US', 'MBGS') AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        WHEN Vertical_Calc = 'Sphere School' THEN 0 
                        WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade <> 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        WHEN Vertical_Calc = 'CSC + Cros' AND Nome_Unidade = 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor
                        WHEN Vertical_Calc = 'CEFIC' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 
                        WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                        ELSE 0 
                    END
                ELSE 0 
            END
        ELSE 0 END), 0) AS Res_24,

        -- [12M25 F]
        ROUND(SUM(CASE 
            WHEN Ano = 2025 AND Origem = 'Forecast' THEN
                CASE 
                    WHEN Vertical_Calc = 'Publiseb' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc <> 'Publiseb' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc = 'CSC + Cros' THEN 
                        CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                    ELSE 0 
                END
            ELSE 0 
        END), 0) AS ROL_F25,
        
        ROUND(SUM(CASE 
            WHEN Ano = 2025 AND Origem = 'Forecast' THEN
                CASE 
                    WHEN Vertical_Calc = 'Publiseb' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc <> 'Publiseb' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                    WHEN Vertical_Calc = 'CSC + Cros' THEN 
                        CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                    ELSE 0 
                END
            ELSE 0 
        END), 0) AS Res_F25,

        -- [10+2 RF]
        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    WHEN Mes <= 10 AND Origem IN ('Resultado', 'Ajustes') THEN 
                        CASE 
                           WHEN Vertical_Calc='CSC + Cros' AND Nome_Unidade='Sede Administrativa' THEN (CASE WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor ELSE 0 END) ELSE (CASE WHEN ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE 0 END) 
                        END
                    WHEN Mes > 10 AND Origem = 'Forecast' THEN
                        CASE 
                            WHEN Vertical_Calc = 'Publiseb' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                            WHEN Vertical_Calc <> 'Publiseb' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                            WHEN Vertical_Calc = 'CSC + Cros' THEN 
                                CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND ROL=1 AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                            ELSE 0 
                        END
                    ELSE 0
                END
            ELSE 0 
        END), 0) AS ROL_RF,

        ROUND(SUM(CASE 
            WHEN Ano = 2025 THEN
                CASE 
                    WHEN Mes <= 10 AND Origem IN ('Resultado', 'Ajustes') THEN 
                        CASE 
                             WHEN Vertical_Calc = 'Maple Bear Brasil' AND is_ebitda='sim' AND is_recorrente='sim' AND Nome_PnL <> 'Intercompany MBC-CAD' THEN Valor * -1
                             WHEN Vertical_Calc = 'Maple LATAM' AND is_ebitda='sim' AND is_recorrente='sim' AND Nome_PnL NOT LIKE 'Intercompany%' THEN Valor * -1
                             WHEN Vertical IN ('Premium', 'Vanguarda', 'Sphere School', 'Sphere Franquias', 'Maple Publicidade', 'Maple US', 'MBGS') AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                             WHEN Vertical_Calc = 'Sphere School' THEN 0 
                             WHEN Vertical_Calc='CSC + Cros' AND Nome_Unidade='Sede Administrativa' THEN (CASE WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor ELSE 0 END) 
                             WHEN Vertical_Calc='CSC + Cros' AND Nome_Unidade<>'Sede Administrativa' THEN (CASE WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE 0 END)
                             WHEN Vertical_Calc='CEFIC' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                             WHEN is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 
                             ELSE 0 
                        END
                    WHEN Mes > 10 AND Origem = 'Forecast' THEN
                        CASE 
                            WHEN Vertical_Calc = 'Publiseb' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                            WHEN Vertical_Calc <> 'Publiseb' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1
                            WHEN Vertical_Calc = 'CSC + Cros' THEN 
                                CASE WHEN Nome_Unidade <> 'Sede Administrativa' AND is_ebitda='sim' AND is_recorrente='sim' THEN Valor * -1 ELSE Valor END
                            ELSE 0 
                        END
                    ELSE 0
                END
            ELSE 0 
        END), 0) AS Res_RF

    FROM dados_classificados
    GROUP BY Vertical_Calc
),

-- ==========================================================
-- 5. CÁLCULO ALUNOS (SOMA MISTA / 10)
-- ==========================================================
students_monthly AS (
    SELECT 
        Vertical_Calc AS Vertical, 
        Ano, 
        Mes, 
        -- Alunos 10+2: Considerar apenas YTD Outubro
        SUM(CASE 
            WHEN Ano = 2025 AND Mes <= 10 AND Origem = 'Alunos' THEN Valor 
            ELSE 0 
        END) AS qtd_ytd_oct,
        
        SUM(CASE WHEN Origem = 'Forecast' THEN Valor ELSE 0 END) AS qtd_forecast,
        SUM(CASE WHEN Origem = 'Alunos' THEN Valor ELSE 0 END) AS qtd_realized
    FROM dados_classificados
    WHERE skclasspnl = '400000000' AND Mes BETWEEN 3 AND 12
    GROUP BY Vertical_Calc, Ano, Mes
),

students_avg AS (
    SELECT
        Vertical,
        -- Média 2024: (Mar-Dez) / 10
        SUM(CASE WHEN Ano = YEAR(CURRENT_DATE) - 1 THEN qtd_realized ELSE 0 END) / 10.0 AS Alunos_24,
        
        -- Média Forecast 2025: (Mar-Dez) / 10
        SUM(CASE WHEN Ano = 2025 THEN qtd_forecast ELSE 0 END) / 10.0 AS Alunos_F25,
        
        -- Média RF 2025 (10+2): (Mar-Out) / 8
        SUM(CASE WHEN Ano = 2025 THEN qtd_ytd_oct ELSE 0 END) / 8.0 AS Alunos_RF
    FROM students_monthly -- CORREÇÃO: Lê da CTE anterior
    GROUP BY Vertical
),

base_data AS (
    SELECT 
        COALESCE(f.Vertical, s.Vertical) AS Vertical,
        s.Alunos_24, f.ROL_24, f.Res_24,
        s.Alunos_F25, f.ROL_F25, f.Res_F25,
        s.Alunos_RF, f.ROL_RF, f.Res_RF
    FROM financials f
    FULL OUTER JOIN students_avg s ON f.Vertical = s.Vertical
)

-- ==========================================================
-- 6. APRESENTAÇÃO
-- ==========================================================

-- [1] PREMIUM
SELECT 
    'Premium' AS Vertical,
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)) AS `Alunos|12M24 R`, 
    ROUND(SUM(ROL_24)/1000, 0) AS `ROL|12M24 R`,
    ROUND(SUM(Res_24)/1000, 0) AS `EBITDA|12M24 R`,
    CASE WHEN SUM(ROL_24) = 0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24) / SUM(ROL_24) * 100, 1), 0) END AS `% EBITDA|12M24 R`,

    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)) AS `Alunos|12M25 F`, 
    ROUND(SUM(ROL_F25)/1000, 0) AS `ROL|12M25 F`,
    ROUND(SUM(Res_F25)/1000, 0) AS `EBITDA|12M25 F`,
    CASE WHEN SUM(ROL_F25) = 0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25) / SUM(ROL_F25) * 100, 1), 0) END AS `% EBITDA|12M25 F`,

    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)) AS `Alunos|(10+2) RF`, 
    ROUND(SUM(ROL_RF)/1000, 0) AS `ROL|(10+2) RF`,
    ROUND(SUM(Res_RF)/1000, 0) AS `EBITDA|(10+2) RF`,
    CASE WHEN SUM(ROL_RF) = 0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF) / SUM(ROL_RF) * 100, 1), 0) END AS `% EBITDA|(10+2) RF`,

    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)) AS `Var 25 x Fcst|Alunos`,
    CASE WHEN SUM(Alunos_F25) = 0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25)) / ABS(SUM(Alunos_F25))) * 100 AS DECIMAL(15,1)) END AS `Var Pct 25 x Fcst|Alunos`,

    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0) AS `Var 25 x Fcst|ROL`,
    CASE WHEN SUM(ROL_F25) = 0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25)) / ABS(SUM(ROL_F25))) * 100, 1) END AS `Var Pct 25 x Fcst|ROL`,

    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0) AS `Var 25 x Fcst|EBITDA`,
    CASE WHEN SUM(Res_F25) = 0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25)) / ABS(SUM(Res_F25))) * 100, 1) END AS `Var Pct 25 x Fcst|EBITDA`,
    
    1.0 AS sort_order
FROM base_data 
WHERE Vertical = 'Premium'
GROUP BY 1

UNION ALL

-- [VANGUARDA]
SELECT 
    'Vanguarda',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    2.0
FROM base_data 
WHERE Vertical = 'Vanguarda'
GROUP BY 1

UNION ALL

-- [SUBTOTAL ESCOLAS]
SELECT 
    'Operações Premium - Escolas',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    3.0
FROM base_data 
WHERE Vertical IN ('Premium', 'Vanguarda', 'Sphere School')
GROUP BY 1

UNION ALL

-- [FRANQUIAS INDIVIDUAIS]
SELECT 
    CASE WHEN Vertical = 'Sphere Franquias' THEN 'Sphere' ELSE Vertical END,
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    CASE Vertical
        WHEN 'Maple Bear Brasil' THEN 4.1
        WHEN 'Maple Publicidade' THEN 4.2
        WHEN 'Sphere Franquias' THEN 4.3
        WHEN 'Maple LATAM' THEN 4.4
        WHEN 'Maple US' THEN 4.5
        WHEN 'MBGS' THEN 4.6
        ELSE 4.9
    END
FROM base_data 
WHERE Vertical IN ('Maple Bear Brasil', 'Maple Publicidade', 'Sphere Franquias', 'Maple LATAM', 'Maple US', 'MBGS')
GROUP BY Vertical

UNION ALL

-- [SUBTOTAL FRANQUIAS]
SELECT 
    'Operações Premium - Franquias',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    5.0
FROM base_data 
WHERE Vertical IN ('Maple Bear Brasil', 'Maple Publicidade', 'Sphere Franquias', 'Maple LATAM', 'Maple US', 'MBGS')
GROUP BY 1

UNION ALL

-- [TOTAL OPERAÇÕES PREMIUM]
SELECT 
    'Operações Premium',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    6.0
FROM base_data 
WHERE Vertical IN ('Premium', 'Vanguarda', 'Sphere School', 'Maple Bear Brasil', 'Maple Publicidade', 'Sphere Franquias', 'Maple LATAM', 'Maple US', 'MBGS')
GROUP BY 1

UNION ALL

-- [ESTRATEGICO + PRESIDENCIA + CORPORATIVO]
SELECT 
    'Estratégico + Presidência + Corporativo',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), NULL,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), NULL,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), NULL,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)), NULL,
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0), NULL,
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0), NULL,
    7.0
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding')
GROUP BY 1

UNION ALL

-- [NOVOS NEGOCIOS]
SELECT 
    Vertical,
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), NULL,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), NULL,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), NULL,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)), NULL,
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0), NULL,
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0), NULL,
    CASE Vertical WHEN 'Publiseb' THEN 8.1 WHEN 'CEFIC' THEN 8.2 END
FROM base_data 
WHERE Vertical IN ('Publiseb', 'CEFIC')
GROUP BY Vertical

UNION ALL

-- [TOTAL ESTRATÉGICO]
SELECT 
    'Total Estratégico',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), NULL,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), NULL,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), NULL,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)), NULL,
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0), NULL,
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0), NULL,
    9.0
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding', 'Publiseb', 'CEFIC')
GROUP BY 1

UNION ALL

-- [TOTAL OP. PREMIUM (GERAL)]
SELECT 
    'Total Op. Premium',
    CAST(SUM(Alunos_24) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_24)/1000, 0), ROUND(SUM(Res_24)/1000, 0), CASE WHEN SUM(ROL_24)=0 OR SUM(ROL_24) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_24)/SUM(ROL_24)*100, 1), 0) END,
    CAST(SUM(Alunos_F25) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_F25)/1000, 0), ROUND(SUM(Res_F25)/1000, 0), CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_F25)/SUM(ROL_F25)*100, 1), 0) END,
    CAST(SUM(Alunos_RF) / 1000.0 AS DECIMAL(15,3)), 
    ROUND(SUM(ROL_RF)/1000, 0), ROUND(SUM(Res_RF)/1000, 0), CASE WHEN SUM(ROL_RF)=0 OR SUM(ROL_RF) IS NULL THEN NULL ELSE NULLIF(ROUND(SUM(Res_RF)/SUM(ROL_RF)*100, 1), 0) END,
    
    CAST((COALESCE(SUM(Alunos_RF),0) - COALESCE(SUM(Alunos_F25),0)) AS DECIMAL(15,0)),
    CASE WHEN SUM(Alunos_F25)=0 OR SUM(Alunos_F25) IS NULL THEN NULL ELSE CAST(((SUM(Alunos_RF) - SUM(Alunos_F25))/ABS(SUM(Alunos_F25)))*100 AS DECIMAL(15,1)) END,
    
    ROUND((COALESCE(SUM(ROL_RF),0) - COALESCE(SUM(ROL_F25),0))/1000, 0),
    CASE WHEN SUM(ROL_F25)=0 OR SUM(ROL_F25) IS NULL THEN NULL ELSE ROUND(((SUM(ROL_RF) - SUM(ROL_F25))/ABS(SUM(ROL_F25)))*100, 1) END,
    
    ROUND((COALESCE(SUM(Res_RF),0) - COALESCE(SUM(Res_F25),0))/1000, 0),
    CASE WHEN SUM(Res_F25)=0 OR SUM(Res_F25) IS NULL THEN NULL ELSE ROUND(((SUM(Res_RF) - SUM(Res_F25))/ABS(SUM(Res_F25)))*100, 1) END,
    10.0
FROM base_data 
WHERE Vertical IN (
    'Premium', 'Vanguarda', 'Sphere School', 'Maple Bear Brasil', 'Maple Publicidade', 'Sphere Franquias', 'Maple LATAM', 'Maple US', 'MBGS',
    'Estrategico + Presidencia', 'CSC + Cros', 'Holding', 'Publiseb', 'CEFIC'
)
GROUP BY 1

ORDER BY sort_order, Vertical