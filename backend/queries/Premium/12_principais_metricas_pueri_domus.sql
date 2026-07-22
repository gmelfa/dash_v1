-- @id: premium_principais_metricas_pueri_domus
-- @name: Premium - Principais Métricas YTD - Pueri Domus
-- @category: Premium
-- @order: 12

with params as (
    select
        :ano_selecionado     as ano_atual,
        :ano_anterior        as ano_anterior,
        :mes_selecionado     as mes_ytd,
        'Premium'            as vertical
),

base as (
    select
        f.Origem,
        year(f.Data_Transacao)   as ano,
        month(f.Data_Transacao)  as mes,
        f.Ebitda,
        f.Recorrente,
        f.ROL                   as rol_flag,
        f.skclasspnl,
        f.Nome_PnL,
        f.Valor,
        p.ano_atual,
        p.ano_anterior,
        p.mes_ytd
    from financeiro.prd.mv_f_apresentacao f
    cross join params p
    where f.Vertical = p.vertical
      and f.Grupo = 'Pueri Domus'
      and year(f.Data_Transacao)  in (p.ano_atual, p.ano_anterior)
      and month(f.Data_Transacao) between 1 and p.mes_ytd
      and f.Nome_Unidade not like '%CSC Local%'
      and f.Nome_Unidade not like '%Diretoria Premium%'
      and f.idEstFiscal != '1040'
),

