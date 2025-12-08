-- @id: resultado_10_2025
-- @name: Resumo - Grupo SEB (YTD Outubro)
-- @description: Análise financeira consolidada com Premium, Franquias, Estratégico e CSC
-- @category: financeiro
-- @order: 1
-- @tags: financeiro, resultado, 2025, premium, franquias, estrategico

WITH
-- ==========================================================
-- 1. FONTE DE DADOS (FILTROS GERAIS)
-- ==========================================================
source_data AS (
  SELECT 
    year(Data_Transacao) AS Ano,
    month(Data_Transacao) AS Mes,
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
    ((year(Data_Transacao) = year(current_date) - 1) OR (year(Data_Transacao) = 2025))
    AND month(Data_Transacao) BETWEEN 1 AND 10
    AND Vertical NOT LIKE '%Escolas Próprias%'
    AND Grupo NOT LIKE '%Escolas Próprias%'
    AND Vertical NOT IN ('CDB', 'CSM', 'DEL', 'ESM', 'HEB', 'INT', 'PSM', 'SAR')
),

-- ==========================================================
-- 2. IDENTIFICAÇÃO DO CSC (FLAG - PRIORIDADE MÁXIMA)
-- ==========================================================
csc_flagged AS (
  SELECT *,
    CASE 
      -- Regra 1: Sede Administrativa (Exclui Rateios e Corp BU)
      WHEN Nome_Unidade = 'Sede Administrativa' AND Nome_PnL NOT IN ('Rateio Corporativo', 'Corporativo BU') THEN 1
      -- Regra 2: Corporativo/Rateio em OUTRAS unidades (Captura de qualquer lugar exceto Matriz/Sede)
      WHEN Nome_Unidade NOT IN ('SEB Matriz', 'Sede Administrativa') AND Nome_PnL IN ('Corporativo BU', 'Rateio Corporativo') THEN 1
      -- Regra 3: Conexia Aluguel
      WHEN Grupo = 'Conexia' AND Nome_PnL = 'Aluguel / IPTU' AND Nome_Unidade <> 'Sede Administrativa' THEN 1
      ELSE 0
    END AS is_csc
  FROM source_data
),

-- ==========================================================
-- 3. SEPARAÇÃO DOS DADOS (CSC vs RESTO)
-- ==========================================================

-- 3.1 DADOS CSC (Com Inversão de Sinal)
csc_final AS (
  SELECT 
    'CSC + Cros' AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    
    -- Lógica de Valor CSC: Inverte sinal se NÃO for Sede
    CASE 
      WHEN Nome_Unidade <> 'Sede Administrativa' THEN 
        CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor * -1 ELSE 0 END
      ELSE
        CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END
    END AS Val_ROL,
    
    CASE 
      WHEN Nome_Unidade <> 'Sede Administrativa' THEN 
        CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor * -1 ELSE 0 END
      ELSE
        CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END
    END AS Val_EBITDA,
    
    CASE 
      WHEN Nome_Unidade <> 'Sede Administrativa' THEN Valor * -1
      ELSE Valor
    END AS Valor
    
  FROM csc_flagged
  WHERE is_csc = 1
),

-- 3.2 POOL DE DADOS RESTANTES (Limpo de CSC)
remaining_data AS (
  SELECT * FROM csc_flagged WHERE is_csc = 0
),

-- ==========================================================
-- 4. LÓGICA DAS OUTRAS VERTICAIS (MODULARIZADA)
-- ==========================================================

-- 4.1 PREMIUM BASE
premium_final AS (
  SELECT 
    'Premium Base' AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE 
    (Grupo LIKE '%Pueri Domus%' OR Nome_Unidade LIKE '%Pueri Domus%')
    OR (Grupo LIKE '%Carolina Patrício%' OR Nome_Unidade LIKE '%C. Patrício%' OR Nome_Unidade LIKE '%Carolina Patrício%')
    OR (Vertical = 'Premium' AND Nome_Unidade NOT LIKE '%Sphere%')
),

-- 4.2 SPHERE (School e Franquias)
sphere_final AS (
  SELECT 
    CASE 
      WHEN Nome_Unidade LIKE '%Sphere International School%' THEN 'Sphere School'
      ELSE 'Sphere Franquias'
    END AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE 
    (Nome_Unidade LIKE '%Sphere International School%')
    OR (Grupo LIKE '%Sphere%' OR Nome_Unidade LIKE '%Sphere%')
),

