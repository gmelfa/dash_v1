-- @id: premium_ebitda_variacoes_por_tema_pueri_domus
-- @name: Premium - EBITDA Variações por Tema YTD - Consolidado
-- @category: Premium
-- @order: 14

with params as (
    select
        :ano_selecionado     as ano_atual,
        :mes_selecionado     as mes_ytd,
        'Premium'            as vertical
),

-- Diretoria Premium - Pueri Domus e Pueri Domus - CSC Local ficam de fora do cálculo
-- por enquanto (saem zeradas na união final) — precisamos investigar a lógica certa
-- pra essas duas linhas antes de calcular
base as (
    select
        f.Nome_Unidade,
        f.Origem,
        f.ROL       as rol_flag,
        f.Nome_PnL,
        f.Valor,
        case
            when f.Nome_Unidade = 'Pueri Domus Aclimação'   then 3
            when f.Nome_Unidade = 'Pueri Domus Itaim'       then 4
            when f.Nome_Unidade = 'Pueri Domus Perdizes'    then 5
            when f.Nome_Unidade = 'Pueri Domus Perdizes II' then 6
            when f.Nome_Unidade = 'Pueri Domus Verbo'       then 7
            else 99
        end as peso_unidade
    from financeiro.prd.mv_f_apresentacao f
    cross join params p
    where f.Vertical = p.vertical
      and f.Grupo = 'Pueri Domus'
      and f.Nome_Unidade not in ('Diretoria Premium - Pueri Domus', 'Pueri Domus - CSC Local')
      and year(f.Data_Transacao) = p.ano_atual
      and month(f.Data_Transacao) <= p.mes_ytd
      and f.idEstFiscal != '1040'
      and f.Origem in ('Forecast', 'Resultado', 'Ajustes')
      and f.Ebitda     = 'Sim'
      and f.Recorrente = 'Sim'
),

metricas as (
    select
        Nome_Unidade,
        peso_unidade,

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
    group by Nome_Unidade, peso_unidade
),

-- variação = Realizado (26R) - Forecast (26F), por tema
variacoes as (
    select
        Nome_Unidade as Descricao,
        peso_unidade,
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

-- "Outros" é resíduo — garante que a soma das colunas sempre bate com o EBITDA total,
-- sem precisar listar manualmente cada linha residual do DRE
calculadas as (
    select
        Descricao, peso_unidade,
        var_ebitda, var_rol, var_cmv, var_fopagdir, var_fopagind, var_benef, var_consult, var_aluguel, var_rateio, var_mkt, var_pcld,
        var_ebitda - (var_rol + var_cmv + var_fopagdir + var_fopagind + var_benef + var_consult + var_aluguel + var_rateio + var_mkt + var_pcld) as var_outros
    from variacoes
),

final as (
    -- Diretoria Premium - Pueri Domus e Pueri Domus - CSC Local: zeradas por enquanto,
    -- sem fórmula (ver comentário no CTE base)
    select
        'Diretoria Premium - Pueri Domus' as Descricao, 1 as peso_unidade,
        0 as var_ebitda, 0 as var_rol, 0 as var_cmv, 0 as var_fopagdir, 0 as var_fopagind,
        0 as var_benef, 0 as var_consult, 0 as var_aluguel, 0 as var_rateio, 0 as var_mkt,
        0 as var_pcld, 0 as var_outros

    union all

    select
        'Pueri Domus - CSC Local' as Descricao, 2 as peso_unidade,
        0 as var_ebitda, 0 as var_rol, 0 as var_cmv, 0 as var_fopagdir, 0 as var_fopagind,
        0 as var_benef, 0 as var_consult, 0 as var_aluguel, 0 as var_rateio, 0 as var_mkt,
        0 as var_pcld, 0 as var_outros

    union all

    select
        Descricao, peso_unidade,
        var_ebitda, var_rol, var_cmv, var_fopagdir, var_fopagind, var_benef, var_consult, var_aluguel, var_rateio, var_mkt, var_pcld, var_outros
    from calculadas

    union all

    select
        'Total YTD', 100,
        sum(var_ebitda), sum(var_rol), sum(var_cmv), sum(var_fopagdir), sum(var_fopagind), sum(var_benef), sum(var_consult), sum(var_aluguel), sum(var_rateio), sum(var_mkt), sum(var_pcld), sum(var_outros)
    from calculadas
)

select
    Descricao                  as `Variação vs Orçado|Unidades`,
    round(var_ebitda, 0)        as `YTD|EBITDA`,
    round(var_rol, 0)           as `YTD|ROL`,
    round(var_cmv, 0)           as `YTD|Material Didático (CMV)`,
    round(var_fopagdir, 0)      as `YTD|Fopag (dir)`,
    round(var_fopagind, 0)      as `YTD|Fopag (ind)`,
    round(var_benef, 0)         as `YTD|Benefícios`,
    round(var_consult, 0)       as `YTD|Consultorias e Honorários`,
    round(var_aluguel, 0)       as `YTD|Aluguel / IPTU`,
    round(var_rateio, 0)        as `YTD|Rateio Corporativo`,
    round(var_mkt, 0)           as `YTD|Marketing`,
    round(var_pcld, 0)          as `YTD|PCLD`,
    round(var_outros, 0)        as `YTD|Outros`
from final
order by peso_unidade
