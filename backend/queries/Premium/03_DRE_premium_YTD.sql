-- @id: premium_dre_ytd
-- @name: Premium - DRE YTD
-- @category: Premium
-- @order: 09

-- ============================================================================
-- DRE PREMIUM YTD
-- Demonstrativo de Resultado do Exercício para a Vertical Premium
-- 3 cenários: 25R (ano anterior real), 26F (forecast), 26R (ano atual real)
-- Valores em R$ mil, exceto Alunos e Ticket Médio
-- ============================================================================

WITH params AS (
    SELECT
        :ano_selecionado     AS ano_atual,
        :ano_anterior        AS ano_anterior,
        :mes_selecionado     AS mes_ytd,
        'Premium'            AS vertical
),

-- Base: dados filtrados da mv_f_apresentacao
-- Exclui apenas CSC Local (conforme fórmulas Excel); inclui Diretoria Premium
base AS (
    SELECT
        f.Origem,
        YEAR(f.Data_Transacao)   AS ano,
        MONTH(f.Data_Transacao)  AS mes,
        f.Ebitda,
        f.Recorrente,
        f.ROL                   AS rol_flag,
        f.skclasspnl,
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

-- Agregação em uma única linha: cada coluna = métrica × cenário
numeros_raw AS (
    SELECT
        MAX(mes_ytd) AS mes_ytd,

        -- ================================================================
        -- ALUNOS (sem filtro Ebitda/Recorrente, usa skclasspnl)
        -- ================================================================
        SUM(CASE WHEN ano = ano_anterior AND mes = mes_ytd AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_25r_snap,
        SUM(CASE WHEN ano = ano_atual    AND mes = mes_ytd AND Origem = 'Forecast' AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_26f_snap,
        SUM(CASE WHEN ano = ano_atual    AND mes = mes_ytd AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_26r_snap,
        SUM(CASE WHEN ano = ano_anterior AND mes >= 3 AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_25r_soma,
        SUM(CASE WHEN ano = ano_atual    AND mes >= 3 AND Origem = 'Forecast' AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_26f_soma,
        SUM(CASE WHEN ano = ano_atual    AND mes >= 3 AND Origem = 'Alunos'   AND skclasspnl = '400000000' THEN Valor ELSE 0 END) AS alu_26r_soma,

        -- ================================================================
        -- RECEITA DE ENSINO (em R$ brutos, para cálculo do ticket)
        -- = Receitas com Ensino Regular + UpSelling + Bolsa de Estudos
        -- ================================================================
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            THEN Valor*-1 ELSE 0 END) AS rec_ensino_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            THEN Valor*-1 ELSE 0 END) AS rec_ensino_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Receitas com Ensino Regular','Receitas com UpSelling','Bolsa de Estudos')
            THEN Valor*-1 ELSE 0 END) AS rec_ensino_26r,

        -- ================================================================
        -- ROL (flag ROL=1) — em R$ mil
        -- ================================================================
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS rol_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS rol_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND rol_flag=1 AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS rol_26r,

        -- ================================================================
        -- EBITDA (flag Ebitda=Sim, Recorrente=Sim) — em R$ mil
        -- ================================================================
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS ebitda_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS ebitda_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' THEN Valor*-1 ELSE 0 END) / 1000 AS ebitda_26r,

        -- ================================================================
        -- RECEITAS INDIVIDUAIS — em R$ mil
        -- ================================================================

        -- Receitas com Ensino Regular
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com Ensino Regular' THEN Valor*-1 ELSE 0 END) / 1000 AS ens_reg_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com Ensino Regular' THEN Valor*-1 ELSE 0 END) / 1000 AS ens_reg_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com Ensino Regular' THEN Valor*-1 ELSE 0 END) / 1000 AS ens_reg_26r,

        -- Receitas com UpSelling
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com UpSelling' THEN Valor*-1 ELSE 0 END) / 1000 AS upsell_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com UpSelling' THEN Valor*-1 ELSE 0 END) / 1000 AS upsell_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receitas com UpSelling' THEN Valor*-1 ELSE 0 END) / 1000 AS upsell_26r,

        -- Bolsa de Estudos
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Estudos' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Estudos' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Estudos' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_26r,

        -- Descontos Método de Assinatura
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Método de Assinatura' THEN Valor*-1 ELSE 0 END) / 1000 AS met_ass_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Método de Assinatura' THEN Valor*-1 ELSE 0 END) / 1000 AS met_ass_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Método de Assinatura' THEN Valor*-1 ELSE 0 END) / 1000 AS met_ass_26r,

        -- Receita com Material Didático
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Material Didático' THEN Valor*-1 ELSE 0 END) / 1000 AS mat_did_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Material Didático' THEN Valor*-1 ELSE 0 END) / 1000 AS mat_did_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Material Didático' THEN Valor*-1 ELSE 0 END) / 1000 AS mat_did_26r,

        -- Receita com Eventos
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Eventos' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_rec_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Eventos' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_rec_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Receita com Eventos' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_rec_26r,

        -- Outras Receitas
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Outras Receitas' THEN Valor*-1 ELSE 0 END) / 1000 AS outras_rec_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Outras Receitas' THEN Valor*-1 ELSE 0 END) / 1000 AS outras_rec_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Outras Receitas' THEN Valor*-1 ELSE 0 END) / 1000 AS outras_rec_26r,

        -- Bolsa de Colaborador
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Colaborador' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_colab_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Colaborador' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_colab_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Bolsa de Colaborador' THEN Valor*-1 ELSE 0 END) / 1000 AS bolsa_colab_26r,

        -- Deduções (impostos sobre receita — ISS, PIS, COFINS, etc.)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Deduções' THEN Valor*-1 ELSE 0 END) / 1000 AS deducoes_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Deduções' THEN Valor*-1 ELSE 0 END) / 1000 AS deducoes_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Deduções' THEN Valor*-1 ELSE 0 END) / 1000 AS deducoes_26r,

        -- ================================================================
        -- CUSTOS DIRETOS — em R$ mil (agregados)
        -- ================================================================

        -- (=) Custo com Mercadoria Vendida (Custo do Material Físico + Custo do Material Digital + Bonificação)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END) / 1000 AS cmv_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END) / 1000 AS cmv_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Custo do Material Físico','Custo do Material Dígital','Bonificação') THEN Valor*-1 ELSE 0 END) / 1000 AS cmv_26r,

        -- FOPAG Direto (CLT-PJ)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_dir_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_dir_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'FOPAG Direto (CLT- PJ)' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_dir_26r,

        -- Eventos SEB (custo)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_seb_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_seb_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Eventos SEB' THEN Valor*-1 ELSE 0 END) / 1000 AS ev_seb_26r,

        -- Outros Custos (Certificações + Refeição + Material Pedagógico — agregado)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END) / 1000 AS outros_cust_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END) / 1000 AS outros_cust_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Certificações','Custos com Alimentação','Materiais Pedagógicos') THEN Valor*-1 ELSE 0 END) / 1000 AS outros_cust_26r,

        -- ================================================================
        -- CUSTOS E DESPESAS FIXAS — em R$ mil
        -- ================================================================

        -- Folha de Pagamento
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Folha de Pagamento' THEN Valor*-1 ELSE 0 END) / 1000 AS fopag_26r,

        -- Benefícios
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END) / 1000 AS benef_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END) / 1000 AS benef_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Benefícios' THEN Valor*-1 ELSE 0 END) / 1000 AS benef_26r,

        -- Cursos e Treinamentos
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END) / 1000 AS cursos_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END) / 1000 AS cursos_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Cursos e Treinamentos' THEN Valor*-1 ELSE 0 END) / 1000 AS cursos_26r,

        -- Segurança e Limpeza (Materiais de Limpeza + Serviços de Limpeza e Segurança)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END) / 1000 AS limp_seg_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END) / 1000 AS limp_seg_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Materiais de Limpeza','Serviços de Limpeza e Segurança') THEN Valor*-1 ELSE 0 END) / 1000 AS limp_seg_26r,

        -- Consultorias e Honorários
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END) / 1000 AS consult_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END) / 1000 AS consult_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Consultorias e Honorários' THEN Valor*-1 ELSE 0 END) / 1000 AS consult_26r,

        -- Aluguel e IPTU
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END) / 1000 AS aluguel_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END) / 1000 AS aluguel_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Aluguel / IPTU' THEN Valor*-1 ELSE 0 END) / 1000 AS aluguel_26r,

        -- Conservação e Manutenção (Conservação Predial + Locação de Maquinas e Equipamentos)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END) / 1000 AS manut_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END) / 1000 AS manut_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL IN ('Conservação Predial e Manutenção Máquinas e Móveis','Locação de Maquinas e Equipamentos') THEN Valor*-1 ELSE 0 END) / 1000 AS manut_26r,

        -- Tecnologia
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END) / 1000 AS tecnol_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END) / 1000 AS tecnol_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Tecnologia (Telefone- Internet- Licença e Serviços de info)' THEN Valor*-1 ELSE 0 END) / 1000 AS tecnol_26r,

        -- Energia Elétrica e Água e Esgoto
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END) / 1000 AS energia_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END) / 1000 AS energia_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Energia Elétrica e Água e Esgoto' THEN Valor*-1 ELSE 0 END) / 1000 AS energia_26r,

        -- Despesas com Viagens
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END) / 1000 AS viagens_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END) / 1000 AS viagens_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Viagens' THEN Valor*-1 ELSE 0 END) / 1000 AS viagens_26r,

        -- CSC Local (custo alocado)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END) / 1000 AS csc_local_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END) / 1000 AS csc_local_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'CSC Local' THEN Valor*-1 ELSE 0 END) / 1000 AS csc_local_26r,

        -- Corporativo BU
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END) / 1000 AS corp_bu_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END) / 1000 AS corp_bu_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Corporativo BU' THEN Valor*-1 ELSE 0 END) / 1000 AS corp_bu_26r,

        -- Rateio Corporativo
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END) / 1000 AS rat_corp_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END) / 1000 AS rat_corp_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Rateio Corporativo' THEN Valor*-1 ELSE 0 END) / 1000 AS rat_corp_26r,

        -- Demais custos, desp e taxas (agregado: Desp Jurídicas + RPA + Mat Escritório + Dem Impostos + Dem Custos)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas')
            THEN Valor*-1 ELSE 0 END) / 1000 AS dem_total_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas')
            THEN Valor*-1 ELSE 0 END) / 1000 AS dem_total_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim'
                  AND Nome_PnL IN ('Despesas Jurídicas','RPA','Materiais de Escritório','Demais Impostos e Taxas','Demais Custos e Despesas')
            THEN Valor*-1 ELSE 0 END) / 1000 AS dem_total_26r,

        -- ================================================================
        -- DESPESAS DE VENDAS — em R$ mil
        -- ================================================================

        -- Despesa com Marketing
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END) / 1000 AS mkt_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END) / 1000 AS mkt_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Marketing' THEN Valor*-1 ELSE 0 END) / 1000 AS mkt_26r,

        -- PCLD
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END) / 1000 AS pcld_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END) / 1000 AS pcld_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'PCLD' THEN Valor*-1 ELSE 0 END) / 1000 AS pcld_26r,

        -- Despesas Bancárias
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END) / 1000 AS desp_banc_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END) / 1000 AS desp_banc_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas Bancárias' THEN Valor*-1 ELSE 0 END) / 1000 AS desp_banc_26r,

        -- Despesas com Isenção
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END) / 1000 AS isen_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END) / 1000 AS isen_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Despesas com Isenção' THEN Valor*-1 ELSE 0 END) / 1000 AS isen_26r,

        -- Descontos Comerciais (agora na seção de vendas)
        SUM(CASE WHEN ano = ano_anterior AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END) / 1000 AS desc_com_25r,
        SUM(CASE WHEN ano = ano_atual    AND Origem = 'Forecast'               AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END) / 1000 AS desc_com_26f,
        SUM(CASE WHEN ano = ano_atual    AND Origem IN ('Resultado','Ajustes') AND Ebitda='Sim' AND Recorrente='Sim' AND Nome_PnL = 'Descontos Comerciais' THEN Valor*-1 ELSE 0 END) / 1000 AS desc_com_26r

    FROM base
),