-- 4.3 FRANQUIAS ESPECÍFICAS
franquias_final AS (
  SELECT 
    CASE 
      WHEN Nome_Unidade = 'Maple Bear Brasil' THEN 'Maple Bear Brasil'
      WHEN Nome_Unidade = 'Maple Publicidade' THEN 'Maple Publicidade'
      ELSE 'Outras Franquias'
    END AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE 
    (Nome_Unidade IN ('Maple Bear Brasil', 'Maple Publicidade'))
    OR (Vertical = 'Franquias')
),

-- 4.4 NOVAS VERTICAIS (Publiseb e CEFIC)
novas_verticais_final AS (
  SELECT 
    Nome_Unidade AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE Nome_Unidade IN ('Publiseb', 'CEFIC')
),

-- 4.5 ESTRATÉGICO (Matriz)
estrategico_final AS (
  SELECT 
    'Estrategico + Presidencia' AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE Nome_Unidade = 'SEB Matriz'
),

-- 4.6 OUTROS (Catch-All para o que sobrou)
others_final AS (
  SELECT 
    Vertical AS Vertical_Calc,
    Ano, Mes, Origem, skclasspnl, Nome_PnL, Grupo, skUnidade, Nome_Unidade, Vertical,
    CASE WHEN ROL = 1 AND lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_ROL,
    CASE WHEN lower(Ebitda) = 'sim' AND lower(Recorrente) = 'sim' THEN Valor ELSE 0 END AS Val_EBITDA,
    Valor
  FROM remaining_data
  WHERE 
    -- Exclui tudo que já foi pego acima
    NOT (
      (Grupo LIKE '%Pueri Domus%' OR Nome_Unidade LIKE '%Pueri Domus%')
      OR (Grupo LIKE '%Carolina Patrício%' OR Nome_Unidade LIKE '%C. Patrício%' OR Nome_Unidade LIKE '%Carolina Patrício%')
      OR (Vertical = 'Premium' AND Nome_Unidade NOT LIKE '%Sphere%')
      OR (Nome_Unidade LIKE '%Sphere International School%')
      OR (Grupo LIKE '%Sphere%' OR Nome_Unidade LIKE '%Sphere%')
      OR (Nome_Unidade IN ('Maple Bear Brasil', 'Maple Publicidade'))
      OR (Vertical = 'Franquias')
      OR (Nome_Unidade IN ('Publiseb', 'CEFIC'))
      OR (Nome_Unidade = 'SEB Matriz')
    )
),

-- ==========================================================
-- 5. UNIÃO FINAL (RAW DATA)
-- ==========================================================
raw_data AS (
  SELECT * FROM csc_final
  UNION ALL
  SELECT * FROM premium_final
  UNION ALL
  SELECT * FROM sphere_final
  UNION ALL
  SELECT * FROM franquias_final
  UNION ALL
  SELECT * FROM novas_verticais_final
  UNION ALL
  SELECT * FROM estrategico_final
  UNION ALL
  SELECT * FROM others_final
),

-- ==========================================================
-- 6. AGREGAÇÃO FINANCEIRA (COM REGRAS ESPECÍFICAS DE FORECAST)
-- ==========================================================
financials AS (
  SELECT 
    Vertical_Calc AS Vertical,
    
    -- 2024 REALIZADO (Base para CEFIC)
    round(sum(CASE WHEN Ano = year(current_date) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN Val_ROL ELSE 0 END) * -1, 0) AS ROL_2024,
    round(sum(CASE WHEN Ano = year(current_date) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN Val_EBITDA ELSE 0 END) * -1, 0) AS Res_2024,
    
    -- 2025 FORECAST ROL
    round(CASE 
        -- REGRA CEFIC: Realizado 2024 + 6%
        WHEN Vertical_Calc = 'CEFIC' THEN 
             (sum(CASE WHEN Ano = year(current_date) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN Val_ROL ELSE 0 END) * -1) * 1.06
             
        -- REGRA PUBLISEB: Busca no Budget
        WHEN Vertical_Calc = 'Publiseb' THEN
             sum(CASE WHEN Ano = 2025 AND Origem = 'Budget' THEN Val_ROL ELSE 0 END) * -1
             
        -- REGRA PADRÃO: Busca no Forecast
        ELSE sum(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN Val_ROL ELSE 0 END) * -1
    END, 0) AS ROL_F,
    
    -- 2025 FORECAST EBITDA
    round(CASE 
        -- REGRA CEFIC: Realizado 2024 + 6%
        WHEN Vertical_Calc = 'CEFIC' THEN 
             (sum(CASE WHEN Ano = year(current_date) - 1 AND Origem IN ('Resultado', 'Ajustes') THEN Val_EBITDA ELSE 0 END) * -1) * 1.06
             
        -- REGRA PUBLISEB: Busca no Budget
        WHEN Vertical_Calc = 'Publiseb' THEN
             sum(CASE WHEN Ano = 2025 AND Origem = 'Budget' THEN Val_EBITDA ELSE 0 END) * -1
             
        -- REGRA PADRÃO: Busca no Forecast
        ELSE sum(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN Val_EBITDA ELSE 0 END) * -1
    END, 0) AS Forecast_F,
    
    -- 2025 REALIZADO (Padrão: Resultado + Ajustes)
    round(sum(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN Val_ROL ELSE 0 END) * -1, 0) AS ROL_R,
    round(sum(CASE WHEN Ano = 2025 AND Origem IN ('Resultado', 'Ajustes') THEN Val_EBITDA ELSE 0 END) * -1, 0) AS Res_R
    
  FROM raw_data
  GROUP BY Vertical_Calc
),

