-- ============================================================
-- Adiciona PRIMARY KEYs ausentes nas tabelas do schema
-- se_api_transferencias_especiais
-- Necessário para o UPSERT (INSERT ... ON CONFLICT DO UPDATE)
-- ============================================================

ALTER TABLE se_api_transferencias_especiais.programa_especial
    ADD PRIMARY KEY (id_programa);

ALTER TABLE se_api_transferencias_especiais.plano_acao_especial
    ADD PRIMARY KEY (id_plano_acao);

ALTER TABLE se_api_transferencias_especiais.empenho_especial
    ADD PRIMARY KEY (id_empenho);

ALTER TABLE se_api_transferencias_especiais.documento_habil_especial
    ADD PRIMARY KEY (id_dh);

ALTER TABLE se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial
    ADD PRIMARY KEY (id_op_ob);

ALTER TABLE se_api_transferencias_especiais.historico_pagamento_especial
    ADD PRIMARY KEY (id_historico_op_ob);

ALTER TABLE se_api_transferencias_especiais.relatorio_gestao_especial
    ADD PRIMARY KEY (id_relatorio_gestao);

ALTER TABLE se_api_transferencias_especiais.relatorio_gestao_novo_especial
    ADD PRIMARY KEY (id_relatorio_gestao_novo);

ALTER TABLE se_api_transferencias_especiais.meta_especial
    ADD PRIMARY KEY (id_executor, id_meta);

ALTER TABLE se_api_transferencias_especiais.executor_especial
    ADD PRIMARY KEY (id_plano_acao, id_executor);

ALTER TABLE se_api_transferencias_especiais.plano_trabalho_especial
    ADD PRIMARY KEY (id_plano_trabalho);

ALTER TABLE se_api_transferencias_especiais.finalidade_especial
    ADD PRIMARY KEY (id_executor, cd_area_politica_publica_tipo_pt, cd_area_politica_publica_pt);

ALTER TABLE se_api_transferencias_especiais.plano_trabalho_analise_especial
    ADD PRIMARY KEY (id_plano_trabalho_analise);

ALTER TABLE se_api_transferencias_especiais.orgao_analise_pendente_especial
    ADD PRIMARY KEY (id_plano_trabalho, id_orgao_analise_pendente_pt);

ALTER TABLE se_api_transferencias_especiais.plano_trabalho_historico_especial
    ADD PRIMARY KEY (id_plano_trabalho_hist, id_plano_trabalho);

ALTER TABLE se_api_transferencias_especiais.plano_trabalho_analise_historico_especial
    ADD PRIMARY KEY (id_plano_trabalho_analise, codigo_siorg_orgao_analise_pt_hist, data_analise_pt_hist);