-- Aplica rolling average em alunos e pré-calcula subtotais
numeros AS (
    SELECT
        mes_ytd,

        -- Alunos com rolling average
        CASE WHEN mes_ytd <= 3 THEN alu_25r_snap ELSE alu_25r_soma / (mes_ytd - 2) END AS alunos_25r,
        CASE WHEN mes_ytd <= 3 THEN alu_26f_snap ELSE alu_26f_soma / (mes_ytd - 2) END AS alunos_26f,
        CASE WHEN mes_ytd <= 3 THEN alu_26r_snap ELSE alu_26r_soma / (mes_ytd - 2) END AS alunos_26r,

        -- Receita de ensino bruta (para ticket médio)
        rec_ensino_25r, rec_ensino_26f, rec_ensino_26r,

        -- ROL e EBITDA
        rol_25r, rol_26f, rol_26r,
        ebitda_25r, ebitda_26f, ebitda_26r,

        -- Receitas individuais
        ens_reg_25r, ens_reg_26f, ens_reg_26r,
        upsell_25r, upsell_26f, upsell_26r,
        bolsa_25r, bolsa_26f, bolsa_26r,
        met_ass_25r, met_ass_26f, met_ass_26r,
        mat_did_25r, mat_did_26f, mat_did_26r,
        ev_rec_25r, ev_rec_26f, ev_rec_26r,
        outras_rec_25r, outras_rec_26f, outras_rec_26r,
        bolsa_colab_25r, bolsa_colab_26f, bolsa_colab_26r,
        deducoes_25r, deducoes_26f, deducoes_26r,

        -- Custos diretos
        cmv_25r, cmv_26f, cmv_26r,
        fopag_dir_25r, fopag_dir_26f, fopag_dir_26r,
        ev_seb_25r, ev_seb_26f, ev_seb_26r,
        outros_cust_25r, outros_cust_26f, outros_cust_26r,

        -- Custos fixos
        fopag_25r, fopag_26f, fopag_26r,
        benef_25r, benef_26f, benef_26r,
        cursos_25r, cursos_26f, cursos_26r,
        limp_seg_25r, limp_seg_26f, limp_seg_26r,
        consult_25r, consult_26f, consult_26r,
        aluguel_25r, aluguel_26f, aluguel_26r,
        manut_25r, manut_26f, manut_26r,
        tecnol_25r, tecnol_26f, tecnol_26r,
        energia_25r, energia_26f, energia_26r,
        viagens_25r, viagens_26f, viagens_26r,
        csc_local_25r, csc_local_26f, csc_local_26r,
        corp_bu_25r, corp_bu_26f, corp_bu_26r,
        rat_corp_25r, rat_corp_26f, rat_corp_26r,
        dem_total_25r, dem_total_26f, dem_total_26r,

        -- Despesas de vendas
        mkt_25r, mkt_26f, mkt_26r,
        pcld_25r, pcld_26f, pcld_26r,
        desp_banc_25r, desp_banc_26f, desp_banc_26r,
        isen_25r, isen_26f, isen_26r,
        desc_com_25r, desc_com_26f, desc_com_26r,

        -- ====== SUBTOTAIS PRÉ-CALCULADOS ======
        -- IMPORTANTE: cada componente é arredondado ANTES de somar,
        -- para replicar o comportamento do Excel (SOMA de valores já exibidos/arredondados)

        -- (=) Receita de Ensino Bruta
        (ROUND(ens_reg_25r, 0) + ROUND(upsell_25r, 0)) AS rec_bruta_25r,
        (ROUND(ens_reg_26f, 0) + ROUND(upsell_26f, 0)) AS rec_bruta_26f,
        (ROUND(ens_reg_26r, 0) + ROUND(upsell_26r, 0)) AS rec_bruta_26r,

        -- (=) Receita de Ensino = Rec Bruta + Bolsa
        (ROUND(ens_reg_25r, 0) + ROUND(upsell_25r, 0) + ROUND(bolsa_25r, 0)) AS rec_ensino_tot_25r,
        (ROUND(ens_reg_26f, 0) + ROUND(upsell_26f, 0) + ROUND(bolsa_26f, 0)) AS rec_ensino_tot_26f,
        (ROUND(ens_reg_26r, 0) + ROUND(upsell_26r, 0) + ROUND(bolsa_26r, 0)) AS rec_ensino_tot_26r,

        -- (=) ROL antes das deduções = Receita de Ensino + linhas individuais (soma bottom-up)
        (ROUND(ens_reg_25r, 0) + ROUND(upsell_25r, 0) + ROUND(bolsa_25r, 0) + ROUND(met_ass_25r, 0) + ROUND(mat_did_25r, 0) + ROUND(ev_rec_25r, 0) + ROUND(outras_rec_25r, 0) + ROUND(bolsa_colab_25r, 0)) AS rol_antes_ded_25r,
        (ROUND(ens_reg_26f, 0) + ROUND(upsell_26f, 0) + ROUND(bolsa_26f, 0) + ROUND(met_ass_26f, 0) + ROUND(mat_did_26f, 0) + ROUND(ev_rec_26f, 0) + ROUND(outras_rec_26f, 0) + ROUND(bolsa_colab_26f, 0)) AS rol_antes_ded_26f,
        (ROUND(ens_reg_26r, 0) + ROUND(upsell_26r, 0) + ROUND(bolsa_26r, 0) + ROUND(met_ass_26r, 0) + ROUND(mat_did_26r, 0) + ROUND(ev_rec_26r, 0) + ROUND(outras_rec_26r, 0) + ROUND(bolsa_colab_26r, 0)) AS rol_antes_ded_26r,

        -- (=) Total Custo Direto = FOPAG Direto + Eventos SEB + Outros Custos
        (ROUND(fopag_dir_25r, 0) + ROUND(ev_seb_25r, 0) + ROUND(outros_cust_25r, 0)) AS tc_dir_25r,
        (ROUND(fopag_dir_26f, 0) + ROUND(ev_seb_26f, 0) + ROUND(outros_cust_26f, 0)) AS tc_dir_26f,
        (ROUND(fopag_dir_26r, 0) + ROUND(ev_seb_26r, 0) + ROUND(outros_cust_26r, 0)) AS tc_dir_26r,

        -- (=) Margem de Contribuição = ROL + CMV + Total Custo Direto
        (ROUND(rol_25r, 0) + ROUND(cmv_25r, 0) + ROUND(fopag_dir_25r, 0) + ROUND(ev_seb_25r, 0) + ROUND(outros_cust_25r, 0)) AS mc_25r,
        (ROUND(rol_26f, 0) + ROUND(cmv_26f, 0) + ROUND(fopag_dir_26f, 0) + ROUND(ev_seb_26f, 0) + ROUND(outros_cust_26f, 0)) AS mc_26f,
        (ROUND(rol_26r, 0) + ROUND(cmv_26r, 0) + ROUND(fopag_dir_26r, 0) + ROUND(ev_seb_26r, 0) + ROUND(outros_cust_26r, 0)) AS mc_26r,

        -- (=) Total Custos e Desp Fixas
        (ROUND(fopag_25r, 0) + ROUND(benef_25r, 0) + ROUND(cursos_25r, 0) + ROUND(limp_seg_25r, 0) + ROUND(consult_25r, 0) + ROUND(aluguel_25r, 0) + ROUND(manut_25r, 0) + ROUND(tecnol_25r, 0) + ROUND(energia_25r, 0) + ROUND(viagens_25r, 0) + ROUND(csc_local_25r, 0) + ROUND(corp_bu_25r, 0) + ROUND(rat_corp_25r, 0) + ROUND(dem_total_25r, 0)) AS tc_fixo_25r,
        (ROUND(fopag_26f, 0) + ROUND(benef_26f, 0) + ROUND(cursos_26f, 0) + ROUND(limp_seg_26f, 0) + ROUND(consult_26f, 0) + ROUND(aluguel_26f, 0) + ROUND(manut_26f, 0) + ROUND(tecnol_26f, 0) + ROUND(energia_26f, 0) + ROUND(viagens_26f, 0) + ROUND(csc_local_26f, 0) + ROUND(corp_bu_26f, 0) + ROUND(rat_corp_26f, 0) + ROUND(dem_total_26f, 0)) AS tc_fixo_26f,
        (ROUND(fopag_26r, 0) + ROUND(benef_26r, 0) + ROUND(cursos_26r, 0) + ROUND(limp_seg_26r, 0) + ROUND(consult_26r, 0) + ROUND(aluguel_26r, 0) + ROUND(manut_26r, 0) + ROUND(tecnol_26r, 0) + ROUND(energia_26r, 0) + ROUND(viagens_26r, 0) + ROUND(csc_local_26r, 0) + ROUND(corp_bu_26r, 0) + ROUND(rat_corp_26r, 0) + ROUND(dem_total_26r, 0)) AS tc_fixo_26r,

        -- Despesas bancárias e isenções (só Bancárias + Isenção; Descontos Comerciais é linha separada)
        (ROUND(desp_banc_25r, 0) + ROUND(isen_25r, 0)) AS banc_isen_25r,
        (ROUND(desp_banc_26f, 0) + ROUND(isen_26f, 0)) AS banc_isen_26f,
        (ROUND(desp_banc_26r, 0) + ROUND(isen_26r, 0)) AS banc_isen_26r,

        -- (=) Total Desp Vendas = Marketing + PCLD + Despesas bancárias e isenções
        (ROUND(mkt_25r, 0) + ROUND(pcld_25r, 0) + ROUND(desp_banc_25r, 0) + ROUND(isen_25r, 0) + ROUND(desc_com_25r, 0)) AS td_vendas_25r,
        (ROUND(mkt_26f, 0) + ROUND(pcld_26f, 0) + ROUND(desp_banc_26f, 0) + ROUND(isen_26f, 0) + ROUND(desc_com_26f, 0)) AS td_vendas_26f,
        (ROUND(mkt_26r, 0) + ROUND(pcld_26r, 0) + ROUND(desp_banc_26r, 0) + ROUND(isen_26r, 0) + ROUND(desc_com_26r, 0)) AS td_vendas_26r

    FROM numeros_raw
)