-- ==========================================================
-- 7. CÁLCULO DE ALUNOS
-- ==========================================================
students_monthly AS (
  SELECT 
    Vertical_Calc,
    Ano, Mes, Origem,
    sum(Valor) AS qtd_alunos
  FROM raw_data
  WHERE skclasspnl = '400000000' AND Mes BETWEEN 3 AND 10
  GROUP BY Vertical_Calc, Ano, Mes, Origem
),

students_avg AS (
  SELECT
    Vertical_Calc AS Vertical,
    round(avg(CASE WHEN Ano = year(current_date) - 1 AND Origem = 'Alunos' THEN qtd_alunos END), 0) AS Alunos_2024,
    round(avg(CASE WHEN Ano = 2025 AND Origem = 'Forecast' THEN qtd_alunos END), 0) AS Alunos_F,
    round(avg(CASE WHEN Ano = 2025 AND Origem = 'Alunos' THEN qtd_alunos END), 0) AS Alunos_R
  FROM students_monthly
  GROUP BY Vertical_Calc
),

-- ==========================================================
-- 8. CONSOLIDAÇÃO FINAL
-- ==========================================================
base_data AS (
  SELECT 
    coalesce(f.Vertical, s.Vertical) AS Vertical,
    s.Alunos_2024, f.ROL_2024, f.Res_2024 AS Resultado_2024,
    s.Alunos_F, f.ROL_F, f.Forecast_F,
    s.Alunos_R, f.ROL_R, f.Res_R AS Resultado_R
  FROM financials f
  FULL OUTER JOIN students_avg s ON f.Vertical = s.Vertical
)

-- ==========================================================
-- 9. SELECTS FINAIS
-- ==========================================================

-- [1] PREMIUM
SELECT 
  'Premium' AS Vertical,
  round(sum(Alunos_2024), 0) AS `Alunos (10M24 R)`,
  round(sum(ROL_2024), 0) AS `ROL (10M24 R)`,
  round(sum(Resultado_2024), 0) AS `Resultado (10M24 R)`,
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END AS `%Ebtida (10M24 R)`,
  
  round(sum(Alunos_F), 0) AS `Alunos (10M25 F)`,
  round(sum(ROL_F), 0) AS `ROL (10M25 F)`,
  round(sum(Forecast_F), 0) AS `Forecast (10M25 F)`,
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END AS `%Ebtida (10M25 F)`,
  
  round(sum(Alunos_R), 0) AS `Alunos (10M25 R)`,
  round(sum(ROL_R), 0) AS `ROL (10M25 R)`,
  round(sum(Resultado_R), 0) AS `Resultado (10M25 R)`,
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END AS `%Ebtida (10M25 R)`,
  
  round(sum(Alunos_R) - sum(Alunos_F), 0) AS `Var Alunos`,
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END AS `Var % Alunos`,
  
  round(sum(ROL_R) - sum(ROL_F), 0) AS `Var ROL`,
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END AS `Var % ROL`,
  
  round(sum(Resultado_R) - sum(Forecast_F), 0) AS `Var EBITDA`,
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END AS `Var % EBITDA`,
  
  1.0 AS sort_order
FROM base_data 
WHERE Vertical IN ('Premium Base', 'Sphere School')
GROUP BY 1

UNION ALL

