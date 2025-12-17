-- @id: relatorio_gerencial_v20_zero_join
-- @name: Relatório Gerencial
-- @category: diretorias
-- @order: 65

WITH dim_diretorias AS (
    -- ==========================================================
    -- 1. MAPA DE DIRETORIAS (Mantido via tabela auxiliar pois o mapeamento de CC não existe na MV)
    -- ==========================================================
    SELECT idCentroCustos, Diretoria, 'Rateavel' as Grupo_Logico
    FROM financeiro.prd.d_centrocustosxlsx
    WHERE Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços')
    
    UNION ALL
    SELECT idCentroCustos, 'Auditoria', 'Rateavel' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Diretoria Executiva' AND Area = 'Auditoria'
    UNION ALL
    SELECT idCentroCustos, 'Eventos Estratégicos', 'Sem_Trava' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Presidência' AND Area = 'Eventos Estratégicos'
    UNION ALL
    SELECT idCentroCustos, 'Planejamento Estratégico', 'Sem_Trava' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Presidência' AND Area = 'Planejamento Estratégico'
    UNION ALL
    SELECT idCentroCustos, 'Return on Learning', 'Sem_Trava' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Presidência' AND Area = 'Return on Learning'
    UNION ALL
    SELECT idCentroCustos, 'Diretoria Executiva', 'Executiva_Core' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Diretoria Executiva' AND Area = 'Diretoria Executiva'
    UNION ALL
    SELECT idCentroCustos, 'Presidência', 'Presidencia_Complexa' FROM financeiro.prd.d_centrocustosxlsx WHERE (Diretoria = 'Presidência' AND Area = 'Presidência') OR idCentroCustos IN ('30101018', '30401001')
    UNION ALL
    SELECT idCentroCustos, 'MBGS', 'MBGS_Filter' FROM financeiro.prd.d_centrocustosxlsx WHERE Diretoria = 'Outros' AND Area = 'MBGS'
    UNION ALL
    SELECT idCentroCustos, 'Resultado Não Operacional', 'Res_Nao_Op_Filter' FROM financeiro.prd.d_centrocustosxlsx WHERE Area = 'Resultado Não Operacional'
),

fatos_brutos AS (
    -- ==========================================================
    -- 2. EXTRAÇÃO E TRATAMENTO (PROTOCOLO ZERO JOIN)
    -- ==========================================================
    SELECT
        Origem,
        Valor,
        Vertical,
        skUnidade,
        skclasspnl,
        -- Extração do Centro de Custo direto da chave PnL
        SUBSTRING(skclasspnl, 13, 8) AS join_key_cc,
        -- Extração do Estabelecimento Fiscal (Protocolo Otimizado)
        RIGHT(skUnidade, 4) AS EstFiscal, 
        MONTH(Data_Transacao) AS Mes_Transacao,
        -- Colunas Nativas da MV (Substituem d_classpnl/link_pnl)
        Nome_PnL,
        Ebitda,     -- Já vem como String ('Sim'/'Não')
        Recorrente  -- Já vem como String ('Sim'/'Não')
    FROM financeiro.prd.mv_f_apresentacao
    WHERE YEAR(Data_Transacao) = 2025
      AND MONTH(Data_Transacao) BETWEEN 1 AND 12
      AND Origem IN ('Forecast', 'Resultado', 'Ajustes')
),

dados_consolidados AS (
    SELECT
        cc.Diretoria,
        f.Origem,
        f.Valor,
        f.Mes_Transacao,
        f.join_key_cc,
        
        -- VALIDAÇÃO DE CONTEÚDO (Usando EstFiscal extraído)
        CASE
            WHEN cc.Grupo_Logico IN ('MBGS_Filter', 'Res_Nao_Op_Filter') THEN
                CASE 
                    WHEN f.Origem = 'Forecast' AND f.Vertical = 'SEB' THEN 1
                    WHEN f.Origem IN ('Resultado', 'Ajustes') AND f.EstFiscal = '1006' THEN 1 -- ID 1006 = Sede Adm
                    ELSE 0 
                END
            WHEN cc.Grupo_Logico = 'Presidencia_Complexa' AND f.join_key_cc NOT IN ('30101018', '30401001') THEN
                CASE WHEN f.EstFiscal = '1006' THEN 1 ELSE 0 END
            ELSE 1
        END AS is_content_valid,

        -- VALIDAÇÃO DE QUALIDADE (Usando Flags da MV)
        CASE
            WHEN cc.Grupo_Logico IN ('MBGS_Filter', 'Res_Nao_Op_Filter', 'Presidencia_Complexa', 'Executiva_Core', 'Rateavel') THEN
                 CASE 
                    WHEN f.join_key_cc IN ('30101018', '30401001') AND f.Ebitda = 'Sim' AND f.Recorrente = 'Sim' AND f.Nome_PnL NOT IN ('Rateio SSS', 'Rateio Cross') THEN 1
                    WHEN f.join_key_cc NOT IN ('30101018', '30401001') AND cc.Grupo_Logico = 'Presidencia_Complexa' THEN 1
                    WHEN f.Ebitda = 'Sim' AND f.Recorrente = 'Sim' AND f.Nome_PnL NOT IN ('Rateio SSS', 'Rateio Cross') THEN 1 
                    ELSE 0 
                END
            ELSE 1
        END AS is_quality_valid

    FROM fatos_brutos f
    INNER JOIN dim_diretorias cc
        ON f.join_key_cc = cc.idCentroCustos
),