-- ============================================================================
-- RESULTADO FINAL: cada SELECT = uma linha do DRE
-- ============================================================================

-- 1. Alunos
SELECT 'Alunos' AS Descricao,
    ROUND(alunos_25r, 0)  AS `3M 25 R`,  NULL AS `% ROL`,
    ROUND(alunos_26f, 0)  AS `3M 26 F`,  NULL AS `% ROL_F`,
    ROUND(alunos_26r, 0)  AS `3M 26 R`,  NULL AS `% ROL_R`,
    ROUND(alunos_26r - alunos_26f, 0) AS `Var # 26 x Fcst`,
    ROUND(CASE WHEN alunos_26f <> 0 THEN (alunos_26r - alunos_26f) / ABS(alunos_26f) * 100 ELSE NULL END, 1) AS `Var % 26 x Fcst`,
    ROUND(alunos_26r - alunos_25r, 0) AS `Var # 26 x 25`,
    ROUND(CASE WHEN alunos_25r <> 0 THEN (alunos_26r - alunos_25r) / ABS(alunos_25r) * 100 ELSE NULL END, 1) AS `Var % 26 x 25`,
    NULL AS `Var % p.p.`,
    1 AS sort_order
FROM numeros

UNION ALL

-- 2. Ticket Médio (R$ mês)
SELECT 'Ticket Médio (R$ mês)',
    ROUND(rec_ensino_25r / NULLIF(alunos_25r, 0) / mes_ytd, 0),  NULL,
    ROUND(rec_ensino_26f / NULLIF(alunos_26f, 0) / mes_ytd, 0),  NULL,
    ROUND(rec_ensino_26r / NULLIF(alunos_26r, 0) / mes_ytd, 0),  NULL,
    ROUND((rec_ensino_26r/NULLIF(alunos_26r,0) - rec_ensino_26f/NULLIF(alunos_26f,0)) / mes_ytd, 0),
    ROUND(CASE WHEN alunos_26f > 0 AND rec_ensino_26f <> 0
        THEN ((rec_ensino_26r/alunos_26r) / (rec_ensino_26f/alunos_26f) - 1) * 100 ELSE NULL END, 1),
    ROUND((rec_ensino_26r/NULLIF(alunos_26r,0) - rec_ensino_25r/NULLIF(alunos_25r,0)) / mes_ytd, 0),
    ROUND(CASE WHEN alunos_25r > 0 AND rec_ensino_25r <> 0
        THEN ((rec_ensino_26r/alunos_26r) / (rec_ensino_25r/alunos_25r) - 1) * 100 ELSE NULL END, 1),
    NULL,
    2