-- agrega tudo em uma linha só — cada coluna é um cenário/período
numeros_raw as (
    select
        max(mes_ytd) as mes_ytd,

        -- alunos: snapshot do mês exato (usado quando mes_ytd <= 3)
        sum(case when ano = ano_anterior and mes = mes_ytd and Origem = 'Alunos'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_25r_snap,
        sum(case when ano = ano_atual    and mes = mes_ytd and Origem = 'Budget'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_26b_snap,
        sum(case when ano = ano_atual    and mes = mes_ytd and Origem = 'Forecast' and skclasspnl = '400000000' then Valor else 0 end) as alunos_26f_snap,
        sum(case when ano = ano_atual    and mes = mes_ytd and Origem = 'Alunos'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_26r_snap,

        -- alunos: soma acumulada desde março (usado quando mes_ytd >= 4, dividir por mes_ytd - 2)
        sum(case when ano = ano_anterior and mes >= 3 and Origem = 'Alunos'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_25r_soma,
        sum(case when ano = ano_atual    and mes >= 3 and Origem = 'Budget'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_26b_soma,
        sum(case when ano = ano_atual    and mes >= 3 and Origem = 'Forecast' and skclasspnl = '400000000' then Valor else 0 end) as alunos_26f_soma,
        sum(case when ano = ano_atual    and mes >= 3 and Origem = 'Alunos'   and skclasspnl = '400000000' then Valor else 0 end) as alunos_26r_soma,

        -- receita de ensino em reais brutos, sem /1000 — usada só para calcular o ticket médio
        sum(case when ano = ano_anterior and Origem = 'Resultado' and Ebitda='Sim' and Recorrente='Sim'
                  and Nome_PnL in ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            then Valor*-1 else 0 end) as rec_ensino_25r,
        sum(case when ano = ano_atual    and Origem = 'Budget'    and Ebitda='Sim' and Recorrente='Sim'
                  and Nome_PnL in ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            then Valor*-1 else 0 end) as rec_ensino_26b,
        sum(case when ano = ano_atual    and Origem = 'Forecast'  and Ebitda='Sim' and Recorrente='Sim'
                  and Nome_PnL in ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            then Valor*-1 else 0 end) as rec_ensino_26f,
        sum(case when ano = ano_atual    and Origem = 'Resultado' and Ebitda='Sim' and Recorrente='Sim'
                  and Nome_PnL in ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            then Valor*-1 else 0 end) as rec_ensino_26r,

        -- ROL em R$ mil
        sum(case when ano = ano_anterior and Origem in ('Resultado','Ajustes') and rol_flag=1 and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as rol_25r,
        sum(case when ano = ano_atual    and Origem = 'Budget'                 and rol_flag=1 and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as rol_26b,
        sum(case when ano = ano_atual    and Origem = 'Forecast'               and rol_flag=1 and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as rol_26f,
        sum(case when ano = ano_atual    and Origem in ('Resultado','Ajustes') and rol_flag=1 and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as rol_26r,

        -- EBITDA em R$ mil
        sum(case when ano = ano_anterior and Origem in ('Resultado','Ajustes') and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as ebitda_25r,
        sum(case when ano = ano_atual    and Origem = 'Budget'                 and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as ebitda_26b,
        sum(case when ano = ano_atual    and Origem = 'Forecast'               and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as ebitda_26f,
        sum(case when ano = ano_atual    and Origem in ('Resultado','Ajustes') and Ebitda='Sim' and Recorrente='Sim' then Valor*-1 else 0 end) / 1000 as ebitda_26r

    from base
),

-- aplica regra de alunos: jan-mar = snapshot do mês; abr+ = média acumulada desde março
numeros as (
    select
        mes_ytd,
        case when mes_ytd <= 3 then alunos_25r_snap else alunos_25r_soma / (mes_ytd - 2) end as alunos_25r,
        case when mes_ytd <= 3 then alunos_26b_snap else alunos_26b_soma / (mes_ytd - 2) end as alunos_26b,
        case when mes_ytd <= 3 then alunos_26f_snap else alunos_26f_soma / (mes_ytd - 2) end as alunos_26f,
        case when mes_ytd <= 3 then alunos_26r_snap else alunos_26r_soma / (mes_ytd - 2) end as alunos_26r,
        rec_ensino_25r, rec_ensino_26b, rec_ensino_26f, rec_ensino_26r,
        rol_25r, rol_26b, rol_26f, rol_26r,
        ebitda_25r, ebitda_26b, ebitda_26f, ebitda_26r
    from numeros_raw
)

-- resultado final: cada linha é uma métrica, cada coluna é um período ou variação
select 'Alunos #' as `YTD`,
    round(alunos_25r, 0)                                                                                     as `3M 25 R`,
    round(alunos_26b, 0)                                                                                     as `3M 26 B`,
    round(alunos_26f, 0)                                                                                     as `3M 26 F`,
    round(alunos_26r, 0)                                                                                     as `3M 26 R`,
    round(alunos_26r - alunos_26b, 0)                                                                        as `Var.|26 x Bgt`,
    round(case when alunos_26b > 0 then (alunos_26r - alunos_26b) / alunos_26b * 100 else null end, 1)       as `Var %|26 x Bgt`,
    round(alunos_26r - alunos_26f, 0)                                                                        as `Var #|26 x Fcst`,
    round(case when alunos_26f > 0 then (alunos_26r - alunos_26f) / alunos_26f * 100 else null end, 1)       as `Var %|26 x Fcst`,
    round(alunos_26r - alunos_25r, 0)                                                                        as `Var #|26 x 25`,
    round(case when alunos_25r > 0 then (alunos_26r - alunos_25r) / alunos_25r * 100 else null end, 1)        as `Var %|26 x 25`
from numeros

union all

select 'Ticket Médio (R$ mês)',
    round(rec_ensino_25r / nullif(alunos_25r, 0) / mes_ytd,                                               0),
    round(rec_ensino_26b / nullif(alunos_26b, 0) / mes_ytd,                                               0),
    round(rec_ensino_26f / nullif(alunos_26f, 0) / mes_ytd,                                               0),
    round(rec_ensino_26r / nullif(alunos_26r, 0) / mes_ytd,                                               0),
    round((rec_ensino_26r/nullif(alunos_26r,0) - rec_ensino_26b/nullif(alunos_26b,0)) / mes_ytd,          2),
    round(case when alunos_26b > 0 then ((rec_ensino_26r/alunos_26r) - (rec_ensino_26b/alunos_26b)) / (rec_ensino_26b/alunos_26b) * 100 else null end, 1),
    round((rec_ensino_26r/nullif(alunos_26r,0) - rec_ensino_26f/nullif(alunos_26f,0)) / mes_ytd,          2),
    round(case when alunos_26f > 0 then ((rec_ensino_26r/alunos_26r) - (rec_ensino_26f/alunos_26f)) / (rec_ensino_26f/alunos_26f) * 100 else null end, 1),
    round((rec_ensino_26r/nullif(alunos_26r,0) - rec_ensino_25r/nullif(alunos_25r,0)) / mes_ytd,          0),
    round(case when alunos_25r > 0 then ((rec_ensino_26r/alunos_26r) - (rec_ensino_25r/alunos_25r)) / (rec_ensino_25r/alunos_25r) * 100 else null end, 1)
from numeros

union all

select 'ROL',
    round(rol_25r, 0),
    round(rol_26b, 0),
    round(rol_26f, 0),
    round(rol_26r, 0),
    round(rol_26r - rol_26b,  2),
    round(case when rol_26b <> 0 then (rol_26r - rol_26b) / rol_26b * 100 else null end, 1),
    round(rol_26r - rol_26f,  2),
    round(case when rol_26f <> 0 then (rol_26r - rol_26f) / rol_26f * 100 else null end, 1),
    round(rol_26r - rol_25r,  0),
    round(case when rol_25r <> 0 then (rol_26r - rol_25r) / rol_25r * 100 else null end, 1)
from numeros

union all

select 'EBITDA',
    round(ebitda_25r, 0),
    round(ebitda_26b, 0),
    round(ebitda_26f, 0),
    round(ebitda_26r, 0),
    round(ebitda_26r - ebitda_26b,  2),
    round(case when ebitda_26b <> 0 then (ebitda_26r - ebitda_26b) / ebitda_26b * 100 else null end, 1),
    round(ebitda_26r - ebitda_26f,  2),
    round(case when ebitda_26f <> 0 then (ebitda_26r - ebitda_26f) / ebitda_26f * 100 else null end, 1),
    round(ebitda_26r - ebitda_25r,  0),
    round(case when ebitda_25r <> 0 then (ebitda_26r - ebitda_25r) / ebitda_25r * 100 else null end, 1)
from numeros

union all

select 'Margem %',
    round(case when rol_25r > 0 then ebitda_25r / rol_25r * 100 else null end, 1),
    round(case when rol_26b > 0 then ebitda_26b / rol_26b * 100 else null end, 1),
    round(case when rol_26f > 0 then ebitda_26f / rol_26f * 100 else null end, 1),
    round(case when rol_26r > 0 then ebitda_26r / rol_26r * 100 else null end, 1),
    null, null, null, null, null, null
from numeros
