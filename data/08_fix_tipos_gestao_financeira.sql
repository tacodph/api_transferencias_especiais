-- ============================================================
-- Corrige tipos: API mascara dados bancários com '***'
-- (incompatível com BIGINT)
-- ============================================================

ALTER TABLE se_api_transferencias_especiais.gestao_financeira_lancamentos_especiais
    ALTER COLUMN codigo_agencia_favorecido_gestao_financeira TYPE TEXT USING codigo_agencia_favorecido_gestao_financeira::text,
    ALTER COLUMN codigo_conta_favorecido_gestao_financeira TYPE TEXT USING codigo_conta_favorecido_gestao_financeira::text;

ALTER TABLE se_api_transferencias_especiais.gestao_financeira_subtransacoes_especiais
    ALTER COLUMN codigo_agencia_beneficiario_subtransacao_gestao_financeira TYPE TEXT USING codigo_agencia_beneficiario_subtransacao_gestao_financeira::text,
    ALTER COLUMN codigo_conta_beneficiario_subtransacao_gestao_financeira TYPE TEXT USING codigo_conta_beneficiario_subtransacao_gestao_financeira::text;
