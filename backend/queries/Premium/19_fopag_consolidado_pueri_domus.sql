-- @id: premium_fopag_consolidado_pueri_domus
-- @name: Premium - FOPAG Consolidado - Pueri Domus
-- @category: Premium
-- @order: 19
-- @table_1_query_id: Premium/premium_fopag_direta_pueri_domus
-- @table_1_title: Fopag Direta
-- @table_2_query_id: Premium/premium_fopag_indireta_pueri_domus
-- @table_2_title: Fopag Indireta

-- Esta query não roda SQL própria — combina os resultados de
-- premium_fopag_direta_pueri_domus (17) e premium_fopag_indireta_pueri_domus (18),
-- já existentes, em uma única página com as duas tabelas empilhadas (título acima de cada).
-- Ver table_1_query_id/table_2_query_id acima; qualquer ajuste de cálculo
-- deve ser feito direto nos arquivos 17/18, nunca aqui.
SELECT 1
