-- @id: premium_principais_metricas_ebitda_variacoes_pueri_domus_verbo
-- @name: Premium - Principais Métricas YTD - Pueri Domus Verbo
-- @category: Premium
-- @order: 23
-- @table_1_query_id: Premium/premium_principais_metricas_pueri_domus_verbo
-- @table_1_title: Principais Métricas
-- @table_2_query_id: Premium/premium_ebitda_variacoes_pueri_domus_verbo
-- @table_2_title: EBITDA Variações por Tema

-- Esta query não roda SQL própria — combina os resultados de
-- premium_principais_metricas_pueri_domus_verbo (23a) e
-- premium_ebitda_variacoes_pueri_domus_verbo (23b), ambas @hidden (não
-- aparecem sozinhas no sumário), em uma única página com as duas tabelas
-- empilhadas. Qualquer ajuste de cálculo deve ser feito direto nos
-- arquivos 23a/23b, nunca aqui.
SELECT 1