FROM numeros

UNION ALL

-- 3. Receitas com Ensino Regular
SELECT 'Receitas com Ensino Regular',
    ROUND(ens_reg_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN ens_reg_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(ens_reg_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN ens_reg_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(ens_reg_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN ens_reg_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(ens_reg_26r - ens_reg_26f, 0),
    ROUND(CASE WHEN ens_reg_26f <> 0 THEN (ens_reg_26r - ens_reg_26f) / ABS(ens_reg_26f) * 100 ELSE NULL END, 1),
    ROUND(ens_reg_26r - ens_reg_25r, 0),
    ROUND(CASE WHEN ens_reg_25r <> 0 THEN (ens_reg_26r - ens_reg_25r) / ABS(ens_reg_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (ens_reg_26r/rol_26r*100) - (ens_reg_26f/rol_26f*100) ELSE NULL END, 1),
    3
FROM numeros

UNION ALL

-- 4. Receitas com UpSelling
SELECT 'Receitas com UpSelling',
    ROUND(upsell_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN upsell_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(upsell_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN upsell_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(upsell_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN upsell_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(upsell_26r - upsell_26f, 0),
    ROUND(CASE WHEN upsell_26f <> 0 THEN (upsell_26r - upsell_26f) / ABS(upsell_26f) * 100 ELSE NULL END, 1),
    ROUND(upsell_26r - upsell_25r, 0),
    ROUND(CASE WHEN upsell_25r <> 0 THEN (upsell_26r - upsell_25r) / ABS(upsell_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (upsell_26r/rol_26r*100) - (upsell_26f/rol_26f*100) ELSE NULL END, 1),
    4
FROM numeros

UNION ALL

-- 5. (=) Receita de Ensino Bruta
SELECT '(=) Receita de Ensino Bruta',
    ROUND(rec_bruta_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN rec_bruta_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(rec_bruta_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN rec_bruta_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(rec_bruta_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN rec_bruta_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(rec_bruta_26r - rec_bruta_26f, 0),
    ROUND(CASE WHEN rec_bruta_26f <> 0 THEN (rec_bruta_26r - rec_bruta_26f) / ABS(rec_bruta_26f) * 100 ELSE NULL END, 1),
    ROUND(rec_bruta_26r - rec_bruta_25r, 0),
    ROUND(CASE WHEN rec_bruta_25r <> 0 THEN (rec_bruta_26r - rec_bruta_25r) / ABS(rec_bruta_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (rec_bruta_26r/rol_26r*100) - (rec_bruta_26f/rol_26f*100) ELSE NULL END, 1),
    5
FROM numeros

UNION ALL

-- 6. Bolsa de Estudos
SELECT 'Bolsa de Estudos',
    ROUND(bolsa_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN bolsa_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(bolsa_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN bolsa_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(bolsa_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN bolsa_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(bolsa_26r - bolsa_26f, 0),
    ROUND(CASE WHEN bolsa_26f <> 0 THEN (bolsa_26r - bolsa_26f) / ABS(bolsa_26f) * 100 ELSE NULL END, 1),
    ROUND(bolsa_26r - bolsa_25r, 0),
    ROUND(CASE WHEN bolsa_25r <> 0 THEN (bolsa_26r - bolsa_25r) / ABS(bolsa_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (bolsa_26r/rol_26r*100) - (bolsa_26f/rol_26f*100) ELSE NULL END, 1),
    6
FROM numeros

UNION ALL

-- 7. (=) Receita de Ensino
SELECT '(=) Receita de Ensino',
    ROUND(rec_ensino_tot_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN rec_ensino_tot_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(rec_ensino_tot_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN rec_ensino_tot_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(rec_ensino_tot_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN rec_ensino_tot_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(rec_ensino_tot_26r - rec_ensino_tot_26f, 0),
    ROUND(CASE WHEN rec_ensino_tot_26f <> 0 THEN (rec_ensino_tot_26r - rec_ensino_tot_26f) / ABS(rec_ensino_tot_26f) * 100 ELSE NULL END, 1),
    ROUND(rec_ensino_tot_26r - rec_ensino_tot_25r, 0),
    ROUND(CASE WHEN rec_ensino_tot_25r <> 0 THEN (rec_ensino_tot_26r - rec_ensino_tot_25r) / ABS(rec_ensino_tot_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (rec_ensino_tot_26r/rol_26r*100) - (rec_ensino_tot_26f/rol_26f*100) ELSE NULL END, 1),
    7
FROM numeros

UNION ALL

-- 8. Descontos Método de Assinatura
SELECT 'Descontos Método de Assinatura',
    ROUND(met_ass_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN met_ass_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(met_ass_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN met_ass_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(met_ass_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN met_ass_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(met_ass_26r - met_ass_26f, 0),
    ROUND(CASE WHEN met_ass_26f <> 0 THEN (met_ass_26r - met_ass_26f) / ABS(met_ass_26f) * 100 ELSE NULL END, 1),
    ROUND(met_ass_26r - met_ass_25r, 0),
    ROUND(CASE WHEN met_ass_25r <> 0 THEN (met_ass_26r - met_ass_25r) / ABS(met_ass_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (met_ass_26r/rol_26r*100) - (met_ass_26f/rol_26f*100) ELSE NULL END, 1),
    8
FROM numeros

UNION ALL

-- 9. Receita com Material Didático
SELECT 'Receita com Material Didático',
    ROUND(mat_did_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN mat_did_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(mat_did_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN mat_did_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(mat_did_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN mat_did_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(mat_did_26r - mat_did_26f, 0),
    ROUND(CASE WHEN mat_did_26f <> 0 THEN (mat_did_26r - mat_did_26f) / ABS(mat_did_26f) * 100 ELSE NULL END, 1),
    ROUND(mat_did_26r - mat_did_25r, 0),
    ROUND(CASE WHEN mat_did_25r <> 0 THEN (mat_did_26r - mat_did_25r) / ABS(mat_did_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (mat_did_26r/rol_26r*100) - (mat_did_26f/rol_26f*100) ELSE NULL END, 1),
    9
FROM numeros

UNION ALL

-- 10. Receita com Eventos
SELECT 'Receita com Eventos',
    ROUND(ev_rec_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN ev_rec_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(ev_rec_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN ev_rec_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(ev_rec_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN ev_rec_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(ev_rec_26r - ev_rec_26f, 0),
    ROUND(CASE WHEN ev_rec_26f <> 0 THEN (ev_rec_26r - ev_rec_26f) / ABS(ev_rec_26f) * 100 ELSE NULL END, 1),
    ROUND(ev_rec_26r - ev_rec_25r, 0),
    ROUND(CASE WHEN ev_rec_25r <> 0 THEN (ev_rec_26r - ev_rec_25r) / ABS(ev_rec_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (ev_rec_26r/rol_26r*100) - (ev_rec_26f/rol_26f*100) ELSE NULL END, 1),
    10
FROM numeros

UNION ALL

-- 11. Outras Receitas
SELECT 'Outras Receitas',
    ROUND(outras_rec_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN outras_rec_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(outras_rec_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN outras_rec_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(outras_rec_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN outras_rec_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(outras_rec_26r - outras_rec_26f, 0),
    ROUND(CASE WHEN outras_rec_26f <> 0 THEN (outras_rec_26r - outras_rec_26f) / ABS(outras_rec_26f) * 100 ELSE NULL END, 1),
    ROUND(outras_rec_26r - outras_rec_25r, 0),
    ROUND(CASE WHEN outras_rec_25r <> 0 THEN (outras_rec_26r - outras_rec_25r) / ABS(outras_rec_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (outras_rec_26r/rol_26r*100) - (outras_rec_26f/rol_26f*100) ELSE NULL END, 1),
    11
FROM numeros

UNION ALL

-- 12. Bolsa de Colaborador
SELECT 'Bolsa de Colaborador',
    ROUND(bolsa_colab_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN bolsa_colab_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(bolsa_colab_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN bolsa_colab_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(bolsa_colab_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN bolsa_colab_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(bolsa_colab_26r - bolsa_colab_26f, 0),
    ROUND(CASE WHEN bolsa_colab_26f <> 0 THEN (bolsa_colab_26r - bolsa_colab_26f) / ABS(bolsa_colab_26f) * 100 ELSE NULL END, 1),
    ROUND(bolsa_colab_26r - bolsa_colab_25r, 0),
    ROUND(CASE WHEN bolsa_colab_25r <> 0 THEN (bolsa_colab_26r - bolsa_colab_25r) / ABS(bolsa_colab_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (bolsa_colab_26r/rol_26r*100) - (bolsa_colab_26f/rol_26f*100) ELSE NULL END, 1),
    12
FROM numeros

UNION ALL

-- 13. (=) ROL antes das deduções
SELECT '(=) ROL antes das deduções',
    ROUND(rol_antes_ded_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN rol_antes_ded_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(rol_antes_ded_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN rol_antes_ded_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(rol_antes_ded_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN rol_antes_ded_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(rol_antes_ded_26r - rol_antes_ded_26f, 0),
    ROUND(CASE WHEN rol_antes_ded_26f <> 0 THEN (rol_antes_ded_26r - rol_antes_ded_26f) / ABS(rol_antes_ded_26f) * 100 ELSE NULL END, 1),
    ROUND(rol_antes_ded_26r - rol_antes_ded_25r, 0),
    ROUND(CASE WHEN rol_antes_ded_25r <> 0 THEN (rol_antes_ded_26r - rol_antes_ded_25r) / ABS(rol_antes_ded_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (rol_antes_ded_26r/rol_26r*100) - (rol_antes_ded_26f/rol_26f*100) ELSE NULL END, 1),
    13
FROM numeros

UNION ALL

-- 14. Deduções
SELECT 'Deduções',
    ROUND(deducoes_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN deducoes_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(deducoes_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN deducoes_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(deducoes_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN deducoes_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(deducoes_26r - deducoes_26f, 0),
    ROUND(CASE WHEN deducoes_26f <> 0 THEN (deducoes_26r - deducoes_26f) / ABS(deducoes_26f) * 100 ELSE NULL END, 1),
    ROUND(deducoes_26r - deducoes_25r, 0),
    ROUND(CASE WHEN deducoes_25r <> 0 THEN (deducoes_26r - deducoes_25r) / ABS(deducoes_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (deducoes_26r/rol_26r*100) - (deducoes_26f/rol_26f*100) ELSE NULL END, 1),
    14
FROM numeros

UNION ALL

-- 15. (=) ROL
SELECT '(=) ROL',
    ROUND(rol_25r, 0), 100.0,
    ROUND(rol_26f, 0), 100.0,
    ROUND(rol_26r, 0), 100.0,
    ROUND(rol_26r - rol_26f, 0),
    ROUND(CASE WHEN rol_26f <> 0 THEN (rol_26r - rol_26f) / ABS(rol_26f) * 100 ELSE NULL END, 1),
    ROUND(rol_26r - rol_25r, 0),
    ROUND(CASE WHEN rol_25r <> 0 THEN (rol_26r - rol_25r) / ABS(rol_25r) * 100 ELSE NULL END, 1),
    0.0,
    15
FROM numeros

UNION ALL

-- ==================== CUSTOS DIRETOS ====================

-- 16. (=) Custo com Mercadoria Vendida
SELECT '(=) Custo com Mercadoria Vendida',
    ROUND(cmv_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN cmv_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(cmv_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN cmv_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(cmv_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN cmv_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(cmv_26r - cmv_26f, 0),
    ROUND(CASE WHEN cmv_26f <> 0 THEN (cmv_26r - cmv_26f) / ABS(cmv_26f) * 100 ELSE NULL END, 1),
    ROUND(cmv_26r - cmv_25r, 0),
    ROUND(CASE WHEN cmv_25r <> 0 THEN (cmv_26r - cmv_25r) / ABS(cmv_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (cmv_26r/rol_26r*100) - (cmv_26f/rol_26f*100) ELSE NULL END, 1),
    16
FROM numeros

UNION ALL

-- 17. FOPAG Direto (CLT-PJ)
SELECT 'FOPAG Direto (CLT-PJ)',
    ROUND(fopag_dir_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN fopag_dir_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(fopag_dir_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN fopag_dir_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(fopag_dir_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN fopag_dir_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(fopag_dir_26r - fopag_dir_26f, 0),
    ROUND(CASE WHEN fopag_dir_26f <> 0 THEN (fopag_dir_26r - fopag_dir_26f) / ABS(fopag_dir_26f) * 100 ELSE NULL END, 1),
    ROUND(fopag_dir_26r - fopag_dir_25r, 0),
    ROUND(CASE WHEN fopag_dir_25r <> 0 THEN (fopag_dir_26r - fopag_dir_25r) / ABS(fopag_dir_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (fopag_dir_26r/rol_26r*100) - (fopag_dir_26f/rol_26f*100) ELSE NULL END, 1),
    17
FROM numeros

UNION ALL

-- 18. Eventos SEB
SELECT 'Eventos SEB',
    ROUND(ev_seb_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN ev_seb_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(ev_seb_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN ev_seb_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(ev_seb_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN ev_seb_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(ev_seb_26r - ev_seb_26f, 0),
    ROUND(CASE WHEN ev_seb_26f <> 0 THEN (ev_seb_26r - ev_seb_26f) / ABS(ev_seb_26f) * 100 ELSE NULL END, 1),
    ROUND(ev_seb_26r - ev_seb_25r, 0),
    ROUND(CASE WHEN ev_seb_25r <> 0 THEN (ev_seb_26r - ev_seb_25r) / ABS(ev_seb_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (ev_seb_26r/rol_26r*100) - (ev_seb_26f/rol_26f*100) ELSE NULL END, 1),
    18
FROM numeros

UNION ALL

-- 19. Outros Custos
SELECT 'Outros Custos',
    ROUND(outros_cust_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN outros_cust_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(outros_cust_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN outros_cust_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(outros_cust_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN outros_cust_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(outros_cust_26r - outros_cust_26f, 0),
    ROUND(CASE WHEN outros_cust_26f <> 0 THEN (outros_cust_26r - outros_cust_26f) / ABS(outros_cust_26f) * 100 ELSE NULL END, 1),
    ROUND(outros_cust_26r - outros_cust_25r, 0),
    ROUND(CASE WHEN outros_cust_25r <> 0 THEN (outros_cust_26r - outros_cust_25r) / ABS(outros_cust_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (outros_cust_26r/rol_26r*100) - (outros_cust_26f/rol_26f*100) ELSE NULL END, 1),
    19
FROM numeros

UNION ALL

-- 20. (=) Total Custo Direto
SELECT '(=) Total Custo Direto',
    ROUND(tc_dir_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN tc_dir_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(tc_dir_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN tc_dir_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(tc_dir_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN tc_dir_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(tc_dir_26r - tc_dir_26f, 0),
    ROUND(CASE WHEN tc_dir_26f <> 0 THEN (tc_dir_26r - tc_dir_26f) / ABS(tc_dir_26f) * 100 ELSE NULL END, 1),
    ROUND(tc_dir_26r - tc_dir_25r, 0),
    ROUND(CASE WHEN tc_dir_25r <> 0 THEN (tc_dir_26r - tc_dir_25r) / ABS(tc_dir_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (tc_dir_26r/rol_26r*100) - (tc_dir_26f/rol_26f*100) ELSE NULL END, 1),
    20
FROM numeros

UNION ALL

-- 21. (=) Margem de Contribuição
SELECT '(=) Margem de Contribuição',
    ROUND(mc_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN mc_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(mc_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN mc_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(mc_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN mc_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(mc_26r - mc_26f, 0),
    ROUND(CASE WHEN mc_26f <> 0 THEN (mc_26r - mc_26f) / ABS(mc_26f) * 100 ELSE NULL END, 1),
    ROUND(mc_26r - mc_25r, 0),
    ROUND(CASE WHEN mc_25r <> 0 THEN (mc_26r - mc_25r) / ABS(mc_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (mc_26r/rol_26r*100) - (mc_26f/rol_26f*100) ELSE NULL END, 1),
    21
FROM numeros

UNION ALL

-- ==================== CUSTOS E DESPESAS FIXAS ====================

-- 22. Folha de Pagamento
SELECT 'Folha de Pagamento',
    ROUND(fopag_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN fopag_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(fopag_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN fopag_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(fopag_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN fopag_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(fopag_26r - fopag_26f, 0),
    ROUND(CASE WHEN fopag_26f <> 0 THEN (fopag_26r - fopag_26f) / ABS(fopag_26f) * 100 ELSE NULL END, 1),
    ROUND(fopag_26r - fopag_25r, 0),
    ROUND(CASE WHEN fopag_25r <> 0 THEN (fopag_26r - fopag_25r) / ABS(fopag_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (fopag_26r/rol_26r*100) - (fopag_26f/rol_26f*100) ELSE NULL END, 1),
    22
FROM numeros

UNION ALL

-- 23. Benefícios
SELECT 'Benefícios',
    ROUND(benef_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN benef_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(benef_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN benef_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(benef_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN benef_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(benef_26r - benef_26f, 0),
    ROUND(CASE WHEN benef_26f <> 0 THEN (benef_26r - benef_26f) / ABS(benef_26f) * 100 ELSE NULL END, 1),
    ROUND(benef_26r - benef_25r, 0),
    ROUND(CASE WHEN benef_25r <> 0 THEN (benef_26r - benef_25r) / ABS(benef_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (benef_26r/rol_26r*100) - (benef_26f/rol_26f*100) ELSE NULL END, 1),
    23
FROM numeros

UNION ALL

-- 24. Cursos e Treinamentos
SELECT 'Cursos e Treinamentos',
    ROUND(cursos_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN cursos_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(cursos_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN cursos_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(cursos_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN cursos_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(cursos_26r - cursos_26f, 0),
    ROUND(CASE WHEN cursos_26f <> 0 THEN (cursos_26r - cursos_26f) / ABS(cursos_26f) * 100 ELSE NULL END, 1),
    ROUND(cursos_26r - cursos_25r, 0),
    ROUND(CASE WHEN cursos_25r <> 0 THEN (cursos_26r - cursos_25r) / ABS(cursos_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (cursos_26r/rol_26r*100) - (cursos_26f/rol_26f*100) ELSE NULL END, 1),
    24
FROM numeros

UNION ALL

-- 25. Segurança e Limpeza
SELECT 'Segurança e Limpeza',
    ROUND(limp_seg_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN limp_seg_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(limp_seg_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN limp_seg_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(limp_seg_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN limp_seg_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(limp_seg_26r - limp_seg_26f, 0),
    ROUND(CASE WHEN limp_seg_26f <> 0 THEN (limp_seg_26r - limp_seg_26f) / ABS(limp_seg_26f) * 100 ELSE NULL END, 1),
    ROUND(limp_seg_26r - limp_seg_25r, 0),
    ROUND(CASE WHEN limp_seg_25r <> 0 THEN (limp_seg_26r - limp_seg_25r) / ABS(limp_seg_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (limp_seg_26r/rol_26r*100) - (limp_seg_26f/rol_26f*100) ELSE NULL END, 1),
    25
FROM numeros

UNION ALL

-- 26. Consultorias e Honorários
SELECT 'Consultorias e Honorários',
    ROUND(consult_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN consult_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(consult_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN consult_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(consult_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN consult_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(consult_26r - consult_26f, 0),
    ROUND(CASE WHEN consult_26f <> 0 THEN (consult_26r - consult_26f) / ABS(consult_26f) * 100 ELSE NULL END, 1),
    ROUND(consult_26r - consult_25r, 0),
    ROUND(CASE WHEN consult_25r <> 0 THEN (consult_26r - consult_25r) / ABS(consult_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (consult_26r/rol_26r*100) - (consult_26f/rol_26f*100) ELSE NULL END, 1),
    26
FROM numeros

UNION ALL

-- 27. Aluguel e IPTU
SELECT 'Aluguel e IPTU',
    ROUND(aluguel_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN aluguel_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(aluguel_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN aluguel_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(aluguel_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN aluguel_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(aluguel_26r - aluguel_26f, 0),
    ROUND(CASE WHEN aluguel_26f <> 0 THEN (aluguel_26r - aluguel_26f) / ABS(aluguel_26f) * 100 ELSE NULL END, 1),
    ROUND(aluguel_26r - aluguel_25r, 0),
    ROUND(CASE WHEN aluguel_25r <> 0 THEN (aluguel_26r - aluguel_25r) / ABS(aluguel_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (aluguel_26r/rol_26r*100) - (aluguel_26f/rol_26f*100) ELSE NULL END, 1),
    27
FROM numeros

UNION ALL

-- 28. Conservação e Manutenção
SELECT 'Conservação e Manutenção',
    ROUND(manut_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN manut_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(manut_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN manut_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(manut_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN manut_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(manut_26r - manut_26f, 0),
    ROUND(CASE WHEN manut_26f <> 0 THEN (manut_26r - manut_26f) / ABS(manut_26f) * 100 ELSE NULL END, 1),
    ROUND(manut_26r - manut_25r, 0),
    ROUND(CASE WHEN manut_25r <> 0 THEN (manut_26r - manut_25r) / ABS(manut_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (manut_26r/rol_26r*100) - (manut_26f/rol_26f*100) ELSE NULL END, 1),
    28
FROM numeros

UNION ALL

-- 29. Tecnologia
SELECT 'Tecnologia',
    ROUND(tecnol_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN tecnol_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(tecnol_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN tecnol_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(tecnol_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN tecnol_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(tecnol_26r - tecnol_26f, 0),
    ROUND(CASE WHEN tecnol_26f <> 0 THEN (tecnol_26r - tecnol_26f) / ABS(tecnol_26f) * 100 ELSE NULL END, 1),
    ROUND(tecnol_26r - tecnol_25r, 0),
    ROUND(CASE WHEN tecnol_25r <> 0 THEN (tecnol_26r - tecnol_25r) / ABS(tecnol_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (tecnol_26r/rol_26r*100) - (tecnol_26f/rol_26f*100) ELSE NULL END, 1),
    29
FROM numeros

UNION ALL

-- 30. Energia Elétrica e Água e Esgoto
SELECT 'Energia Elétrica e Água e Esgoto',
    ROUND(energia_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN energia_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(energia_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN energia_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(energia_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN energia_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(energia_26r - energia_26f, 0),
    ROUND(CASE WHEN energia_26f <> 0 THEN (energia_26r - energia_26f) / ABS(energia_26f) * 100 ELSE NULL END, 1),
    ROUND(energia_26r - energia_25r, 0),
    ROUND(CASE WHEN energia_25r <> 0 THEN (energia_26r - energia_25r) / ABS(energia_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (energia_26r/rol_26r*100) - (energia_26f/rol_26f*100) ELSE NULL END, 1),
    30
FROM numeros

UNION ALL

-- 31. Despesas com Viagens
SELECT 'Despesas com Viagens',
    ROUND(viagens_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN viagens_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(viagens_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN viagens_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(viagens_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN viagens_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(viagens_26r - viagens_26f, 0),
    ROUND(CASE WHEN viagens_26f <> 0 THEN (viagens_26r - viagens_26f) / ABS(viagens_26f) * 100 ELSE NULL END, 1),
    ROUND(viagens_26r - viagens_25r, 0),
    ROUND(CASE WHEN viagens_25r <> 0 THEN (viagens_26r - viagens_25r) / ABS(viagens_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (viagens_26r/rol_26r*100) - (viagens_26f/rol_26f*100) ELSE NULL END, 1),
    31
FROM numeros

UNION ALL

-- 32. CSC Local
SELECT 'CSC Local',
    ROUND(csc_local_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN csc_local_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(csc_local_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN csc_local_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(csc_local_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN csc_local_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(csc_local_26r - csc_local_26f, 0),
    ROUND(CASE WHEN csc_local_26f <> 0 THEN (csc_local_26r - csc_local_26f) / ABS(csc_local_26f) * 100 ELSE NULL END, 1),
    ROUND(csc_local_26r - csc_local_25r, 0),
    ROUND(CASE WHEN csc_local_25r <> 0 THEN (csc_local_26r - csc_local_25r) / ABS(csc_local_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (csc_local_26r/rol_26r*100) - (csc_local_26f/rol_26f*100) ELSE NULL END, 1),
    32
FROM numeros

UNION ALL

-- 33. Corporativo BU
SELECT 'Corporativo BU',
    ROUND(corp_bu_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN corp_bu_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(corp_bu_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN corp_bu_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(corp_bu_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN corp_bu_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(corp_bu_26r - corp_bu_26f, 0),
    ROUND(CASE WHEN corp_bu_26f <> 0 THEN (corp_bu_26r - corp_bu_26f) / ABS(corp_bu_26f) * 100 ELSE NULL END, 1),
    ROUND(corp_bu_26r - corp_bu_25r, 0),
    ROUND(CASE WHEN corp_bu_25r <> 0 THEN (corp_bu_26r - corp_bu_25r) / ABS(corp_bu_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (corp_bu_26r/rol_26r*100) - (corp_bu_26f/rol_26f*100) ELSE NULL END, 1),
    33
FROM numeros

UNION ALL

-- 34. Rateio Corporativo
SELECT 'Rateio Corporativo',
    ROUND(rat_corp_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN rat_corp_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(rat_corp_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN rat_corp_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(rat_corp_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN rat_corp_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(rat_corp_26r - rat_corp_26f, 0),
    ROUND(CASE WHEN rat_corp_26f <> 0 THEN (rat_corp_26r - rat_corp_26f) / ABS(rat_corp_26f) * 100 ELSE NULL END, 1),
    ROUND(rat_corp_26r - rat_corp_25r, 0),
    ROUND(CASE WHEN rat_corp_25r <> 0 THEN (rat_corp_26r - rat_corp_25r) / ABS(rat_corp_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (rat_corp_26r/rol_26r*100) - (rat_corp_26f/rol_26f*100) ELSE NULL END, 1),
    34
FROM numeros

UNION ALL

-- 35. Demais custos, desp e taxas
SELECT 'Demais custos, desp e taxas',
    ROUND(dem_total_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN dem_total_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(dem_total_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN dem_total_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(dem_total_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN dem_total_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(dem_total_26r - dem_total_26f, 0),
    ROUND(CASE WHEN dem_total_26f <> 0 THEN (dem_total_26r - dem_total_26f) / ABS(dem_total_26f) * 100 ELSE NULL END, 1),
    ROUND(dem_total_26r - dem_total_25r, 0),
    ROUND(CASE WHEN dem_total_25r <> 0 THEN (dem_total_26r - dem_total_25r) / ABS(dem_total_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (dem_total_26r/rol_26r*100) - (dem_total_26f/rol_26f*100) ELSE NULL END, 1),
    35
FROM numeros

UNION ALL

-- 36. (=) Total Custos Desp Fixas
SELECT '(=) Total Custos Desp Fixas',
    ROUND(tc_fixo_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN tc_fixo_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(tc_fixo_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN tc_fixo_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(tc_fixo_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN tc_fixo_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(tc_fixo_26r - tc_fixo_26f, 0),
    ROUND(CASE WHEN tc_fixo_26f <> 0 THEN (tc_fixo_26r - tc_fixo_26f) / ABS(tc_fixo_26f) * 100 ELSE NULL END, 1),
    ROUND(tc_fixo_26r - tc_fixo_25r, 0),
    ROUND(CASE WHEN tc_fixo_25r <> 0 THEN (tc_fixo_26r - tc_fixo_25r) / ABS(tc_fixo_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (tc_fixo_26r/rol_26r*100) - (tc_fixo_26f/rol_26f*100) ELSE NULL END, 1),
    36
FROM numeros

UNION ALL

-- ==================== DESPESAS DE VENDAS ====================

-- 37. Despesa com Marketing
SELECT 'Despesa com Marketing',
    ROUND(mkt_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN mkt_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(mkt_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN mkt_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(mkt_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN mkt_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(mkt_26r - mkt_26f, 0),
    ROUND(CASE WHEN mkt_26f <> 0 THEN (mkt_26r - mkt_26f) / ABS(mkt_26f) * 100 ELSE NULL END, 1),
    ROUND(mkt_26r - mkt_25r, 0),
    ROUND(CASE WHEN mkt_25r <> 0 THEN (mkt_26r - mkt_25r) / ABS(mkt_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (mkt_26r/rol_26r*100) - (mkt_26f/rol_26f*100) ELSE NULL END, 1),
    37
FROM numeros

UNION ALL

-- 38. PCLD
SELECT 'PCLD',
    ROUND(pcld_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN pcld_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(pcld_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN pcld_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(pcld_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN pcld_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(pcld_26r - pcld_26f, 0),
    ROUND(CASE WHEN pcld_26f <> 0 THEN (pcld_26r - pcld_26f) / ABS(pcld_26f) * 100 ELSE NULL END, 1),
    ROUND(pcld_26r - pcld_25r, 0),
    ROUND(CASE WHEN pcld_25r <> 0 THEN (pcld_26r - pcld_25r) / ABS(pcld_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (pcld_26r/rol_26r*100) - (pcld_26f/rol_26f*100) ELSE NULL END, 1),
    38
FROM numeros

UNION ALL

-- 39. Despesas bancárias e isenções (subtotal)
SELECT 'Despesas bancárias e isenções',
    ROUND(banc_isen_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN banc_isen_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(banc_isen_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN banc_isen_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(banc_isen_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN banc_isen_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(banc_isen_26r - banc_isen_26f, 0),
    ROUND(CASE WHEN banc_isen_26f <> 0 THEN (banc_isen_26r - banc_isen_26f) / ABS(banc_isen_26f) * 100 ELSE NULL END, 1),
    ROUND(banc_isen_26r - banc_isen_25r, 0),
    ROUND(CASE WHEN banc_isen_25r <> 0 THEN (banc_isen_26r - banc_isen_25r) / ABS(banc_isen_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (banc_isen_26r/rol_26r*100) - (banc_isen_26f/rol_26f*100) ELSE NULL END, 1),
    39
FROM numeros

UNION ALL

-- 40. Despesas Bancárias (sub-item)
SELECT '  Despesas Bancárias',
    ROUND(desp_banc_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN desp_banc_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(desp_banc_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN desp_banc_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(desp_banc_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN desp_banc_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(desp_banc_26r - desp_banc_26f, 0),
    ROUND(CASE WHEN desp_banc_26f <> 0 THEN (desp_banc_26r - desp_banc_26f) / ABS(desp_banc_26f) * 100 ELSE NULL END, 1),
    ROUND(desp_banc_26r - desp_banc_25r, 0),
    ROUND(CASE WHEN desp_banc_25r <> 0 THEN (desp_banc_26r - desp_banc_25r) / ABS(desp_banc_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (desp_banc_26r/rol_26r*100) - (desp_banc_26f/rol_26f*100) ELSE NULL END, 1),
    40
FROM numeros

UNION ALL

-- 41. Despesas com Isenção (sub-item)
SELECT '  Despesas com Isenção',
    ROUND(isen_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN isen_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(isen_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN isen_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(isen_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN isen_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(isen_26r - isen_26f, 0),
    ROUND(CASE WHEN isen_26f <> 0 THEN (isen_26r - isen_26f) / ABS(isen_26f) * 100 ELSE NULL END, 1),
    ROUND(isen_26r - isen_25r, 0),
    ROUND(CASE WHEN isen_25r <> 0 THEN (isen_26r - isen_25r) / ABS(isen_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (isen_26r/rol_26r*100) - (isen_26f/rol_26f*100) ELSE NULL END, 1),
    41
FROM numeros

UNION ALL

-- 42. Descontos Comerciais (sub-item)
SELECT '  Descontos Comerciais',
    ROUND(desc_com_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN desc_com_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(desc_com_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN desc_com_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(desc_com_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN desc_com_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(desc_com_26r - desc_com_26f, 0),
    ROUND(CASE WHEN desc_com_26f <> 0 THEN (desc_com_26r - desc_com_26f) / ABS(desc_com_26f) * 100 ELSE NULL END, 1),
    ROUND(desc_com_26r - desc_com_25r, 0),
    ROUND(CASE WHEN desc_com_25r <> 0 THEN (desc_com_26r - desc_com_25r) / ABS(desc_com_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (desc_com_26r/rol_26r*100) - (desc_com_26f/rol_26f*100) ELSE NULL END, 1),
    42
FROM numeros

UNION ALL

-- 43. (=) Total Desp Vendas
SELECT '(=) Total Desp Vendas',
    ROUND(td_vendas_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN td_vendas_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(td_vendas_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN td_vendas_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(td_vendas_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN td_vendas_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(td_vendas_26r - td_vendas_26f, 0),
    ROUND(CASE WHEN td_vendas_26f <> 0 THEN (td_vendas_26r - td_vendas_26f) / ABS(td_vendas_26f) * 100 ELSE NULL END, 1),
    ROUND(td_vendas_26r - td_vendas_25r, 0),
    ROUND(CASE WHEN td_vendas_25r <> 0 THEN (td_vendas_26r - td_vendas_25r) / ABS(td_vendas_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (td_vendas_26r/rol_26r*100) - (td_vendas_26f/rol_26f*100) ELSE NULL END, 1),
    43
FROM numeros

UNION ALL

-- ==================== EBITDA ====================

-- 44. (=) EBITDA
SELECT '(=) EBITDA',
    ROUND(ebitda_25r, 0), ROUND(CASE WHEN rol_25r <> 0 THEN ebitda_25r / rol_25r * 100 ELSE NULL END, 1),
    ROUND(ebitda_26f, 0), ROUND(CASE WHEN rol_26f <> 0 THEN ebitda_26f / rol_26f * 100 ELSE NULL END, 1),
    ROUND(ebitda_26r, 0), ROUND(CASE WHEN rol_26r <> 0 THEN ebitda_26r / rol_26r * 100 ELSE NULL END, 1),
    ROUND(ebitda_26r - ebitda_26f, 0),
    ROUND(CASE WHEN ebitda_26f <> 0 THEN (ebitda_26r - ebitda_26f) / ABS(ebitda_26f) * 100 ELSE NULL END, 1),
    ROUND(ebitda_26r - ebitda_25r, 0),
    ROUND(CASE WHEN ebitda_25r <> 0 THEN (ebitda_26r - ebitda_25r) / ABS(ebitda_25r) * 100 ELSE NULL END, 1),
    ROUND(CASE WHEN rol_26r <> 0 AND rol_26f <> 0 THEN (ebitda_26r/rol_26r*100) - (ebitda_26f/rol_26f*100) ELSE NULL END, 1),
    44
FROM numeros

ORDER BY sort_order
