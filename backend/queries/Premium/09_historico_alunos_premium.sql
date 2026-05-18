-- @id: premium_historico_alunos
-- @name: Premium - Histórico de Alunos
-- @category: Premium
-- @order: 10

-- ============================================================
-- Histórico de Alunos — Premium
-- 3 seções empilhadas: Histórico (ano anterior),
-- Forecast (ano atual) e Realizado (ano atual)
-- ============================================================

WITH params AS (
    SELECT
        :ano_selecionado     AS ano_atual,
        :ano_anterior        AS ano_anterior,
        :mes_selecionado     AS mes_ytd,
        'Premium'            AS vertical
),

-- ============================================================
-- SEÇÃO 1: HISTÓRICO (f_alunos — ano anterior)
-- ============================================================

premium_units AS (
    SELECT DISTINCT skUnidade
    FROM financeiro.prd.mv_f_apresentacao
    WHERE Vertical = (SELECT vertical FROM params)
),

-- Dados de f_alunos para AMBOS os anos (Histórico e Realizado)
falunos_base AS (
    SELECT
        a.Segmento,
        YEAR(a.Data) AS ano,
        MONTH(a.Data) AS mes,
        SUM(a.QtdAlunos) AS qtd
    FROM financeiro.prd.f_alunos a
    CROSS JOIN params p
    WHERE a.skUnidade IN (SELECT skUnidade FROM premium_units)
      AND YEAR(a.Data) IN (p.ano_anterior, p.ano_atual)
      AND a.Segmento IN ('EI','EFI','EFII','PV','EM')
    GROUP BY a.Segmento, YEAR(a.Data), MONTH(a.Data)
),

hist_alunos AS (
    SELECT Segmento, mes, qtd
    FROM falunos_base
    WHERE ano = (SELECT ano_anterior FROM params)
),

real_alunos AS (
    SELECT Segmento, mes, qtd
    FROM falunos_base
    WHERE ano = (SELECT ano_atual FROM params)
),

hist_pivot AS (
    SELECT
        Segmento,
        SUM(CASE WHEN mes = 1  THEN qtd ELSE 0 END) AS m1,
        SUM(CASE WHEN mes = 2  THEN qtd ELSE 0 END) AS m2,
        SUM(CASE WHEN mes = 3  THEN qtd ELSE 0 END) AS m3,
        SUM(CASE WHEN mes = 4  THEN qtd ELSE 0 END) AS m4,
        SUM(CASE WHEN mes = 5  THEN qtd ELSE 0 END) AS m5,
        SUM(CASE WHEN mes = 6  THEN qtd ELSE 0 END) AS m6,
        SUM(CASE WHEN mes = 7  THEN qtd ELSE 0 END) AS m7,
        SUM(CASE WHEN mes = 8  THEN qtd ELSE 0 END) AS m8,
        SUM(CASE WHEN mes = 9  THEN qtd ELSE 0 END) AS m9,
        SUM(CASE WHEN mes = 10 THEN qtd ELSE 0 END) AS m10,
        SUM(CASE WHEN mes = 11 THEN qtd ELSE 0 END) AS m11,
        SUM(CASE WHEN mes = 12 THEN qtd ELSE 0 END) AS m12
    FROM hist_alunos
    GROUP BY Segmento
),

hist_total AS (
    SELECT
        'Total' AS Segmento,
        SUM(m1) AS m1, SUM(m2) AS m2, SUM(m3) AS m3, SUM(m4) AS m4,
        SUM(m5) AS m5, SUM(m6) AS m6, SUM(m7) AS m7, SUM(m8) AS m8,
        SUM(m9) AS m9, SUM(m10) AS m10, SUM(m11) AS m11, SUM(m12) AS m12
    FROM hist_pivot
),

hist AS (
    SELECT * FROM hist_pivot
    UNION ALL
    SELECT * FROM hist_total
),

-- ============================================================
-- SEÇÃO 2 e 3: FORECAST / REALIZADO (f_alunos_forecastrealizado)
-- ============================================================

