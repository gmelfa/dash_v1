-- @id: premium_lucro_liquido_ytd_consolidado
-- @name: Premium - Lucro Líquido YTD - Consolidado
-- @category: Premium
-- @order: 19

WITH params AS (
    SELECT
        :ano_selecionado     AS ano_atual,
        :ano_anterior        AS ano_anterior,
        :mes_selecionado     AS mes_ytd,
        'Premium'            AS vertical
),

base AS (
    SELECT
        f.Origem,
        YEAR(f.Data_Transacao)   AS ano,
        f.Ebitda,
        f.Recorrente,
        f.ROL                   AS rol_flag,
        f.Nome_PnL,
        f.Valor,
        p.ano_atual,
        p.ano_anterior,
        p.mes_ytd
    FROM financeiro.prd.mv_f_apresentacao f
    CROSS JOIN params p
    WHERE f.Vertical = p.vertical
      AND YEAR(f.Data_Transacao)  IN (p.ano_atual, p.ano_anterior)
      AND MONTH(f.Data_Transacao) BETWEEN 1 AND p.mes_ytd
      AND f.Nome_Unidade NOT LIKE '%CSC Local%'
      AND f.Nome_Unidade NOT LIKE '%Diretoria%'
      AND f.Nome_Unidade <> 'Pueri Domus Ipiranga'
),