-- [VANGUARDA]
SELECT 
  'Vanguarda',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END,
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END,
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END,
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END,
  round(sum(ROL_R) - sum(ROL_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END,
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END,
  1.0
FROM base_data 
WHERE Vertical = 'Vanguarda'
GROUP BY 1

UNION ALL

-- [2] SUBTOTAL ESCOLAS
SELECT 
  'Operações Premium - Escolas',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END,
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END,
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END,
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END,
  round(sum(ROL_R) - sum(ROL_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END,
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END,
  2.0
FROM base_data 
WHERE Vertical IN ('Premium Base', 'Sphere School', 'Vanguarda')
GROUP BY 1

UNION ALL

-- [3] FRANQUIAS INDIVIDUAIS
SELECT 
  Vertical,
  round(Alunos_2024, 0), round(ROL_2024, 0), round(Resultado_2024, 0),
  CASE WHEN ROL_2024 = 0 OR ROL_2024 IS NULL THEN NULL ELSE NULLIF(round(Resultado_2024 / ROL_2024 * 100, 0), 0) END,
  round(Alunos_F, 0), round(ROL_F, 0), round(Forecast_F, 0),
  CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE NULLIF(round(Forecast_F / ROL_F * 100, 0), 0) END,
  round(Alunos_R, 0), round(ROL_R, 0), round(Resultado_R, 0),
  CASE WHEN ROL_R = 0 OR ROL_R IS NULL THEN NULL ELSE NULLIF(round(Resultado_R / ROL_R * 100, 0), 0) END,
  round(Alunos_R - Alunos_F, 0),
  CASE WHEN Alunos_F = 0 OR Alunos_F IS NULL THEN NULL ELSE round(((Alunos_R - Alunos_F) / abs(Alunos_F)) * 100, 1) END,
  round(ROL_R - ROL_F, 0),
  CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE round(((ROL_R - ROL_F) / abs(ROL_F)) * 100, 1) END,
  round(Resultado_R - Forecast_F, 0),
  CASE WHEN Forecast_F = 0 OR Forecast_F IS NULL THEN NULL ELSE round(((Resultado_R - Forecast_F) / abs(Forecast_F)) * 100, 1) END,
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

-- [4] SUBTOTAL FRANQUIAS
SELECT 
  'Operações Premium - Franquias',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END,
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END,
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END,
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END,
  round(sum(ROL_R) - sum(ROL_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END,
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END,
  4.0
FROM base_data 
WHERE Vertical IN ('MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade')
GROUP BY 1

UNION ALL

-- [5] OPERAÇÕES PREMIUM (SOMENTE ESCOLAS + FRANQUIAS)
SELECT 
  'Operações Premium',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END,
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END,
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END,
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END,
  round(sum(ROL_R) - sum(ROL_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END,
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END,
  5.0
FROM base_data 
WHERE Vertical IN ('Premium Base', 'Sphere School', 'Vanguarda', 'MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade')
GROUP BY 1

UNION ALL

-- [NEW] ESTRATÉGICO INDIVIDUAL
SELECT 
  Vertical,
  round(Alunos_2024, 0), round(ROL_2024, 0), round(Resultado_2024, 0),
  NULL, -- %Ebtida (10M24 R)
  round(Alunos_F, 0), round(ROL_F, 0), round(Forecast_F, 0),
  NULL, -- %Ebtida (10M25 F)
  round(Alunos_R, 0), round(ROL_R, 0), round(Resultado_R, 0),
  NULL, -- %Ebtida (10M25 R)
  round(Alunos_R - Alunos_F, 0),
  NULL, -- Var % Alunos
  round(ROL_R - ROL_F, 0),
  NULL, -- Var % ROL
  round(Resultado_R - Forecast_F, 0),
  NULL, -- Var % EBITDA
  CASE Vertical
    WHEN 'Estrategico + Presidencia' THEN 5.1
    WHEN 'CSC + Cros' THEN 5.2
    WHEN 'Holding' THEN 5.3
    ELSE 5.9
  END
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding')

UNION ALL

-- [NEW] SUBTOTAL ESTRATÉGICO + CORP
SELECT 
  'Estratégico + Presidência + Corporativo',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  NULL, -- %Ebtida (10M24 R)
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  NULL, -- %Ebtida (10M25 F)
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  NULL, -- %Ebtida (10M25 R)
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  NULL, -- Var % Alunos
  round(sum(ROL_R) - sum(ROL_F), 0),
  NULL, -- Var % ROL
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  NULL, -- Var % EBITDA
  5.4
FROM base_data 
WHERE Vertical IN ('Estrategico + Presidencia', 'CSC + Cros', 'Holding')
GROUP BY 1

UNION ALL

-- [6] PUBLISEB E CEFIC (Linhas Individuais)
SELECT 
  Vertical,
  round(Alunos_2024, 0), round(ROL_2024, 0), round(Resultado_2024, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_2024 = 0 OR ROL_2024 IS NULL THEN NULL ELSE NULLIF(round(Resultado_2024 / ROL_2024 * 100, 0), 0) END END,
  round(Alunos_F, 0), round(ROL_F, 0), round(Forecast_F, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE NULLIF(round(Forecast_F / ROL_F * 100, 0), 0) END END,
  round(Alunos_R, 0), round(ROL_R, 0), round(Resultado_R, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_R = 0 OR ROL_R IS NULL THEN NULL ELSE NULLIF(round(Resultado_R / ROL_R * 100, 0), 0) END END,
  round(Alunos_R - Alunos_F, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN Alunos_F = 0 OR Alunos_F IS NULL THEN NULL ELSE round(((Alunos_R - Alunos_F) / abs(Alunos_F)) * 100, 1) END END,
  round(ROL_R - ROL_F, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN ROL_F = 0 OR ROL_F IS NULL THEN NULL ELSE round(((ROL_R - ROL_F) / abs(ROL_F)) * 100, 1) END END,
  round(Resultado_R - Forecast_F, 0),
  CASE WHEN Vertical = 'Publiseb' THEN NULL ELSE CASE WHEN Forecast_F = 0 OR Forecast_F IS NULL THEN NULL ELSE round(((Resultado_R - Forecast_F) / abs(Forecast_F)) * 100, 1) END END,
  CASE Vertical
    WHEN 'Publiseb' THEN 6.1
    WHEN 'CEFIC' THEN 6.2
    ELSE 6.9
  END AS sort_order
FROM base_data 
WHERE Vertical IN ('Publiseb', 'CEFIC')

UNION ALL

-- [7] TOTAL ESTRATÉGICO (Novo Subtotal - Apenas Publiseb e CEFIC)
SELECT 
  'Total Estratégico',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  NULL, -- %Ebtida (10M24 R)
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  NULL, -- %Ebtida (10M25 F)
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  NULL, -- %Ebtida (10M25 R)
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  NULL, -- Var % Alunos
  round(sum(ROL_R) - sum(ROL_F), 0),
  NULL, -- Var % ROL
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  NULL, -- Var % EBITDA
  7.0
FROM base_data 
WHERE Vertical IN ('Publiseb', 'CEFIC', 'Estrategico + Presidencia', 'CSC + Cros', 'Holding')
GROUP BY 1

UNION ALL

-- [8] TOTAL OP. PREMIUM (Total Geral Completo)
SELECT 
  'Total Op. Premium',
  round(sum(Alunos_2024), 0), round(sum(ROL_2024), 0), round(sum(Resultado_2024), 0),
  CASE WHEN sum(ROL_2024) = 0 OR sum(ROL_2024) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_2024) / sum(ROL_2024) * 100, 0), 0) END,
  round(sum(Alunos_F), 0), round(sum(ROL_F), 0), round(sum(Forecast_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE NULLIF(round(sum(Forecast_F) / sum(ROL_F) * 100, 0), 0) END,
  round(sum(Alunos_R), 0), round(sum(ROL_R), 0), round(sum(Resultado_R), 0),
  CASE WHEN sum(ROL_R) = 0 OR sum(ROL_R) IS NULL THEN NULL ELSE NULLIF(round(sum(Resultado_R) / sum(ROL_R) * 100, 0), 0) END,
  round(sum(Alunos_R) - sum(Alunos_F), 0),
  CASE WHEN sum(Alunos_F) = 0 OR sum(Alunos_F) IS NULL THEN NULL ELSE round(((sum(Alunos_R) - sum(Alunos_F)) / abs(sum(Alunos_F))) * 100, 1) END,
  round(sum(ROL_R) - sum(ROL_F), 0),
  CASE WHEN sum(ROL_F) = 0 OR sum(ROL_F) IS NULL THEN NULL ELSE round(((sum(ROL_R) - sum(ROL_F)) / abs(sum(ROL_F))) * 100, 1) END,
  round(sum(Resultado_R) - sum(Forecast_F), 0),
  CASE WHEN sum(Forecast_F) = 0 OR sum(Forecast_F) IS NULL THEN NULL ELSE round(((sum(Resultado_R) - sum(Forecast_F)) / abs(sum(Forecast_F))) * 100, 1) END,
  8.0
FROM base_data 
WHERE Vertical IN (
  'Premium Base', 'Sphere School', 'Vanguarda', 
  'MBGS', 'Maple LATAM', 'Maple US', 'Maple Bear Brasil', 'Sphere Franquias', 'Maple Publicidade',
  'Publiseb', 'CEFIC', 'Estrategico + Presidencia', 'CSC + Cros', 'Holding'
)
GROUP BY 1

ORDER BY sort_order, Vertical