fcst_real_base AS (
    SELECT
        CASE
            WHEN CursoServico LIKE '%1ST%' OR CursoServico LIKE '%2ND%'
              OR CursoServico LIKE '%3RD%' OR CursoServico LIKE '%4TH%'
              OR CursoServico LIKE '%5TH%' THEN 'EFI'
            WHEN CursoServico LIKE '%6TH%' OR CursoServico LIKE '%7TH%'
              OR CursoServico LIKE '%8TH%' OR CursoServico LIKE '%9TH%' THEN 'EFII'
            WHEN CursoServico LIKE '%10TH%' OR CursoServico LIKE '%11TH%'
              OR CursoServico LIKE '%12TH%' OR CursoServico LIKE '%SERIE MEDIO%' THEN 'EM'
            ELSE 'EI'
        END AS Segmento,
        Versao,
        `month(Data)` AS mes,
        SUM(QtdAlunos) AS qtd
    FROM financeiro.prd.f_alunos_forecastrealizado fr
    CROSS JOIN params p
    WHERE fr.Vertical = 'Premium'
      AND fr.`year(Data)` = p.ano_atual
      AND fr.Versao = 'Forecast'
    GROUP BY 1, 2, 3
),

fcst_real_pivot AS (
    SELECT
        Segmento,
        Versao,
        SUM(CASE WHEN mes = 1  THEN qtd ELSE 0 END) AS m1,
        SUM(CASE WHEN mes = 2  THEN qtd ELSE 0 END) AS m2,
        SUM(CASE WHEN mes = 3  THEN qtd ELSE 0 END) AS m3,
        SUM(CASE WHEN mes = 4  THEN qtd ELSE 0 END) AS m4,
        SUM(CASE WHEN mes = 5  THEN qtd ELSE 0 END) AS m5,
        SUM(CASE WHEN mes = 6  THEN qtd ELSE 0 END) AS m6,
        SUM(CASE WHEN mes = 7  THEN qtd ELSE 0 END) AS m7,
        SUM(CASE WHEN mes = 8  THEN qtd ELSE 0 END) AS m8,
        SUM(CASE WHEN mes = 9  THEN qtd ELSE 0 END) AS m9,
        SUM(CASE WHEN mes = 10 THEN qtd ELSE 0 END) AS m10,
        SUM(CASE WHEN mes = 11 THEN qtd ELSE 0 END) AS m11,
        SUM(CASE WHEN mes = 12 THEN qtd ELSE 0 END) AS m12
    FROM fcst_real_base
    GROUP BY Segmento, Versao
),

fcst_real_total AS (
    SELECT
        'Total' AS Segmento,
        Versao,
        SUM(m1) AS m1, SUM(m2) AS m2, SUM(m3) AS m3, SUM(m4) AS m4,
        SUM(m5) AS m5, SUM(m6) AS m6, SUM(m7) AS m7, SUM(m8) AS m8,
        SUM(m9) AS m9, SUM(m10) AS m10, SUM(m11) AS m11, SUM(m12) AS m12
    FROM fcst_real_pivot
    GROUP BY Versao
),

fcst AS (
    SELECT * FROM fcst_real_pivot WHERE Versao = 'Forecast'
    UNION ALL
    SELECT * FROM fcst_real_total WHERE Versao = 'Forecast'
),

-- Realizado: vem de f_alunos (com Segmento correto)
real_pivot AS (
    SELECT
        Segmento,
        SUM(CASE WHEN mes = 1  THEN qtd ELSE 0 END) AS m1,
        SUM(CASE WHEN mes = 2  THEN qtd ELSE 0 END) AS m2,
        SUM(CASE WHEN mes = 3  THEN qtd ELSE 0 END) AS m3,
        SUM(CASE WHEN mes = 4  THEN qtd ELSE 0 END) AS m4,
        SUM(CASE WHEN mes = 5  THEN qtd ELSE 0 END) AS m5,
        SUM(CASE WHEN mes = 6  THEN qtd ELSE 0 END) AS m6,
        SUM(CASE WHEN mes = 7  THEN qtd ELSE 0 END) AS m7,
        SUM(CASE WHEN mes = 8  THEN qtd ELSE 0 END) AS m8,
        SUM(CASE WHEN mes = 9  THEN qtd ELSE 0 END) AS m9,
        SUM(CASE WHEN mes = 10 THEN qtd ELSE 0 END) AS m10,
        SUM(CASE WHEN mes = 11 THEN qtd ELSE 0 END) AS m11,
        SUM(CASE WHEN mes = 12 THEN qtd ELSE 0 END) AS m12
    FROM real_alunos
    GROUP BY Segmento
),

