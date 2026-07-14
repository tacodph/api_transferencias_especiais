-- ============================================================
-- Remove tabelas/views do modelo antigo (*_especial singular)
-- Mantém: *_especiais (v2), controle_carga
-- Solicitado antes da carga completa v2 (Prompt 6)
-- ============================================================

-- Views que dependem das tabelas antigas
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_beneficiario_plano_acao_especial CASCADE;
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_emenda_parlamentar_plano_acao_especial CASCADE;
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_transferencias_por_uf CASCADE;
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_pagamentos_pendentes CASCADE;
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_resumo_parlamentar CASCADE;
DROP VIEW IF EXISTS se_api_transferencias_especiais.vw_execucao_financeira CASCADE;

-- Tabelas do modelo v1 (16 de carga + extrato legado)
DROP TABLE IF EXISTS se_api_transferencias_especiais.plano_trabalho_analise_historico_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.plano_trabalho_historico_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.orgao_analise_pendente_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.plano_trabalho_analise_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.finalidade_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.plano_trabalho_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.meta_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.executor_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.historico_pagamento_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.documento_habil_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.empenho_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.relatorio_gestao_novo_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.relatorio_gestao_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.plano_acao_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.programa_especial CASCADE;
DROP TABLE IF EXISTS se_api_transferencias_especiais.extrato_lancamento_especial CASCADE;