agregacao_por_diretoria AS (
    SELECT
        Diretoria,
        ROUND(COALESCE(-(SUM(CASE 
            WHEN Origem = 'Forecast' AND Mes_Transacao <= 10 THEN 
                CASE WHEN join_key_cc IN ('30101018', '30401001') THEN 0 ELSE Valor * is_content_valid END
            ELSE 0 
        END) / 1000), 0), 0) AS valor_10m25_f,

        ROUND(COALESCE(-(SUM(CASE
            WHEN Origem IN ('Resultado', 'Ajustes') AND is_content_valid = 1 AND is_quality_valid = 1 AND Mes_Transacao <= 10 THEN Valor
            ELSE 0
        END) / 1000), 0), 0) AS valor_10m25_r,

        ROUND(COALESCE(-(SUM(CASE 
            WHEN Origem = 'Forecast' THEN 
                 CASE WHEN join_key_cc IN ('30101018', '30401001') THEN 0 ELSE Valor * is_content_valid END
            ELSE 0 
        END) / 1000), 0), 0) AS valor_fy25_forecast
    FROM dados_consolidados
    GROUP BY Diretoria
),

-- ==========================================================
-- CÁLCULO ESPECÍFICO DO RATEIO (Sem Joins de PnL/Unidades)
-- ==========================================================
calculo_rateio_especifico AS (
    SELECT
        ROUND(COALESCE(-(SUM(CASE 
            WHEN f.Origem = 'Forecast' AND Mes_Transacao <= 10 THEN f.Valor ELSE 0 
        END) / 1000), 0), 0) AS Rateado_10M_F,

        ROUND(COALESCE(-(SUM(CASE
            WHEN f.Origem IN ('Resultado', 'Ajustes') AND Mes_Transacao <= 10 THEN f.Valor ELSE 0
        END) / 1000), 0), 0) AS Rateado_10M_R,

        ROUND(COALESCE(-(SUM(CASE 
            WHEN f.Origem = 'Forecast' THEN f.Valor ELSE 0 
        END) / 1000), 0), 0) AS Rateado_FY
    FROM fatos_brutos f
    WHERE 
        -- Conta 'Rateio Corporativo' E Unidade diferente de 1006 (Sede)
        (f.Nome_PnL = 'Rateio Corporativo' AND f.EstFiscal <> '1006')
        OR
        -- Conta 'Aluguel / IPTU' E Vertical = CNX
        (f.Nome_PnL = 'Aluguel / IPTU' AND f.Vertical = 'CNX')
),