real_total AS (
    SELECT
        'Total' AS Segmento,
        SUM(m1) AS m1, SUM(m2) AS m2, SUM(m3) AS m3, SUM(m4) AS m4,
        SUM(m5) AS m5, SUM(m6) AS m6, SUM(m7) AS m7, SUM(m8) AS m8,
        SUM(m9) AS m9, SUM(m10) AS m10, SUM(m11) AS m11, SUM(m12) AS m12
    FROM real_pivot
),

realizado AS (
    SELECT * FROM real_pivot
    UNION ALL
    SELECT * FROM real_total
),

-- ============================================================
-- SEÇÃO 4: VARIAÇÃO (prev x real) = Realizado - Forecast
-- Se Total Realizado do mês = 0, retorna NULL
-- ============================================================

-- Total do Realizado para saber quais meses têm dados
real_total_check AS (
    SELECT * FROM real_total
),

var_prev_real AS (
    SELECT
        r.Segmento,
        CASE WHEN rt.m1  = 0 THEN NULL ELSE r.m1  - f.m1  END AS m1,
        CASE WHEN rt.m2  = 0 THEN NULL ELSE r.m2  - f.m2  END AS m2,
        CASE WHEN rt.m3  = 0 THEN NULL ELSE r.m3  - f.m3  END AS m3,
        CASE WHEN rt.m4  = 0 THEN NULL ELSE r.m4  - f.m4  END AS m4,
        CASE WHEN rt.m5  = 0 THEN NULL ELSE r.m5  - f.m5  END AS m5,
        CASE WHEN rt.m6  = 0 THEN NULL ELSE r.m6  - f.m6  END AS m6,
        CASE WHEN rt.m7  = 0 THEN NULL ELSE r.m7  - f.m7  END AS m7,
        CASE WHEN rt.m8  = 0 THEN NULL ELSE r.m8  - f.m8  END AS m8,
        CASE WHEN rt.m9  = 0 THEN NULL ELSE r.m9  - f.m9  END AS m9,
        CASE WHEN rt.m10 = 0 THEN NULL ELSE r.m10 - f.m10 END AS m10,
        CASE WHEN rt.m11 = 0 THEN NULL ELSE r.m11 - f.m11 END AS m11,
        CASE WHEN rt.m12 = 0 THEN NULL ELSE r.m12 - f.m12 END AS m12
    FROM realizado r
    JOIN (
        SELECT Segmento, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12
        FROM fcst_real_pivot WHERE Versao = 'Forecast'
        UNION ALL
        SELECT Segmento, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12
        FROM fcst_real_total WHERE Versao = 'Forecast'
    ) f ON r.Segmento = f.Segmento
    CROSS JOIN real_total_check rt
)

-- ============================================================
-- OUTPUT FINAL (3 seções empilhadas)
-- ============================================================

-- ==================== HISTÓRICO ====================

-- Header Histórico
SELECT 'Histórico ' || CAST((SELECT ano_anterior FROM params) AS STRING) AS descricao,
    NULL AS Jan, NULL AS Fev, NULL AS Mar, NULL AS Abr, NULL AS Mai, NULL AS Jun,
    NULL AS Jul, NULL AS Ago, NULL AS `Set`, NULL AS `Out`, NULL AS Nov, NULL AS Dez,
    NULL AS media_mar_dez,
    0 AS sort_order

UNION ALL

-- H1. EI
SELECT 'EI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 1
FROM hist WHERE Segmento = 'EI'

