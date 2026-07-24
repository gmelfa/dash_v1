-- @id: premium_ebitda_variacoes_pueri_domus_verbo
-- @name: Premium - EBITDA Variações por Tema YTD - Pueri Domus Verbo
-- @category: Premium
-- @order: 23
-- @hidden: true

-- Existe só como table_2 do combo 23_principais_metricas_ebitda_variacoes_pueri_domus_verbo.sql
-- (@hidden: true) — mesma lógica de variação 26R-26F por tema da
-- premium_ebitda_variacoes_por_tema_pueri_domus (14), só que filtrada pra
-- uma única unidade (Verbo) e com uma única linha de saída (Total YTD)

with params as (
    select
        :ano_selecionado     as ano_atual,
        :mes_selecionado     as mes_ytd,
        'Premium'            as vertical
),

base as (
    select
        f.Origem,
        f.ROL       as rol_flag,
        f.Nome_PnL,
        f.Valor
    from financeiro.prd.mv_f_apresentacao f
    cross join params p
    where f.Vertical = p.vertical
      and f.idEstFiscal = '1012'
      and f.Nome_Unidade not like '%CSC Local%'
      and f.Nome_Unidade not like '%Diretoria%'
      and year(f.Data_Transacao) = p.ano_atual
      and month(f.Data_Transacao) <= p.mes_ytd
      and f.Origem in ('Forecast', 'Resultado', 'Ajustes')
      and f.Ebitda     = 'Sim'
      and f.Recorrente = 'Sim'
),

metricas as (
    select
        sum(case when Origem = 'Forecast'                then Valor*-1 else 0 end) / 1000 as ebitda_26f,
        sum(case when Origem in ('Resultado','Ajustes')  then Valor*-1 else 0 end) / 1000 as ebitda_26r,

        sum(case when Origem = 'Forecast'                and rol_flag = 1 then Valor*-1 else 0 end) / 1000 as rol_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and rol_flag = 1 then Valor*-1 else 0 end) / 1000 as rol_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL in ('Custo do Material Físico','Custo do Material Dígital','Bonificação') then Valor*-1 else 0 end) / 1000 as cmv_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL in ('Custo do Material Físico','Custo do Material Dígital','Bonificação') then Valor*-1 else 0 end) / 1000 as cmv_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'FOPAG Direto (CLT- PJ)' then Valor*-1 else 0 end) / 1000 as fopagdir_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'FOPAG Direto (CLT- PJ)' then Valor*-1 else 0 end) / 1000 as fopagdir_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Folha de Pagamento' then Valor*-1 else 0 end) / 1000 as fopagind_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Folha de Pagamento' then Valor*-1 else 0 end) / 1000 as fopagind_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Benefícios' then Valor*-1 else 0 end) / 1000 as benef_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Benefícios' then Valor*-1 else 0 end) / 1000 as benef_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Consultorias e Honorários' then Valor*-1 else 0 end) / 1000 as consult_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Consultorias e Honorários' then Valor*-1 else 0 end) / 1000 as consult_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Aluguel / IPTU' then Valor*-1 else 0 end) / 1000 as aluguel_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Aluguel / IPTU' then Valor*-1 else 0 end) / 1000 as aluguel_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Rateio Corporativo' then Valor*-1 else 0 end) / 1000 as rateio_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Rateio Corporativo' then Valor*-1 else 0 end) / 1000 as rateio_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'Despesas com Marketing' then Valor*-1 else 0 end) / 1000 as mkt_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'Despesas com Marketing' then Valor*-1 else 0 end) / 1000 as mkt_26r,

        sum(case when Origem = 'Forecast'                and Nome_PnL = 'PCLD' then Valor*-1 else 0 end) / 1000 as pcld_26f,
        sum(case when Origem in ('Resultado','Ajustes')  and Nome_PnL = 'PCLD' then Valor*-1 else 0 end) / 1000 as pcld_26r
    from base
),

-- variação = Realizado (26R) - Forecast (26F), por tema
variacoes as (
    select
        (ebitda_26r   - ebitda_26f)   as var_ebitda,
        (rol_26r      - rol_26f)      as var_rol,
        (cmv_26r      - cmv_26f)      as var_cmv,
        (fopagdir_26r - fopagdir_26f) as var_fopagdir,
        (fopagind_26r - fopagind_26f) as var_fopagind,
        (benef_26r    - benef_26f)    as var_benef,
        (consult_26r  - consult_26f)  as var_consult,
        (aluguel_26r  - aluguel_26f)  as var_aluguel,
        (rateio_26r   - rateio_26f)   as var_rateio,
        (mkt_26r      - mkt_26f)      as var_mkt,
        (pcld_26r     - pcld_26f)     as var_pcld
    from metricas
),

-- "Outros" é resíduo — garante que a soma das colunas sempre bate com o EBITDA total
calculadas as (
    select
        var_ebitda, var_rol, var_cmv, var_fopagdir, var_fopagind, var_benef, var_consult, var_aluguel, var_rateio, var_mkt, var_pcld,
        var_ebitda - (var_rol + var_cmv + var_fopagdir + var_fopagind + var_benef + var_consult + var_aluguel + var_rateio + var_mkt + var_pcld) as var_outros
    from variacoes
)

-- Linha 1 (texto): nome de cada métrica, repetindo o rótulo já usado no
-- cabeçalho — serve de sub-cabeçalho dentro do corpo da tabela
select
    'UNIDADES'                  as `Variação vs Orçado`,
    'EBITDA'                    as `YTD||EBITDA`,
    'ROL'                       as `YTD||ROL`,
    'Material Didático (CMV)'  as `YTD||Material Didático (CMV)`,
    'Fopag (dir)'                as `YTD||Fopag (dir)`,
    'Fopag (ind)'                as `YTD||Fopag (ind)`,
    'Benefícios'                as `YTD||Benefícios`,
    'Consultorias e Honorários' as `YTD||Consultorias e Honorários`,
    'Aluguel / IPTU'            as `YTD||Aluguel / IPTU`,
    'Rateio Corporativo'        as `YTD||Rateio Corporativo`,
    'Marketing'                  as `YTD||Marketing`,
    'PCLD'                       as `YTD||PCLD`,
    'Outros'                     as `YTD||Outros`,
    1 as sort_order

union all

-- Linha 2 (subtotal): Total YTD — único lugar com os valores numéricos reais
select
    'Total YTD',
    cast(round(var_ebitda, 0) as string),
    cast(round(var_rol, 0) as string),
    cast(round(var_cmv, 0) as string),
    cast(round(var_fopagdir, 0) as string),
    cast(round(var_fopagind, 0) as string),
    cast(round(var_benef, 0) as string),
    cast(round(var_consult, 0) as string),
    cast(round(var_aluguel, 0) as string),
    cast(round(var_rateio, 0) as string),
    cast(round(var_mkt, 0) as string),
    cast(round(var_pcld, 0) as string),
    cast(round(var_outros, 0) as string),
    2 as sort_order
from calculadas

order by sort_order