-- Todos os componentes individuais do EBITDA (igual query 08) + itens abaixo do EBITDA
numeros_raw AS (
    SELECT
        MAX(mes_ytd) AS mes_ytd,

        -- ROL
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS rol_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS rol_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS rol_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS rol_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS rol_26r,

        -- CMV
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END)/1000 AS cmv_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END)/1000 AS cmv_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END)/1000 AS cmv_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END)/1000 AS cmv_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END)/1000 AS cmv_26r,

        -- FOPAG Direto
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_dir_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_dir_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_dir_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_dir_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_dir_26r,

        -- Eventos SEB
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END)/1000 AS ev_seb_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END)/1000 AS ev_seb_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END)/1000 AS ev_seb_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END)/1000 AS ev_seb_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END)/1000 AS ev_seb_26r,

        -- Outros Custos Diretos
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END)/1000 AS outros_cust_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END)/1000 AS outros_cust_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END)/1000 AS outros_cust_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END)/1000 AS outros_cust_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END)/1000 AS outros_cust_26r,

        -- Folha de Pagamento (fixos)
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END)/1000 AS fopag_26r,

        -- Benefícios
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END)/1000 AS benef_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END)/1000 AS benef_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END)/1000 AS benef_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END)/1000 AS benef_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END)/1000 AS benef_26r,

        -- Cursos e Treinamentos
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END)/1000 AS cursos_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END)/1000 AS cursos_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END)/1000 AS cursos_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END)/1000 AS cursos_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END)/1000 AS cursos_26r,

        -- Segurança e Limpeza
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END)/1000 AS limp_seg_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END)/1000 AS limp_seg_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END)/1000 AS limp_seg_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END)/1000 AS limp_seg_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END)/1000 AS limp_seg_26r,

        -- Consultorias e Honorários
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END)/1000 AS consult_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END)/1000 AS consult_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END)/1000 AS consult_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END)/1000 AS consult_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END)/1000 AS consult_26r,

        -- Aluguel / IPTU
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END)/1000 AS aluguel_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END)/1000 AS aluguel_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END)/1000 AS aluguel_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END)/1000 AS aluguel_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END)/1000 AS aluguel_26r,

        -- Conservação e Manutenção
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END)/1000 AS manut_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END)/1000 AS manut_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END)/1000 AS manut_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END)/1000 AS manut_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END)/1000 AS manut_26r,

        -- Tecnologia
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END)/1000 AS tecnol_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END)/1000 AS tecnol_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END)/1000 AS tecnol_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END)/1000 AS tecnol_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END)/1000 AS tecnol_26r,

        -- Energia Elétrica e Água e Esgoto
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END)/1000 AS energia_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END)/1000 AS energia_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END)/1000 AS energia_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END)/1000 AS energia_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END)/1000 AS energia_26r,

        -- Despesas com Viagens
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END)/1000 AS viagens_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END)/1000 AS viagens_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END)/1000 AS viagens_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END)/1000 AS viagens_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END)/1000 AS viagens_26r,

        -- CSC Local
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END)/1000 AS csc_local_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END)/1000 AS csc_local_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END)/1000 AS csc_local_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END)/1000 AS csc_local_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END)/1000 AS csc_local_26r,

        -- Corporativo BU
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END)/1000 AS corp_bu_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END)/1000 AS corp_bu_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END)/1000 AS corp_bu_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END)/1000 AS corp_bu_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END)/1000 AS corp_bu_26r,

        -- Rateio Corporativo
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END)/1000 AS rat_corp_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END)/1000 AS rat_corp_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END)/1000 AS rat_corp_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END)/1000 AS rat_corp_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END)/1000 AS rat_corp_26r,

        -- Demais custos, desp e taxas
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas') THEN Valor*-1 ELSE 0 END)/1000 AS dem_total_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas') THEN Valor*-1 ELSE 0 END)/1000 AS dem_total_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas') THEN Valor*-1 ELSE 0 END)/1000 AS dem_total_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas') THEN Valor*-1 ELSE 0 END)/1000 AS dem_total_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas') THEN Valor*-1 ELSE 0 END)/1000 AS dem_total_26r,

        -- Marketing
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END)/1000 AS mkt_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END)/1000 AS mkt_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END)/1000 AS mkt_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END)/1000 AS mkt_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END)/1000 AS mkt_26r,

        -- PCLD
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END)/1000 AS pcld_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END)/1000 AS pcld_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END)/1000 AS pcld_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END)/1000 AS pcld_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END)/1000 AS pcld_26r,

        -- Despesas Bancárias
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END)/1000 AS desp_banc_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END)/1000 AS desp_banc_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END)/1000 AS desp_banc_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END)/1000 AS desp_banc_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END)/1000 AS desp_banc_26r,

        -- Despesas com Isenção
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END)/1000 AS isen_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END)/1000 AS isen_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END)/1000 AS isen_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END)/1000 AS isen_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END)/1000 AS isen_26r,

        -- Descontos Comerciais
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END)/1000 AS desc_com_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END)/1000 AS desc_com_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END)/1000 AS desc_com_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END)/1000 AS desc_com_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END)/1000 AS desc_com_26r,

        -- Provisão para Contigências
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Provisão para Contigências' THEN Valor*-1 ELSE 0 END)/1000 AS prov_cont_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Provisão para Contigências' THEN Valor*-1 ELSE 0 END)/1000 AS prov_cont_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Provisão para Contigências' THEN Valor*-1 ELSE 0 END)/1000 AS prov_cont_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Provisão para Contigências' THEN Valor*-1 ELSE 0 END)/1000 AS prov_cont_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Provisão para Contigências' THEN Valor*-1 ELSE 0 END)/1000 AS prov_cont_26r,

        -- Despesas Indedutiveis
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Despesas Indedutiveis' THEN Valor*-1 ELSE 0 END)/1000 AS desp_indedu_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Despesas Indedutiveis' THEN Valor*-1 ELSE 0 END)/1000 AS desp_indedu_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Despesas Indedutiveis' THEN Valor*-1 ELSE 0 END)/1000 AS desp_indedu_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Despesas Indedutiveis' THEN Valor*-1 ELSE 0 END)/1000 AS desp_indedu_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Despesas Indedutiveis' THEN Valor*-1 ELSE 0 END)/1000 AS desp_indedu_26r,

        -- Ganhos/Perdas - Equivalência
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL IN (
                'Perdas Partic. Result. Colig. e Control. pelo método de Equiv.',
                'Ganhos e perdas na alienação de investimentos',
                'Ganhos e Perdas Coligadas e Controladas'
            ) THEN Valor*-1 ELSE 0 END)/1000 AS ganhos_perdas_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL IN (
                'Perdas Partic. Result. Colig. e Control. pelo método de Equiv.',
                'Ganhos e perdas na alienação de investimentos',
                'Ganhos e Perdas Coligadas e Controladas'
            ) THEN Valor*-1 ELSE 0 END)/1000 AS ganhos_perdas_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL IN (
                'Perdas Partic. Result. Colig. e Control. pelo método de Equiv.',
                'Ganhos e perdas na alienação de investimentos',
                'Ganhos e Perdas Coligadas e Controladas'
            ) THEN Valor*-1 ELSE 0 END)/1000 AS ganhos_perdas_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL IN (
                'Perdas Partic. Result. Colig. e Control. pelo método de Equiv.',
                'Ganhos e perdas na alienação de investimentos',
                'Ganhos e Perdas Coligadas e Controladas'
            ) THEN Valor*-1 ELSE 0 END)/1000 AS ganhos_perdas_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL IN (
                'Perdas Partic. Result. Colig. e Control. pelo método de Equiv.',
                'Ganhos e perdas na alienação de investimentos',
                'Ganhos e Perdas Coligadas e Controladas'
            ) THEN Valor*-1 ELSE 0 END)/1000 AS ganhos_perdas_26r,

        -- Contratos Arrendamento IFRS16
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Contratos Arrendamento IFRS16' THEN Valor*-1 ELSE 0 END)/1000 AS ifrs16_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Contratos Arrendamento IFRS16' THEN Valor*-1 ELSE 0 END)/1000 AS ifrs16_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Contratos Arrendamento IFRS16' THEN Valor*-1 ELSE 0 END)/1000 AS ifrs16_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Contratos Arrendamento IFRS16' THEN Valor*-1 ELSE 0 END)/1000 AS ifrs16_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Contratos Arrendamento IFRS16' THEN Valor*-1 ELSE 0 END)/1000 AS ifrs16_26r,

        -- Depreciação/Amortização
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Depreciação/Amortização' THEN Valor*-1 ELSE 0 END)/1000 AS depr_amor_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Depreciação/Amortização' THEN Valor*-1 ELSE 0 END)/1000 AS depr_amor_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Depreciação/Amortização' THEN Valor*-1 ELSE 0 END)/1000 AS depr_amor_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Depreciação/Amortização' THEN Valor*-1 ELSE 0 END)/1000 AS depr_amor_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Depreciação/Amortização' THEN Valor*-1 ELSE 0 END)/1000 AS depr_amor_26r,

        -- Receita/(Despesa) financeira líquida
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Receita/(Despesa) financeira líquida' THEN Valor*-1 ELSE 0 END)/1000 AS rec_desp_fin_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Receita/(Despesa) financeira líquida' THEN Valor*-1 ELSE 0 END)/1000 AS rec_desp_fin_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Receita/(Despesa) financeira líquida' THEN Valor*-1 ELSE 0 END)/1000 AS rec_desp_fin_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Receita/(Despesa) financeira líquida' THEN Valor*-1 ELSE 0 END)/1000 AS rec_desp_fin_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Receita/(Despesa) financeira líquida' THEN Valor*-1 ELSE 0 END)/1000 AS rec_desp_fin_26r,

        -- IR / CSLL
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='IR / CSLL  - (Rec.)/Desp.' THEN Valor*-1 ELSE 0 END)/1000 AS ircsll_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='IR / CSLL  - (Rec.)/Desp.' THEN Valor*-1 ELSE 0 END)/1000 AS ircsll_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='IR / CSLL  - (Rec.)/Desp.' THEN Valor*-1 ELSE 0 END)/1000 AS ircsll_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='IR / CSLL  - (Rec.)/Desp.' THEN Valor*-1 ELSE 0 END)/1000 AS ircsll_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='IR / CSLL  - (Rec.)/Desp.' THEN Valor*-1 ELSE 0 END)/1000 AS ircsll_26r,

        -- Outros result.em investimentos avaliados pela equivalência (oculto)
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Outros result.em investimentos avaliados pela equivalência' THEN Valor*-1 ELSE 0 END)/1000 AS outros_equiv_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Nome_PnL='Outros result.em investimentos avaliados pela equivalência' THEN Valor*-1 ELSE 0 END)/1000 AS outros_equiv_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Nome_PnL='Outros result.em investimentos avaliados pela equivalência' THEN Valor*-1 ELSE 0 END)/1000 AS outros_equiv_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Ajustes'                AND Nome_PnL='Outros result.em investimentos avaliados pela equivalência' THEN Valor*-1 ELSE 0 END)/1000 AS outros_equiv_26r_adj,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Nome_PnL='Outros result.em investimentos avaliados pela equivalência' THEN Valor*-1 ELSE 0 END)/1000 AS outros_equiv_26r,

        -- EBITDA direto (mesmo cálculo da query 08 — soma direta com Ebitda='Sim' e Recorrente='Sim')
        SUM(CASE WHEN ano=ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS ebitda_dir_25r,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS ebitda_dir_26f,
        SUM(CASE WHEN ano=ano_atual    AND Origem = 'Resultado'              AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS ebitda_dir_26r_res,
        SUM(CASE WHEN ano=ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END)/1000 AS ebitda_dir_26r

    FROM base
),

-- Subtotais do EBITDA com pré-arredondamento por componente (igual query 08)
numeros AS (
    SELECT
        *,

        -- (=) Margem de Contribuição = ROL + CMV + Custos Diretos
        ROUND(rol_25r,0)+ROUND(cmv_25r,0)+ROUND(fopag_dir_25r,0)+ROUND(ev_seb_25r,0)+ROUND(outros_cust_25r,0) AS mc_25r,
        ROUND(rol_26f,0)+ROUND(cmv_26f,0)+ROUND(fopag_dir_26f,0)+ROUND(ev_seb_26f,0)+ROUND(outros_cust_26f,0) AS mc_26f,
        ROUND(rol_26r_res,0)+ROUND(cmv_26r_res,0)+ROUND(fopag_dir_26r_res,0)+ROUND(ev_seb_26r_res,0)+ROUND(outros_cust_26r_res,0) AS mc_26r_res,
        (ROUND(rol_26r,0)+ROUND(cmv_26r,0)+ROUND(fopag_dir_26r,0)+ROUND(ev_seb_26r,0)+ROUND(outros_cust_26r,0))-(ROUND(rol_26r_res,0)+ROUND(cmv_26r_res,0)+ROUND(fopag_dir_26r_res,0)+ROUND(ev_seb_26r_res,0)+ROUND(outros_cust_26r_res,0)) AS mc_26r_adj,
        rol_26r+cmv_26r+fopag_dir_26r+ev_seb_26r+outros_cust_26r AS mc_26r,

        -- (=) Total Custos e Desp Fixas
        ROUND(fopag_25r,0)+ROUND(benef_25r,0)+ROUND(cursos_25r,0)+ROUND(limp_seg_25r,0)+ROUND(consult_25r,0)+ROUND(aluguel_25r,0)+ROUND(manut_25r,0)+ROUND(tecnol_25r,0)+ROUND(energia_25r,0)+ROUND(viagens_25r,0)+ROUND(csc_local_25r,0)+ROUND(corp_bu_25r,0)+ROUND(rat_corp_25r,0)+ROUND(dem_total_25r,0) AS tc_fixo_25r,
        ROUND(fopag_26f,0)+ROUND(benef_26f,0)+ROUND(cursos_26f,0)+ROUND(limp_seg_26f,0)+ROUND(consult_26f,0)+ROUND(aluguel_26f,0)+ROUND(manut_26f,0)+ROUND(tecnol_26f,0)+ROUND(energia_26f,0)+ROUND(viagens_26f,0)+ROUND(csc_local_26f,0)+ROUND(corp_bu_26f,0)+ROUND(rat_corp_26f,0)+ROUND(dem_total_26f,0) AS tc_fixo_26f,
        ROUND(fopag_26r_res,0)+ROUND(benef_26r_res,0)+ROUND(cursos_26r_res,0)+ROUND(limp_seg_26r_res,0)+ROUND(consult_26r_res,0)+ROUND(aluguel_26r_res,0)+ROUND(manut_26r_res,0)+ROUND(tecnol_26r_res,0)+ROUND(energia_26r_res,0)+ROUND(viagens_26r_res,0)+ROUND(csc_local_26r_res,0)+ROUND(corp_bu_26r_res,0)+ROUND(rat_corp_26r_res,0)+ROUND(dem_total_26r_res,0) AS tc_fixo_26r_res,
        (fopag_26r+benef_26r+cursos_26r+limp_seg_26r+consult_26r+aluguel_26r+manut_26r+tecnol_26r+energia_26r+viagens_26r+csc_local_26r+corp_bu_26r+rat_corp_26r+dem_total_26r)-(ROUND(fopag_26r_res,0)+ROUND(benef_26r_res,0)+ROUND(cursos_26r_res,0)+ROUND(limp_seg_26r_res,0)+ROUND(consult_26r_res,0)+ROUND(aluguel_26r_res,0)+ROUND(manut_26r_res,0)+ROUND(tecnol_26r_res,0)+ROUND(energia_26r_res,0)+ROUND(viagens_26r_res,0)+ROUND(csc_local_26r_res,0)+ROUND(corp_bu_26r_res,0)+ROUND(rat_corp_26r_res,0)+ROUND(dem_total_26r_res,0)) AS tc_fixo_26r_adj,
        fopag_26r+benef_26r+cursos_26r+limp_seg_26r+consult_26r+aluguel_26r+manut_26r+tecnol_26r+energia_26r+viagens_26r+csc_local_26r+corp_bu_26r+rat_corp_26r+dem_total_26r AS tc_fixo_26r,

        -- (=) Total Desp Vendas
        ROUND(mkt_25r,0)+ROUND(pcld_25r,0)+ROUND(desp_banc_25r,0)+ROUND(isen_25r,0)+ROUND(desc_com_25r,0) AS td_vendas_25r,
        ROUND(mkt_26f,0)+ROUND(pcld_26f,0)+ROUND(desp_banc_26f,0)+ROUND(isen_26f,0)+ROUND(desc_com_26f,0) AS td_vendas_26f,
        ROUND(mkt_26r_res,0)+ROUND(pcld_26r_res,0)+ROUND(desp_banc_26r_res,0)+ROUND(isen_26r_res,0)+ROUND(desc_com_26r_res,0) AS td_vendas_26r_res,
        (mkt_26r+pcld_26r+desp_banc_26r+isen_26r+desc_com_26r)-(ROUND(mkt_26r_res,0)+ROUND(pcld_26r_res,0)+ROUND(desp_banc_26r_res,0)+ROUND(isen_26r_res,0)+ROUND(desc_com_26r_res,0)) AS td_vendas_26r_adj,
        mkt_26r+pcld_26r+desp_banc_26r+isen_26r+desc_com_26r AS td_vendas_26r,

        ebitda_dir_26r - ebitda_dir_26r_res AS ebitda_dir_26r_adj

    FROM numeros_raw
),

-- EBITDA e todos os subtotais downstream
finais AS (
    SELECT
        *,

        -- (=) EBITDA — soma direta igual query 08 (captura ajustes não mapeados por Nome_PnL)
        ebitda_dir_25r AS ebitda_25r,
        ebitda_dir_26f AS ebitda_26f,
        ebitda_dir_26r_res AS ebitda_26r_res,
        ebitda_dir_26r_adj AS ebitda_26r_adj,
        ebitda_dir_26r AS ebitda_26r,

        -- (=) EBITDA Contábil
        ebitda_dir_25r + prov_cont_25r+desp_indedu_25r+ganhos_perdas_25r+ifrs16_25r AS ebitda_cont_25r,
        ebitda_dir_26f + prov_cont_26f+desp_indedu_26f+ganhos_perdas_26f+ifrs16_26f AS ebitda_cont_26f,
        ebitda_dir_26r_res + prov_cont_26r_res+desp_indedu_26r_res+ganhos_perdas_26r_res+ifrs16_26r_res AS ebitda_cont_26r_res,
        ebitda_dir_26r_adj + prov_cont_26r_adj+desp_indedu_26r_adj+ganhos_perdas_26r_adj+ifrs16_26r_adj AS ebitda_cont_26r_adj,
        ebitda_dir_26r + prov_cont_26r+desp_indedu_26r+ganhos_perdas_26r+ifrs16_26r AS ebitda_cont_26r,

        -- (=) EBIT
        ebitda_dir_25r + prov_cont_25r+desp_indedu_25r+ganhos_perdas_25r+ifrs16_25r + depr_amor_25r AS ebit_25r,
        ebitda_dir_26f + prov_cont_26f+desp_indedu_26f+ganhos_perdas_26f+ifrs16_26f + depr_amor_26f AS ebit_26f,
        ebitda_dir_26r_res + prov_cont_26r_res+desp_indedu_26r_res+ganhos_perdas_26r_res+ifrs16_26r_res + depr_amor_26r_res AS ebit_26r_res,
        ebitda_dir_26r_adj + prov_cont_26r_adj+desp_indedu_26r_adj+ganhos_perdas_26r_adj+ifrs16_26r_adj + depr_amor_26r_adj AS ebit_26r_adj,
        ebitda_dir_26r + prov_cont_26r+desp_indedu_26r+ganhos_perdas_26r+ifrs16_26r + depr_amor_26r AS ebit_26r,

        -- (=) LAIR
        ebitda_dir_25r + prov_cont_25r+desp_indedu_25r+ganhos_perdas_25r+ifrs16_25r + depr_amor_25r + rec_desp_fin_25r AS lair_25r,
        ebitda_dir_26f + prov_cont_26f+desp_indedu_26f+ganhos_perdas_26f+ifrs16_26f + depr_amor_26f + rec_desp_fin_26f AS lair_26f,
        ebitda_dir_26r_res + prov_cont_26r_res+desp_indedu_26r_res+ganhos_perdas_26r_res+ifrs16_26r_res + depr_amor_26r_res + rec_desp_fin_26r_res AS lair_26r_res,
        ebitda_dir_26r_adj + prov_cont_26r_adj+desp_indedu_26r_adj+ganhos_perdas_26r_adj+ifrs16_26r_adj + depr_amor_26r_adj + rec_desp_fin_26r_adj AS lair_26r_adj,
        ebitda_dir_26r + prov_cont_26r+desp_indedu_26r+ganhos_perdas_26r+ifrs16_26r + depr_amor_26r + rec_desp_fin_26r AS lair_26r,

        -- (=) Lucro Líquido
        ebitda_dir_25r + prov_cont_25r+desp_indedu_25r+ganhos_perdas_25r+ifrs16_25r + depr_amor_25r + rec_desp_fin_25r + ircsll_25r AS lucro_liq_25r,
        ebitda_dir_26f + prov_cont_26f+desp_indedu_26f+ganhos_perdas_26f+ifrs16_26f + depr_amor_26f + rec_desp_fin_26f + ircsll_26f AS lucro_liq_26f,
        ebitda_dir_26r_res + prov_cont_26r_res+desp_indedu_26r_res+ganhos_perdas_26r_res+ifrs16_26r_res + depr_amor_26r_res + rec_desp_fin_26r_res + ircsll_26r_res AS lucro_liq_26r_res,
        ebitda_dir_26r_adj + prov_cont_26r_adj+desp_indedu_26r_adj+ganhos_perdas_26r_adj+ifrs16_26r_adj + depr_amor_26r_adj + rec_desp_fin_26r_adj + ircsll_26r_adj AS lucro_liq_26r_adj,
        ebitda_dir_26r + prov_cont_26r+desp_indedu_26r+ganhos_perdas_26r+ifrs16_26r + depr_amor_26r + rec_desp_fin_26r + ircsll_26r AS lucro_liq_26r,

        -- (=) Lucro Líquido Conciliado
        ebitda_dir_25r + prov_cont_25r+desp_indedu_25r+ganhos_perdas_25r+ifrs16_25r + depr_amor_25r + rec_desp_fin_25r + ircsll_25r + outros_equiv_25r AS lucro_liq_conc_25r,
        ebitda_dir_26f + prov_cont_26f+desp_indedu_26f+ganhos_perdas_26f+ifrs16_26f + depr_amor_26f + rec_desp_fin_26f + ircsll_26f + outros_equiv_26f AS lucro_liq_conc_26f,
        ebitda_dir_26r_res + prov_cont_26r_res+desp_indedu_26r_res+ganhos_perdas_26r_res+ifrs16_26r_res + depr_amor_26r_res + rec_desp_fin_26r_res + ircsll_26r_res + outros_equiv_26r_res AS lucro_liq_conc_26r_res,
        ebitda_dir_26r_adj + prov_cont_26r_adj+desp_indedu_26r_adj+ganhos_perdas_26r_adj+ifrs16_26r_adj + depr_amor_26r_adj + rec_desp_fin_26r_adj + ircsll_26r_adj + outros_equiv_26r_adj AS lucro_liq_conc_26r_adj,
        ebitda_dir_26r + prov_cont_26r+desp_indedu_26r+ganhos_perdas_26r+ifrs16_26r + depr_amor_26r + rec_desp_fin_26r + ircsll_26r + outros_equiv_26r AS lucro_liq_conc_26r

    FROM numeros
)

SELECT '(=) EBITDA' AS Descricao,
    ROUND(ebitda_25r, 0) AS `3M 25 R`,
    ROUND(CASE WHEN rol_25r<>0 THEN ebitda_25r/rol_25r*100 ELSE NULL END, 1) AS `% ROL`,
    ROUND(ebitda_26f, 0) AS `3M 26 F`,
    ROUND(CASE WHEN rol_26f<>0 THEN ebitda_26f/rol_26f*100 ELSE NULL END, 1) AS `% ROL_F`,
    ROUND(ebitda_26r, 0) AS `3M 26 R`,
    ROUND(CASE WHEN rol_26r<>0 THEN ebitda_26r/rol_26r*100 ELSE NULL END, 1) AS `% ROL_R`,
    ROUND(ebitda_26r-ebitda_26f, 0) AS `Var # 26 x Fcst`,
    ROUND(CASE WHEN ebitda_26f<>0 THEN (ebitda_26r-ebitda_26f)/ABS(ebitda_26f)*100 ELSE NULL END, 1) AS `Var % 26 x Fcst`,
    ROUND(ebitda_26r-ebitda_25r, 0) AS `Var # 26 x 25`,
    ROUND(CASE WHEN ebitda_25r<>0 THEN (ebitda_26r-ebitda_25r)/ABS(ebitda_25r)*100 ELSE NULL END, 1) AS `Var % 26 x 25`,
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ebitda_26r/rol_26r*100)-(ebitda_26f/rol_26f*100) ELSE NULL END, 1) AS `Var % p.p.`,
    1 AS sort_order