UNION ALL

-- H2. EFI
SELECT 'EFI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 2
FROM hist WHERE Segmento = 'EFI'

UNION ALL

-- H3. EFII
SELECT 'EFII',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 3
FROM hist WHERE Segmento = 'EFII'

UNION ALL

-- H4. PV (sem dados — zeros)
SELECT 'PV', 0,0,0,0,0,0,0,0,0,0,0,0, 0, 4

UNION ALL

-- H5. Total
SELECT 'Total',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 5
FROM hist WHERE Segmento = 'Total'

UNION ALL

-- H6. Var. (começa de Mar)
SELECT 'Var.',
    NULL, NULL, t.m3-t.m2, t.m4-t.m3, t.m5-t.m4, t.m6-t.m5,
    t.m7-t.m6, t.m8-t.m7, t.m9-t.m8, t.m10-t.m9, t.m11-t.m10, t.m12-t.m11,
    NULL, 6
FROM hist t WHERE t.Segmento = 'Total'

UNION ALL

-- H7. Var. YTD (Total[M] - Total[Fev])
SELECT 'Var. YTD',
    NULL, NULL, t.m3-t.m2, t.m4-t.m2, t.m5-t.m2, t.m6-t.m2,
    t.m7-t.m2, t.m8-t.m2, t.m9-t.m2, t.m10-t.m2, t.m11-t.m2, t.m12-t.m2,
    NULL, 7
FROM hist t WHERE t.Segmento = 'Total'

UNION ALL

-- ==================== FORECAST ====================

-- Header Forecast
SELECT 'Forecast ' || CAST((SELECT ano_atual FROM params) AS STRING),
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, 10

UNION ALL

-- F1. EI
SELECT 'EI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 11
FROM fcst WHERE Segmento = 'EI'

UNION ALL

-- F2. EFI
SELECT 'EFI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 12
FROM fcst WHERE Segmento = 'EFI'

UNION ALL

-- F3. EFII
SELECT 'EFII',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 13
FROM fcst WHERE Segmento = 'EFII'

UNION ALL

-- F4. PV (sem dados — zeros)
SELECT 'PV', 0,0,0,0,0,0,0,0,0,0,0,0, 0, 14

UNION ALL

-- F5. Total
SELECT 'Total',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 15
FROM fcst WHERE Segmento = 'Total'

UNION ALL

-- F6. Var. (começa de Mar)
SELECT 'Var.',
    NULL, NULL, t.m3-t.m2, t.m4-t.m3, t.m5-t.m4, t.m6-t.m5,
    t.m7-t.m6, t.m8-t.m7, t.m9-t.m8, t.m10-t.m9, t.m11-t.m10, t.m12-t.m11,
    NULL, 16
FROM fcst t WHERE t.Segmento = 'Total'

UNION ALL

-- F7. Var. YTD (Total[M] - Total[Fev])
SELECT 'Var. YTD',
    NULL, NULL, t.m3-t.m2, t.m4-t.m2, t.m5-t.m2, t.m6-t.m2,
    t.m7-t.m2, t.m8-t.m2, t.m9-t.m2, t.m10-t.m2, t.m11-t.m2, t.m12-t.m2,
    NULL, 17
FROM fcst t WHERE t.Segmento = 'Total'

UNION ALL

-- ==================== REALIZADO ====================

-- Header Realizado
SELECT 'Realizado',
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, 20

UNION ALL

-- R1. EI
SELECT 'EI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 21
FROM realizado WHERE Segmento = 'EI'

UNION ALL

-- R2. EFI
SELECT 'EFI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 22
FROM realizado WHERE Segmento = 'EFI'

UNION ALL

-- R3. EFII
SELECT 'EFII',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 23
FROM realizado WHERE Segmento = 'EFII'

UNION ALL

-- R4. PV (sem dados — zeros)
SELECT 'PV', 0,0,0,0,0,0,0,0,0,0,0,0, 0, 24

UNION ALL

-- R5. Total
SELECT 'Total',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((m3+m4+m5+m6+m7+m8+m9+m10+m11+m12) / 10.0, 0), 25
FROM realizado WHERE Segmento = 'Total'