-- ==========================================================
-- CONSOLIDAÇÃO DOS TOTAIS
-- ==========================================================
totais_finais AS (
    SELECT
        -- Total Rateável (Corporativo + Board)
        SUM(CASE WHEN Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços', 'Auditoria') THEN valor_10m25_f ELSE 0 END) as TotalRateavel_F,
        SUM(CASE WHEN Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços', 'Auditoria') THEN valor_10m25_r ELSE 0 END) as TotalRateavel_R,
        SUM(CASE WHEN Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços', 'Auditoria') THEN valor_fy25_forecast ELSE 0 END) as TotalRateavel_FY,

        -- Total Não Rateável (Presidência + Executiva + Outros Soltos)
        SUM(CASE WHEN Diretoria IN ('Eventos Estratégicos', 'Planejamento Estratégico', 'Return on Learning', 'Presidência', 'Diretoria Executiva') THEN valor_10m25_f ELSE 0 END) as TotalNaoRateavel_F,
        SUM(CASE WHEN Diretoria IN ('Eventos Estratégicos', 'Planejamento Estratégico', 'Return on Learning', 'Presidência', 'Diretoria Executiva') THEN valor_10m25_r ELSE 0 END) as TotalNaoRateavel_R,
        SUM(CASE WHEN Diretoria IN ('Eventos Estratégicos', 'Planejamento Estratégico', 'Return on Learning', 'Presidência', 'Diretoria Executiva') THEN valor_fy25_forecast ELSE 0 END) as TotalNaoRateavel_FY,

        -- Total Não Orçados (MBGS + Res Nao Op)
        SUM(CASE WHEN Diretoria IN ('MBGS', 'Resultado Não Operacional') THEN valor_10m25_f ELSE 0 END) as TotalNaoOrcado_F,
        SUM(CASE WHEN Diretoria IN ('MBGS', 'Resultado Não Operacional') THEN valor_10m25_r ELSE 0 END) as TotalNaoOrcado_R,
        SUM(CASE WHEN Diretoria IN ('MBGS', 'Resultado Não Operacional') THEN valor_fy25_forecast ELSE 0 END) as TotalNaoOrcado_FY,

        -- E40: Valor Rateado
        (SELECT Rateado_10M_F FROM calculo_rateio_especifico) as CorpRateado_F,
        (SELECT Rateado_10M_R FROM calculo_rateio_especifico) as CorpRateado_R,
        (SELECT Rateado_FY FROM calculo_rateio_especifico) as CorpRateado_FY

    FROM agregacao_por_diretoria
)

-- ==========================================================
-- SELECTS FINAIS (TABELA SUPERIOR + INFERIOR)
-- ==========================================================

-- 1. Linhas Individuais (Detalhe das Diretorias)
SELECT
    Diretoria,
    valor_10m25_f AS `10M'25|F`,
    valor_10m25_r AS `10M'25|R`,
    (valor_10m25_r - valor_10m25_f) AS `Var|25 x Fcst`,
    ROUND(((valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(valor_10m25_f, 0), 1) AS `Var Pct|25 x Fcst`,
    valor_fy25_forecast AS `FY'25|Forecast`
FROM agregacao_por_diretoria
 
UNION ALL
 
-- 2. Subtotal "Diretorias Corporativas"
SELECT
    'Diretorias Corporativas',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria
WHERE Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços')
 
UNION ALL

-- 3. Subtotal "Total Board"
SELECT
    'Total Board',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria
WHERE Diretoria = 'Auditoria'

UNION ALL

-- 4. Total Rateável (E17)
SELECT
    'Total Rateável',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria
WHERE Diretoria IN ('Diretoria de Gente e Gestão', 'Diretoria Financeira', 'Diretoria de Digital', 'Diretoria de Serviços', 'Auditoria')

UNION ALL

-- 5. Total Não Rateável
SELECT
    'Total Não Rateável',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria
WHERE Diretoria IN ('Eventos Estratégicos', 'Planejamento Estratégico', 'Return on Learning', 'Presidência', 'Diretoria Executiva')

UNION ALL

-- 6. Total Não Orçados
SELECT
    'Total Não Orçados',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria
WHERE Diretoria IN ('MBGS', 'Resultado Não Operacional')

UNION ALL

-- 7. Total Geral
SELECT
    'Total',
    SUM(valor_10m25_f), SUM(valor_10m25_r),
    SUM(valor_10m25_r - valor_10m25_f),
    ROUND((SUM(valor_10m25_r - valor_10m25_f) * 100.0) / NULLIF(SUM(valor_10m25_f), 0), 1),
    SUM(valor_fy25_forecast)
FROM agregacao_por_diretoria

UNION ALL

-- ==========================================================
-- QUADRO INFERIOR (RESUMO GERENCIAL)
-- ==========================================================

-- 8. Cabeçalho Quadro Inferior (Total Estrat + Pres + Corp)
SELECT 
    'Total Estrat + Pres + Corp',
    (TotalRateavel_F + TotalNaoRateavel_F),
    (TotalRateavel_R + TotalNaoRateavel_R),
    ((TotalRateavel_R + TotalNaoRateavel_R) - (TotalRateavel_F + TotalNaoRateavel_F)),
    ROUND((((TotalRateavel_R + TotalNaoRateavel_R) - (TotalRateavel_F + TotalNaoRateavel_F)) * 100.0) / NULLIF((TotalRateavel_F + TotalNaoRateavel_F), 0), 1),
    (TotalRateavel_FY + TotalNaoRateavel_FY)
FROM totais_finais

UNION ALL

-- 9. Corp - Rateado para os negócios (E40)
SELECT 
    'Corp - Rateado para os negócios',
    CorpRateado_F, CorpRateado_R,
    (CorpRateado_R - CorpRateado_F),
    ROUND(((CorpRateado_R - CorpRateado_F) * 100.0) / NULLIF(CorpRateado_F, 0), 1),
    CorpRateado_FY
FROM totais_finais

UNION ALL

-- 10. Corp - Parcela não rateada (Matemática: E17 - E40)
SELECT 
    'Corp - Parcela não rateada',
    (TotalRateavel_F - CorpRateado_F),
    (TotalRateavel_R - CorpRateado_R),
    ((TotalRateavel_R - CorpRateado_R) - (TotalRateavel_F - CorpRateado_F)),
    ROUND((((TotalRateavel_R - CorpRateado_R) - (TotalRateavel_F - CorpRateado_F)) * 100.0) / NULLIF((TotalRateavel_F - CorpRateado_F), 0), 1),
    (TotalRateavel_FY - CorpRateado_FY)
FROM totais_finais

UNION ALL

-- 11. Estratégico + Presidência (Total Não Rateável + Não Orçados no Realizado)
SELECT 
    'Estratégico + Presidência',
    TotalNaoRateavel_F, -- Forecast mantém o original
    (TotalNaoRateavel_R + TotalNaoOrcado_R), -- Realizado Soma os dois (F25 + F30)
    ((TotalNaoRateavel_R + TotalNaoOrcado_R) - TotalNaoRateavel_F), -- Var recalculada
    ROUND((((TotalNaoRateavel_R + TotalNaoOrcado_R) - TotalNaoRateavel_F) * 100.0) / NULLIF(TotalNaoRateavel_F, 0), 1),
    TotalNaoRateavel_FY -- FY Mantém o original
FROM totais_finais

UNION ALL

-- 12. Total Não Orçado
SELECT 
    'Total Não Orçado',
    TotalNaoOrcado_F, TotalNaoOrcado_R,
    (TotalNaoOrcado_R - TotalNaoOrcado_F),
    ROUND(((TotalNaoOrcado_R - TotalNaoOrcado_F) * 100.0) / NULLIF(TotalNaoOrcado_F, 0), 1),
    TotalNaoOrcado_FY
FROM totais_finais

UNION ALL

-- 13. Saldo remanescente (Soma de tudo no final)
SELECT 
    'Saldo remanescente',
    (TotalRateavel_F + TotalNaoRateavel_F + TotalNaoOrcado_F),
    (TotalRateavel_R + TotalNaoRateavel_R + TotalNaoOrcado_R),
    ((TotalRateavel_R + TotalNaoRateavel_R + TotalNaoOrcado_R) - (TotalRateavel_F + TotalNaoRateavel_F + TotalNaoOrcado_F)),
    ROUND((((TotalRateavel_R + TotalNaoRateavel_R + TotalNaoOrcado_R) - (TotalRateavel_F + TotalNaoRateavel_F + TotalNaoOrcado_F)) * 100.0) / NULLIF((TotalRateavel_F + TotalNaoRateavel_F + TotalNaoOrcado_F), 0), 1),
    (TotalRateavel_FY + TotalNaoRateavel_FY + TotalNaoOrcado_FY)
FROM totais_finais

ORDER BY
    CASE
        WHEN Diretoria = 'Diretoria de Gente e Gestão' THEN 1
        WHEN Diretoria = 'Diretoria Financeira' THEN 2
        WHEN Diretoria = 'Diretoria de Digital' THEN 3
        WHEN Diretoria = 'Diretoria de Serviços' THEN 4
        WHEN Diretoria = 'Diretorias Corporativas' THEN 5
        WHEN Diretoria = 'Auditoria' THEN 6
        WHEN Diretoria = 'Total Board' THEN 7
        WHEN Diretoria = 'Total Rateável' THEN 8
        WHEN Diretoria = 'Eventos Estratégicos' THEN 9
        WHEN Diretoria = 'Planejamento Estratégico' THEN 10
        WHEN Diretoria = 'Return on Learning' THEN 11
        WHEN Diretoria = 'Presidência' THEN 12
        WHEN Diretoria = 'Diretoria Executiva' THEN 13
        WHEN Diretoria = 'Total Não Rateável' THEN 14
        WHEN Diretoria = 'MBGS' THEN 15
        WHEN Diretoria = 'Resultado Não Operacional' THEN 16
        WHEN Diretoria = 'Total Não Orçados' THEN 17
        WHEN Diretoria = 'Total' THEN 18
        -- Quadro Inferior
        WHEN Diretoria = 'Total Estrat + Pres + Corp' THEN 19
        WHEN Diretoria = 'Corp - Rateado para os negócios' THEN 20
        WHEN Diretoria = 'Corp - Parcela não rateada' THEN 21
        WHEN Diretoria = 'Estratégico + Presidência' THEN 22
        WHEN Diretoria = 'Total Não Orçado' THEN 23
        WHEN Diretoria = 'Saldo remanescente' THEN 24
        ELSE 99
    END