FROM finais

UNION ALL

SELECT 'Provisão para Contigências',
    ROUND(prov_cont_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN prov_cont_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(prov_cont_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN prov_cont_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(prov_cont_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN prov_cont_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(prov_cont_26r-prov_cont_26f,0),
    ROUND(CASE WHEN prov_cont_26f<>0 THEN (prov_cont_26r-prov_cont_26f)/ABS(prov_cont_26f)*100 ELSE NULL END,1),
    ROUND(prov_cont_26r-prov_cont_25r,0),
    ROUND(CASE WHEN prov_cont_25r<>0 THEN (prov_cont_26r-prov_cont_25r)/ABS(prov_cont_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (prov_cont_26r/rol_26r*100)-(prov_cont_26f/rol_26f*100) ELSE NULL END,1),
    2
FROM finais

UNION ALL

SELECT 'Despesas Indedutiveis',
    ROUND(desp_indedu_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN desp_indedu_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(desp_indedu_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN desp_indedu_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(desp_indedu_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN desp_indedu_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(desp_indedu_26r-desp_indedu_26f,0),
    ROUND(CASE WHEN desp_indedu_26f<>0 THEN (desp_indedu_26r-desp_indedu_26f)/ABS(desp_indedu_26f)*100 ELSE NULL END,1),
    ROUND(desp_indedu_26r-desp_indedu_25r,0),
    ROUND(CASE WHEN desp_indedu_25r<>0 THEN (desp_indedu_26r-desp_indedu_25r)/ABS(desp_indedu_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (desp_indedu_26r/rol_26r*100)-(desp_indedu_26f/rol_26f*100) ELSE NULL END,1),
    3
FROM finais

UNION ALL

SELECT 'Ganhos/Perdas - Equivalência',
    ROUND(ganhos_perdas_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN ganhos_perdas_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(ganhos_perdas_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN ganhos_perdas_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(ganhos_perdas_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN ganhos_perdas_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(ganhos_perdas_26r-ganhos_perdas_26f,0),
    ROUND(CASE WHEN ganhos_perdas_26f<>0 THEN (ganhos_perdas_26r-ganhos_perdas_26f)/ABS(ganhos_perdas_26f)*100 ELSE NULL END,1),
    ROUND(ganhos_perdas_26r-ganhos_perdas_25r,0),
    ROUND(CASE WHEN ganhos_perdas_25r<>0 THEN (ganhos_perdas_26r-ganhos_perdas_25r)/ABS(ganhos_perdas_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ganhos_perdas_26r/rol_26r*100)-(ganhos_perdas_26f/rol_26f*100) ELSE NULL END,1),
    4
FROM finais

UNION ALL

SELECT 'Contratos Arrendamento IFRS16',
    ROUND(ifrs16_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN ifrs16_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(ifrs16_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN ifrs16_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(ifrs16_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN ifrs16_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(ifrs16_26r-ifrs16_26f,0),
    ROUND(CASE WHEN ifrs16_26f<>0 THEN (ifrs16_26r-ifrs16_26f)/ABS(ifrs16_26f)*100 ELSE NULL END,1),
    ROUND(ifrs16_26r-ifrs16_25r,0),
    ROUND(CASE WHEN ifrs16_25r<>0 THEN (ifrs16_26r-ifrs16_25r)/ABS(ifrs16_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ifrs16_26r/rol_26r*100)-(ifrs16_26f/rol_26f*100) ELSE NULL END,1),
    5
FROM finais

UNION ALL

SELECT '(=) EBITDA Contábil',
    ROUND(ebitda_cont_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN ebitda_cont_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(ebitda_cont_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN ebitda_cont_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(ebitda_cont_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN ebitda_cont_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(ebitda_cont_26r-ebitda_cont_26f,0),
    ROUND(CASE WHEN ebitda_cont_26f<>0 THEN (ebitda_cont_26r-ebitda_cont_26f)/ABS(ebitda_cont_26f)*100 ELSE NULL END,1),
    ROUND(ebitda_cont_26r-ebitda_cont_25r,0),
    ROUND(CASE WHEN ebitda_cont_25r<>0 THEN (ebitda_cont_26r-ebitda_cont_25r)/ABS(ebitda_cont_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ebitda_cont_26r/rol_26r*100)-(ebitda_cont_26f/rol_26f*100) ELSE NULL END,1),
    6
FROM finais

UNION ALL

SELECT 'Depreciação/Amortização',
    ROUND(depr_amor_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN depr_amor_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(depr_amor_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN depr_amor_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(depr_amor_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN depr_amor_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(depr_amor_26r-depr_amor_26f,0),
    ROUND(CASE WHEN depr_amor_26f<>0 THEN (depr_amor_26r-depr_amor_26f)/ABS(depr_amor_26f)*100 ELSE NULL END,1),
    ROUND(depr_amor_26r-depr_amor_25r,0),
    ROUND(CASE WHEN depr_amor_25r<>0 THEN (depr_amor_26r-depr_amor_25r)/ABS(depr_amor_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (depr_amor_26r/rol_26r*100)-(depr_amor_26f/rol_26f*100) ELSE NULL END,1),
    7
FROM finais

UNION ALL

SELECT '(=) EBIT',
    ROUND(ebit_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN ebit_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(ebit_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN ebit_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(ebit_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN ebit_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(ebit_26r-ebit_26f,0),
    ROUND(CASE WHEN ebit_26f<>0 THEN (ebit_26r-ebit_26f)/ABS(ebit_26f)*100 ELSE NULL END,1),
    ROUND(ebit_26r-ebit_25r,0),
    ROUND(CASE WHEN ebit_25r<>0 THEN (ebit_26r-ebit_25r)/ABS(ebit_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ebit_26r/rol_26r*100)-(ebit_26f/rol_26f*100) ELSE NULL END,1),
    8
FROM finais

UNION ALL

SELECT 'Receita/(Despesa) financeira líquida',
    ROUND(rec_desp_fin_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN rec_desp_fin_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(rec_desp_fin_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN rec_desp_fin_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(rec_desp_fin_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN rec_desp_fin_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(rec_desp_fin_26r-rec_desp_fin_26f,0),
    ROUND(CASE WHEN rec_desp_fin_26f<>0 THEN (rec_desp_fin_26r-rec_desp_fin_26f)/ABS(rec_desp_fin_26f)*100 ELSE NULL END,1),
    ROUND(rec_desp_fin_26r-rec_desp_fin_25r,0),
    ROUND(CASE WHEN rec_desp_fin_25r<>0 THEN (rec_desp_fin_26r-rec_desp_fin_25r)/ABS(rec_desp_fin_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (rec_desp_fin_26r/rol_26r*100)-(rec_desp_fin_26f/rol_26f*100) ELSE NULL END,1),
    9
FROM finais

UNION ALL

SELECT '(=) LAIR',
    ROUND(lair_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN lair_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(lair_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN lair_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(lair_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN lair_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(lair_26r-lair_26f,0),
    ROUND(CASE WHEN lair_26f<>0 THEN (lair_26r-lair_26f)/ABS(lair_26f)*100 ELSE NULL END,1),
    ROUND(lair_26r-lair_25r,0),
    ROUND(CASE WHEN lair_25r<>0 THEN (lair_26r-lair_25r)/ABS(lair_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (lair_26r/rol_26r*100)-(lair_26f/rol_26f*100) ELSE NULL END,1),
    10
FROM finais

UNION ALL

SELECT 'IR / CSLL - (Rec.)/Desp.',
    ROUND(ircsll_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN ircsll_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(ircsll_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN ircsll_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(ircsll_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN ircsll_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(ircsll_26r-ircsll_26f,0),
    ROUND(CASE WHEN ircsll_26f<>0 THEN (ircsll_26r-ircsll_26f)/ABS(ircsll_26f)*100 ELSE NULL END,1),
    ROUND(ircsll_26r-ircsll_25r,0),
    ROUND(CASE WHEN ircsll_25r<>0 THEN (ircsll_26r-ircsll_25r)/ABS(ircsll_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (ircsll_26r/rol_26r*100)-(ircsll_26f/rol_26f*100) ELSE NULL END,1),
    11
FROM finais

UNION ALL

SELECT '(=) Lucro Líquido',
    ROUND(lucro_liq_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN lucro_liq_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(lucro_liq_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN lucro_liq_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(lucro_liq_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN lucro_liq_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(lucro_liq_26r-lucro_liq_26f,0),
    ROUND(CASE WHEN lucro_liq_26f<>0 THEN (lucro_liq_26r-lucro_liq_26f)/ABS(lucro_liq_26f)*100 ELSE NULL END,1),
    ROUND(lucro_liq_26r-lucro_liq_25r,0),
    ROUND(CASE WHEN lucro_liq_25r<>0 THEN (lucro_liq_26r-lucro_liq_25r)/ABS(lucro_liq_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (lucro_liq_26r/rol_26r*100)-(lucro_liq_26f/rol_26f*100) ELSE NULL END,1),
    16
FROM finais

UNION ALL

SELECT '(=) Lucro Líquido Conciliado',
    ROUND(lucro_liq_conc_25r,0), ROUND(CASE WHEN rol_25r<>0 THEN lucro_liq_conc_25r/rol_25r*100 ELSE NULL END,1),
    ROUND(lucro_liq_conc_26f,0), ROUND(CASE WHEN rol_26f<>0 THEN lucro_liq_conc_26f/rol_26f*100 ELSE NULL END,1),
    ROUND(lucro_liq_conc_26r,0),
    ROUND(CASE WHEN rol_26r<>0 THEN lucro_liq_conc_26r/rol_26r*100 ELSE NULL END,1),
    ROUND(lucro_liq_conc_26r-lucro_liq_conc_26f,0),
    ROUND(CASE WHEN lucro_liq_conc_26f<>0 THEN (lucro_liq_conc_26r-lucro_liq_conc_26f)/ABS(lucro_liq_conc_26f)*100 ELSE NULL END,1),
    ROUND(lucro_liq_conc_26r-lucro_liq_conc_25r,0),
    ROUND(CASE WHEN lucro_liq_conc_25r<>0 THEN (lucro_liq_conc_26r-lucro_liq_conc_25r)/ABS(lucro_liq_conc_25r)*100 ELSE NULL END,1),
    ROUND(CASE WHEN rol_26r<>0 AND rol_26f<>0 THEN (lucro_liq_conc_26r/rol_26r*100)-(lucro_liq_conc_26f/rol_26f*100) ELSE NULL END,1),
    18
FROM finais

ORDER BY sort_order