UNION ALL

-- R6. Var. (começa de Mar; meses sem realizado = 0 viram NULL)
SELECT 'Var.',
    NULL, NULL, t.m3-t.m2,
    CASE WHEN t.m4 = 0 THEN NULL ELSE t.m4-t.m3 END,
    CASE WHEN t.m5 = 0 THEN NULL ELSE t.m5-t.m4 END,
    CASE WHEN t.m6 = 0 THEN NULL ELSE t.m6-t.m5 END,
    CASE WHEN t.m7 = 0 THEN NULL ELSE t.m7-t.m6 END,
    CASE WHEN t.m8 = 0 THEN NULL ELSE t.m8-t.m7 END,
    CASE WHEN t.m9 = 0 THEN NULL ELSE t.m9-t.m8 END,
    CASE WHEN t.m10 = 0 THEN NULL ELSE t.m10-t.m9 END,
    CASE WHEN t.m11 = 0 THEN NULL ELSE t.m11-t.m10 END,
    CASE WHEN t.m12 = 0 THEN NULL ELSE t.m12-t.m11 END,
    NULL, 26
FROM realizado t WHERE t.Segmento = 'Total'

UNION ALL

-- R7. Var. YTD (Total[M] - Total[Fev])
SELECT 'Var. YTD',
    NULL, NULL, t.m3-t.m2,
    CASE WHEN t.m4 = 0 THEN NULL ELSE t.m4-t.m2 END,
    CASE WHEN t.m5 = 0 THEN NULL ELSE t.m5-t.m2 END,
    CASE WHEN t.m6 = 0 THEN NULL ELSE t.m6-t.m2 END,
    CASE WHEN t.m7 = 0 THEN NULL ELSE t.m7-t.m2 END,
    CASE WHEN t.m8 = 0 THEN NULL ELSE t.m8-t.m2 END,
    CASE WHEN t.m9 = 0 THEN NULL ELSE t.m9-t.m2 END,
    CASE WHEN t.m10 = 0 THEN NULL ELSE t.m10-t.m2 END,
    CASE WHEN t.m11 = 0 THEN NULL ELSE t.m11-t.m2 END,
    CASE WHEN t.m12 = 0 THEN NULL ELSE t.m12-t.m2 END,
    NULL, 27
FROM realizado t WHERE t.Segmento = 'Total'

UNION ALL

-- ==================== VARIAÇÃO (prev x real) ====================

-- Header Variação
SELECT 'Variação (prev x real)',
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, 30

UNION ALL

