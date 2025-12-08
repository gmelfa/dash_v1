WITH base_forecast AS (
  SELECT
    cc.Diretoria,
    f.vlrOrcamento_BRL
  FROM financeiro.prd.f_orcamento f
  LEFT JOIN financeiro.prd.d_centrocustosxlsx cc 
    ON f.idCentroCusto = cc.idCentroCustos
  WHERE YEAR(f.Data) = 2025
    AND MONTH(f.Data) BETWEEN 1 AND 10
    AND f.Versao = 'Forecast'
    AND cc.Diretoria IN (
      'Diretoria de Gente e Gestão',
      'Diretoria Financeira',
      'Diretoria de Digital',
      'Diretoria de Serviços'
    )
),

diretorias_forecast AS (
  SELECT
    Diretoria,
    ROUND(-(SUM(vlrOrcamento_BRL) / 1000), 0) AS valor_10m25_f
  FROM base_forecast
  GROUP BY Diretoria
),

diretorias_resultado AS (
  SELECT
    cc.Diretoria,
    SUM(f.Valor_BRL) AS valor_bruto
  FROM financeiro.prd.f_resultado f
  LEFT JOIN financeiro.prd.d_centrocustosxlsx cc 
    ON f.idCentroCusto = cc.idCentroCustos
  LEFT JOIN financeiro.prd.link_PnL 
    ON link_PnL.skclasspnl = f.skclasspnl
  LEFT JOIN financeiro.prd.d_classpnl 
    ON d_classpnl.skPnL = link_PnL.skPnL
  WHERE YEAR(f.Data_Transacao) = 2025
    AND MONTH(f.Data_Transacao) BETWEEN 1 AND 10
    AND f.idEstFiscal = '1006'
    AND link_PnL.Ebitda = 'Sim'
    AND link_PnL.Recorrente = 'Sim'
    AND d_classpnl.Nome <> 'Rateio SSS'
    AND d_classpnl.Nome <> 'Rateio Cross'
    AND cc.Diretoria IN (
      'Diretoria de Gente e Gestão',
      'Diretoria Financeira',
      'Diretoria de Digital',
      'Diretoria de Serviços'
    )
  GROUP BY cc.Diretoria
  
  UNION ALL
  
  SELECT
    cc.Diretoria,
    SUM(f.Valor_BRL) AS valor_bruto
  FROM financeiro.prd.f_ajustes f
  LEFT JOIN financeiro.prd.d_centrocustosxlsx cc 
    ON f.idCentroCusto = cc.idCentroCustos
  LEFT JOIN financeiro.prd.link_PnL 
    ON link_PnL.skclasspnl = f.skclasspnl
  LEFT JOIN financeiro.prd.d_classpnl 
    ON d_classpnl.skPnL = link_PnL.skPnL
  WHERE YEAR(f.Data_Transacao) = 2025
    AND MONTH(f.Data_Transacao) BETWEEN 1 AND 10
    AND f.idEstFiscal = '1006'
    AND link_PnL.Ebitda = 'Sim'
    AND link_PnL.Recorrente = 'Sim'
    AND d_classpnl.Nome <> 'Rateio SSS'
    AND d_classpnl.Nome <> 'Rateio Cross'
    AND cc.Diretoria IN (
      'Diretoria de Gente e Gestão',
      'Diretoria Financeira',
      'Diretoria de Digital',
      'Diretoria de Serviços'
    )
  GROUP BY cc.Diretoria
),

resultado_agregado AS (
  SELECT
    Diretoria,
    ROUND(-(SUM(valor_bruto) / 1000), 0) AS valor_10m25_r
  FROM diretorias_resultado
  GROUP BY Diretoria
),

diretorias_combinadas AS (
  SELECT
    COALESCE(f.Diretoria, r.Diretoria) AS Diretoria,
    COALESCE(f.valor_10m25_f, 0) AS valor_10m25_f,
    COALESCE(r.valor_10m25_r, 0) AS valor_10m25_r
  FROM diretorias_forecast f
  FULL OUTER JOIN resultado_agregado r
    ON f.Diretoria = r.Diretoria
)

SELECT
  Diretoria,
  valor_10m25_f AS `10M'25 F`,
  valor_10m25_r AS `10M'25 R`
FROM diretorias_combinadas

UNION ALL

SELECT
  'Diretorias Corporativas' AS Diretoria,
  ROUND(SUM(valor_10m25_f), 0) AS `10M'25 F`,
  ROUND(SUM(valor_10m25_r), 0) AS `10M'25 R`
FROM diretorias_combinadas

ORDER BY 
  CASE 
    WHEN Diretoria = 'Diretoria de Gente e Gestão' THEN 1
    WHEN Diretoria = 'Diretoria Financeira' THEN 2
    WHEN Diretoria = 'Diretoria de Digital' THEN 3
    WHEN Diretoria = 'Diretoria de Serviços' THEN 4
    WHEN Diretoria = 'Diretorias Corporativas' THEN 5
  END
