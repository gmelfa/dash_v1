-- @id: premium_fopag_consolidado
-- @name: Premium - FOPAG Consolidado
-- @category: Premium
-- @order: 08
-- @table_1_query_id: Premium/premium_fopag_direta
-- @table_1_title: Fopag Direta
-- @table_2_query_id: Premium/premium_fopag_indireta
-- @table_2_title: Fopag Indireta

-- Esta query não roda SQL própria — combina os resultados de
-- premium_fopag_direta (05) e premium_fopag_indireta (06), já existentes,
-- em uma única página com as duas tabelas empilhadas (título acima de cada).
-- Ver table_1_query_id/table_2_query_id acima; qualquer ajuste de cálculo
-- deve ser feito direto nos arquivos 05/06, nunca aqui.
SELECT 1