-- V1. EI
SELECT 'EI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((COALESCE(m3,0)+COALESCE(m4,0)+COALESCE(m5,0)+COALESCE(m6,0)+COALESCE(m7,0)+COALESCE(m8,0)+COALESCE(m9,0)+COALESCE(m10,0)+COALESCE(m11,0)+COALESCE(m12,0))
        / NULLIF((CASE WHEN m3 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m4 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m5 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m6 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m7 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m8 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m9 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m10 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m11 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m12 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 31
FROM var_prev_real WHERE Segmento = 'EI'

UNION ALL

-- V2. EFI
SELECT 'EFI',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((COALESCE(m3,0)+COALESCE(m4,0)+COALESCE(m5,0)+COALESCE(m6,0)+COALESCE(m7,0)+COALESCE(m8,0)+COALESCE(m9,0)+COALESCE(m10,0)+COALESCE(m11,0)+COALESCE(m12,0))
        / NULLIF((CASE WHEN m3 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m4 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m5 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m6 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m7 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m8 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m9 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m10 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m11 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m12 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 32
FROM var_prev_real WHERE Segmento = 'EFI'

UNION ALL

-- V3. EFII
SELECT 'EFII',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((COALESCE(m3,0)+COALESCE(m4,0)+COALESCE(m5,0)+COALESCE(m6,0)+COALESCE(m7,0)+COALESCE(m8,0)+COALESCE(m9,0)+COALESCE(m10,0)+COALESCE(m11,0)+COALESCE(m12,0))
        / NULLIF((CASE WHEN m3 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m4 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m5 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m6 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m7 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m8 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m9 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m10 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m11 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m12 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 33
FROM var_prev_real WHERE Segmento = 'EFII'

UNION ALL

-- V4. PV
SELECT 'PV', NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL, NULL, 34

UNION ALL

-- V5. Total
SELECT 'Total',
    m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12,
    ROUND((COALESCE(m3,0)+COALESCE(m4,0)+COALESCE(m5,0)+COALESCE(m6,0)+COALESCE(m7,0)+COALESCE(m8,0)+COALESCE(m9,0)+COALESCE(m10,0)+COALESCE(m11,0)+COALESCE(m12,0))
        / NULLIF((CASE WHEN m3 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m4 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m5 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m6 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m7 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m8 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m9 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m10 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m11 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN m12 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 35
FROM var_prev_real WHERE Segmento = 'Total'

UNION ALL

-- V6. Var. (começa de Mar)
SELECT 'Var.',
    NULL, NULL,
    CASE WHEN t.m3 IS NULL OR t.m2 IS NULL THEN NULL ELSE t.m3 - t.m2 END,
    CASE WHEN t.m4 IS NULL THEN NULL ELSE t.m4 - t.m3 END,
    CASE WHEN t.m5 IS NULL THEN NULL ELSE t.m5 - t.m4 END,
    CASE WHEN t.m6 IS NULL THEN NULL ELSE t.m6 - t.m5 END,
    CASE WHEN t.m7 IS NULL THEN NULL ELSE t.m7 - t.m6 END,
    CASE WHEN t.m8 IS NULL THEN NULL ELSE t.m8 - t.m7 END,
    CASE WHEN t.m9 IS NULL THEN NULL ELSE t.m9 - t.m8 END,
    CASE WHEN t.m10 IS NULL THEN NULL ELSE t.m10 - t.m9 END,
    CASE WHEN t.m11 IS NULL THEN NULL ELSE t.m11 - t.m10 END,
    CASE WHEN t.m12 IS NULL THEN NULL ELSE t.m12 - t.m11 END,
    ROUND((COALESCE(CASE WHEN t.m3 IS NULL OR t.m2 IS NULL THEN NULL ELSE t.m3 - t.m2 END, 0))
        / NULLIF((CASE WHEN t.m3 IS NOT NULL AND t.m2 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 36
FROM var_prev_real t WHERE t.Segmento = 'Total'

UNION ALL

-- V7. Var. YTD (Total[M] - Total[Fev], com NULL onde não há dados)
SELECT 'Var. YTD',
    NULL, NULL,
    CASE WHEN t.m3 IS NULL THEN NULL ELSE t.m3 - t.m2 END,
    CASE WHEN t.m4 IS NULL THEN NULL ELSE t.m4 - t.m2 END,
    CASE WHEN t.m5 IS NULL THEN NULL ELSE t.m5 - t.m2 END,
    CASE WHEN t.m6 IS NULL THEN NULL ELSE t.m6 - t.m2 END,
    CASE WHEN t.m7 IS NULL THEN NULL ELSE t.m7 - t.m2 END,
    CASE WHEN t.m8 IS NULL THEN NULL ELSE t.m8 - t.m2 END,
    CASE WHEN t.m9 IS NULL THEN NULL ELSE t.m9 - t.m2 END,
    CASE WHEN t.m10 IS NULL THEN NULL ELSE t.m10 - t.m2 END,
    CASE WHEN t.m11 IS NULL THEN NULL ELSE t.m11 - t.m2 END,
    CASE WHEN t.m12 IS NULL THEN NULL ELSE t.m12 - t.m2 END,
    ROUND((COALESCE(CASE WHEN t.m3 IS NULL THEN NULL ELSE t.m3 - t.m2 END, 0))
        / NULLIF((CASE WHEN t.m3 IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 0), 37
FROM var_prev_real t WHERE t.Segmento = 'Total'

ORDER BY sort_order
