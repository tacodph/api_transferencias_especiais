-- ============================================================
-- DDL: Novo modelo (API v2) — tabelas em paralelo às antigas
-- Schema: se_api_transferencias_especiais
-- Fonte: docs/novo modelos de dados/.../api-transferegov.api_transferegov_especiais.xml
-- URL: https://api-publica.transferegov.gestao.gov.br/especiais
-- Estratégia: paralela com corte (Prompt 2). Não altera tabelas *_especial.
-- PKs das 5 tabelas sem PK no XML: docs/prompt1_mapa_e_chaves_v2.md
-- ============================================================

CREATE SCHEMA IF NOT EXISTS se_api_transferencias_especiais;

-- ============================================================
-- 1. programas_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.programas_especiais (
    id_orgao_programa                                       BIGINT,
    id_orgao_superior_programa                              BIGINT,
    id_programa                                             BIGINT PRIMARY KEY,
    ano_programa                                            BIGINT,
    modalidade_programa                                     TEXT,
    codigo_programa                                         TEXT,
    id_unidade_gestora_programa                             BIGINT,
    documentos_origem_programa                              TEXT,
    id_unidade_orcamentaria_responsavel_programa            BIGINT,
    data_inicio_ciencia_programa                            DATE,
    data_fim_ciencia_programa                               DATE,
    valor_necessidade_financeira_programa                   NUMERIC,
    valor_total_disponibilizado_programa                    NUMERIC,
    valor_impedido_programa                                 NUMERIC,
    valor_a_disponibilizar_programa                         NUMERIC,
    valor_documentos_habeis_gerados_programa                NUMERIC,
    valor_obs_geradas_programa                              NUMERIC,
    valor_disponibilidade_atual_programa                    NUMERIC,
    sigla_orgao_superior_programa                           TEXT,
    cnpj_orgao_superior_programa                            TEXT,
    nome_orgao_superior_programa                            TEXT,
    sigla_orgao_programa                                    TEXT,
    cnpj_orgao_programa                                     TEXT,
    nome_orgao_programa                                     TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.programas_especiais IS 'Tabela que armazena informações detalhadas sobre programas especiais, incluindo dados orçamentários e financeiros.';

-- ============================================================
-- 2. beneficiarios_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.beneficiarios_especiais (
    id_beneficiario                                         BIGINT PRIMARY KEY,
    uf_beneficiario                                         TEXT,
    nome_beneficiario                                       TEXT,
    cnpj_beneficiario                                       TEXT,
    id_ente                                                 BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.beneficiarios_especiais IS 'Tabela responsável por armazenar dados de beneficiários especiais.';

-- ============================================================
-- 3. planos_acao_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.planos_acao_especiais (
    id_plano_acao                                           BIGINT PRIMARY KEY,
    codigo_plano_acao                                       TEXT,
    ano_plano_acao                                          BIGINT,
    modalidade_plano_acao                                   TEXT,
    situacao_plano_acao                                     TEXT,
    email_camara                                            TEXT,
    data_aceite_plano_acao                                  DATE,
    codigo_banco_plano_acao                                 TEXT,
    codigo_situacao_dado_bancario_plano_acao                BIGINT,
    descricao_situacao_dado_bancario_plano_acao             TEXT,
    nome_banco_plano_acao                                   TEXT,
    numero_agencia_plano_acao                               TEXT,
    dv_agencia_plano_acao                                   TEXT,
    numero_conta_plano_acao                                 TEXT,
    dv_conta_plano_acao                                     TEXT,
    nome_parlamentar_emenda_plano_acao                      TEXT,
    ano_emenda_parlamentar_plano_acao                       BIGINT,
    codigo_parlamentar_emenda_plano_acao                    BIGINT,
    sequencial_emenda_parlamentar_plano_acao                BIGINT,
    numero_emenda_parlamentar_plano_acao                    BIGINT,
    codigo_emenda_parlamentar_formatado_plano_acao          TEXT,
    motivo_impedimento_plano_acao                           TEXT,
    valor_custeio_plano_acao                                NUMERIC,
    valor_investimento_plano_acao                           NUMERIC,
    id_agencia_conta                                        TEXT,
    id_beneficiario                                         BIGINT,
    id_objeto                                               BIGINT,
    nome_objeto                                             TEXT,
    detalhamento_objeto                                     TEXT,
    id_programa                                             BIGINT,
    categoria_despesa_plano_acao                            TEXT,
    codigo_descricao_areas_politicas_publicas_plano_acao    TEXT,
    descricao_programacao_orcamentaria_plano_acao           TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.planos_acao_especiais IS 'Tabela de planos de ação vinculados a programas especiais.';

-- ============================================================
-- 4. planos_acao_historico_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.planos_acao_historico_especiais (
    id_historico_plano_acao                                 BIGINT PRIMARY KEY,
    situacao_historico_plano_acao                           TEXT,
    operacao_historico_plano_acao                           TEXT,
    descricao_historico_plano_acao                          TEXT,
    data_hora_historico_plano_acao                          TIMESTAMP,
    id_plano_acao                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.planos_acao_historico_especiais IS 'Tabela responsável por armazenar o histórico de alterações e situações dos planos de ação especiais.';

-- ============================================================
-- 5. empenhos_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.empenhos_especiais (
    id_empenho                                              BIGINT PRIMARY KEY,
    id_minuta_empenho                                       TEXT,
    numero_empenho                                          TEXT,
    situacao_empenho                                        BIGINT,
    descricao_situacao_empenho                              TEXT,
    tipo_documento_empenho                                  BIGINT,
    descricao_tipo_documento_empenho                        TEXT,
    status_processamento_empenho                            TEXT,
    ug_responsavel_empenho                                  BIGINT,
    ug_emitente_empenho                                     BIGINT,
    descricao_ug_emitente_empenho                           TEXT,
    fonte_recurso_empenho                                   TEXT,
    plano_interno_empenho                                   TEXT,
    ptres_empenho                                           BIGINT,
    grupo_natureza_despesa_empenho                          BIGINT,
    natureza_despesa_empenho                                BIGINT,
    subitem_empenho                                         BIGINT,
    categoria_despesa_empenho                               TEXT,
    modalidade_despesa_empenho                              BIGINT,
    numero_ro_empenho                                       TEXT,
    data_emissao_empenho                                    DATE,
    prioridade_desbloqueio_empenho                          BIGINT,
    valor_empenho                                           NUMERIC,
    id_plano_acao                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.empenhos_especiais IS 'Tabela contendo informações detalhadas sobre empenhos especiais.';

-- ============================================================
-- 6. documentos_habeis_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.documentos_habeis_especiais (
    id_dh                                                   BIGINT PRIMARY KEY,
    id_minuta_documento_habil                               TEXT,
    numero_documento_habil                                  TEXT,
    situacao_dh                                             BIGINT,
    descricao_situacao_dh                                   TEXT,
    tipo_documento_dh                                       TEXT,
    ug_emitente_dh                                          BIGINT,
    descricao_ug_emitente_dh                                TEXT,
    data_vencimento_dh                                      DATE,
    data_emissao_dh                                         DATE,
    ug_pagadora_dh                                          BIGINT,
    descricao_ug_pagadora_dh                                TEXT,
    variacao_patrimonial_diminuta_dh                        BIGINT,
    passivo_transferencia_constitucional_legal_dh           BIGINT,
    descricao_centro_custo_dh                               TEXT,
    codigo_siorg_centro_custo_dh                            BIGINT,
    mes_referencia_centro_custo_dh                          BIGINT,
    ano_referencia_centro_custo_dh                          BIGINT,
    mes_ano_referencia_centro_custo_dh                      TEXT,
    ug_beneficiada_centro_custo_dh                          BIGINT,
    descricao_ug_beneficiada_centro_custo_dh                TEXT,
    valor_dh                                                NUMERIC,
    valor_rateio_dh                                         NUMERIC,
    valor_custo_centro_custo_dh                             NUMERIC,
    id_empenho                                              BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.documentos_habeis_especiais IS 'Tabela de Documentos Hábeis Especiais.';

-- ============================================================
-- 7. ordens_pagamentos_ordens_bancarias_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.ordens_pagamentos_ordens_bancarias_especiais (
    id_op_ob                                                BIGINT PRIMARY KEY,
    data_emissao_op                                         DATE,
    numero_ordem_pagamento                                  TEXT,
    vinculacao_op                                           BIGINT,
    situacao_op                                             BIGINT,
    descricao_situacao_op                                   TEXT,
    data_situacao_op                                        DATE,
    data_emissao_ob                                         DATE,
    numero_ordem_bancaria                                   TEXT,
    numero_ordem_lancamento                                 TEXT,
    data_assinatura_ordenador_despesa_ob                    DATE,
    data_assinatura_gestor_financeiro_ob                    DATE,
    id_dh                                                   BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.ordens_pagamentos_ordens_bancarias_especiais IS 'Tabela que armazena informações sobre Ordens de Pagamento e Ordens Bancárias especiais.';

-- ============================================================
-- 8. relatorios_gestao_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.relatorios_gestao_especiais (
    id_relatorio_gestao                                     BIGINT PRIMARY KEY,
    data_relatorio_gestao                                   DATE,
    data_e_hora_relatorio_gestao                            TIMESTAMP,
    tipo_relatorio_gestao                                   TEXT,
    situacao_relatorio_gestao                               TEXT,
    valor_executado_relatorio_gestao                        NUMERIC,
    valor_pendente_relatorio_gestao                         NUMERIC,
    descritivo_relatorio_gestao                             TEXT,
    id_plano_acao                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.relatorios_gestao_especiais IS 'Armazena os relatórios de gestão especiais vinculados aos planos de ação.';

-- ============================================================
-- 9. relatorios_gestao_novos_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.relatorios_gestao_novos_especiais (
    id_relatorio_gestao_novo                                BIGINT PRIMARY KEY,
    data_relatorio_gestao_novo                              DATE,
    data_e_hora_relatorio_gestao_novo                       TIMESTAMP,
    tipo_relatorio_gestao_novo                              TEXT,
    valor_executado_relatorio_gestao_novo                   NUMERIC,
    valor_pendente_relatorio_gestao_novo                    NUMERIC,
    situacao_relatorio_gestao_novo                          TEXT,
    id_plano_acao                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.relatorios_gestao_novos_especiais IS 'Tabela responsável por armazenar os novos relatórios de gestão especiais e seus status financeiros.';

-- ============================================================
-- 10. executor_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.executor_especiais (
    id_executor                                             BIGINT,
    cnpj_executor                                           TEXT,
    nome_executor                                           TEXT,
    objeto_executor                                         TEXT,
    vl_custeio_executor                                     NUMERIC,
    vl_investimento_executor                                NUMERIC,
    ind_recursos_gerenciados_conta_especifica_executor      TEXT,
    codigo_banco_executor                                   TEXT,
    nome_banco_executor                                     TEXT,
    numero_agencia_executor                                 TEXT,
    numero_dv_agencia_executor                              TEXT,
    nome_agencia_executor                                   TEXT,
    numero_conta_executor                                   TEXT,
    numero_dv_conta_executor                                TEXT,
    codigo_situacao_dado_bancario_executor                  BIGINT,
    descricao_situacao_dado_bancario_executor               TEXT,
    id_plano_acao                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_acao, id_executor)
);
COMMENT ON TABLE se_api_transferencias_especiais.executor_especiais IS 'Tabela contendo informações sobre os executores e seus dados bancários, relacionados a planos de ação especiais.';

-- ============================================================
-- 11. meta_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.meta_especiais (
    id_executor                                             BIGINT,
    id_meta                                                 BIGINT PRIMARY KEY,
    sequencial_meta                                         BIGINT,
    nome_meta                                               TEXT,
    desc_meta                                               TEXT,
    un_medida_meta                                          TEXT,
    qt_unidade_meta                                         BIGINT,
    vl_custeio_emenda_especial_meta                         NUMERIC,
    vl_investimento_emenda_especial_meta                    NUMERIC,
    vl_custeio_recursos_proprios_meta                       NUMERIC,
    vl_investimento_recursos_proprios_meta                  NUMERIC,
    vl_custeio_rendimento_meta                              NUMERIC,
    vl_investimento_rendimento_meta                         NUMERIC,
    vl_custeio_doacao_meta                                  NUMERIC,
    vl_investimento_doacao_meta                             NUMERIC,
    qt_meses_meta                                           BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.meta_especiais IS 'Tabela que armazena as Metas associadas aos Executores especiais.';

-- ============================================================
-- 12. finalidade_pt_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.finalidade_pt_especiais (
    id_executor                                             BIGINT,
    cd_area_politica_publica_tipo_pt                        BIGINT,
    area_politica_publica_tipo_pt                           TEXT,
    cd_area_politica_publica_pt                             BIGINT,
    area_politica_publica_pt                                TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_executor, cd_area_politica_publica_tipo_pt, cd_area_politica_publica_pt)
);
COMMENT ON TABLE se_api_transferencias_especiais.finalidade_pt_especiais IS 'Tabela de detalhe da Finalidade do Programa de Trabalho associado ao Executor.';

-- ============================================================
-- 13. planos_trabalho_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.planos_trabalho_especiais (
    id_plano_trabalho                                       BIGINT PRIMARY KEY,
    dt_hora_situacao_plano_trabalho                         TIMESTAMP,
    situacao_plano_trabalho                                 TEXT,
    ind_orcamento_proprio_plano_trabalho                    TEXT,
    data_inicio_execucao_plano_trabalho                     DATE,
    data_fim_execucao_plano_trabalho                        DATE,
    prazo_execucao_meses_plano_trabalho                     BIGINT,
    id_plano_acao                                           BIGINT,
    classificacao_orcamentaria_pt                           TEXT,
    ind_justificativa_prorrogacao_atraso_pt                 TEXT,
    ind_justificativa_prorrogacao_paralizacao_pt            TEXT,
    justificativa_prorrogacao_paralizacao_pt                TEXT,
    dt_hora_pt_aprovado                                     TIMESTAMP,
    ind_orgao_analises_pendentes                            TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.planos_trabalho_especiais IS 'Tabela para armazenar dados de planos de trabalho especiais e suas situações.';

-- ============================================================
-- 14. planos_trabalho_analises_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.planos_trabalho_analises_especiais (
    id_plano_trabalho_analise_pt                            BIGINT PRIMARY KEY,
    codigo_siorg_orgao_analise_pt                           BIGINT,
    nome_orgao_analise_pt                                   TEXT,
    situacao_planejamento_pt                                TEXT,
    situacao_parecer_analise_pt                             TEXT,
    texto_parecer_analise_pt                                TEXT,
    situacao_analise_pt                                     TEXT,
    data_analise_pt                                         TIMESTAMP,
    valor_reprovado_pt                                      NUMERIC,
    id_plano_trabalho                                       BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.planos_trabalho_analises_especiais IS 'Armazena os dados das análises especiais realizadas sobre os planos de trabalho.';

-- ============================================================
-- 15. orgaos_analises_pendentes_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.orgaos_analises_pendentes_especiais (
    id_plano_trabalho                                       BIGINT,
    id_orgao_analise_pendente_pt                            BIGINT,
    nome_orgao_analise_pendente_pt                          TEXT,
    ind_orgao_analises_pendentes                            TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_trabalho, id_orgao_analise_pendente_pt)
);
COMMENT ON TABLE se_api_transferencias_especiais.orgaos_analises_pendentes_especiais IS 'Tabela responsável por armazenar informações sobre órgãos com análises pendentes vinculados a planos de trabalho especiais.';

-- ============================================================
-- 16. pt_historico_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.pt_historico_especiais (
    id_plano_trabalho_hist                                  BIGINT PRIMARY KEY,
    data_plano_trabalho_hist                                TIMESTAMP,
    cpf_responsavel_plano_trabalho_hist                     TEXT,
    situacao_plano_trabalho_hist                            TEXT,
    id_plano_trabalho                                       BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.pt_historico_especiais IS 'Tabela destinada a armazenar o histórico de situações dos planos de trabalho especiais.';

-- ============================================================
-- 17. pt_analise_historico_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.pt_analise_historico_especiais (
    codigo_siorg_orgao_analise_pt_hist                      BIGINT,
    nome_orgao_analise_pt_hist                              TEXT,
    situacao_parecer_analise_pt_hist                        TEXT,
    data_analise_pt_hist                                    TIMESTAMP,
    situacao_analise_pt_hist                                TEXT,
    responsaveis_analise_pt_hist                            TEXT,
    id_plano_trabalho_analise_pt                            BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_trabalho_analise_pt, codigo_siorg_orgao_analise_pt_hist, data_analise_pt_hist)
);
COMMENT ON TABLE se_api_transferencias_especiais.pt_analise_historico_especiais IS 'Tabela destinada a armazenar o histórico de análises especiais de planos de trabalho.';

-- ============================================================
-- 18. gestao_financeira_lancamentos_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.gestao_financeira_lancamentos_especiais (
    id_agencia_conta                                        TEXT,
    id_lancamento_gestao_financeira                         TEXT PRIMARY KEY,
    origem_solicitacao_gestao_financeira                    TEXT,
    cnpj_ente_solicitante_gestao_financeira                 TEXT,
    nome_ente_solicitante_gestao_financeira                 TEXT,
    codigo_banco_gestao_financeira                          BIGINT,
    codigo_agencia_gestao_financeira                        BIGINT,
    dv_agencia_gestao_financeira                            TEXT,
    codigo_conta_gestao_financeira                          BIGINT,
    dv_conta_gestao_financeira                              TEXT,
    descricao_gestao_financeira                             TEXT,
    data_lancamento_gestao_financeira                       DATE,
    numero_ordem_gestao_financeira                          BIGINT,
    numero_referencia_unica_gestao_financeira               TEXT,
    tipo_operacao_gestao_financeira                         TEXT,
    valor_gestao_financeira                                 NUMERIC,
    doc_depositante_gestao_financeira                       TEXT,
    nome_depositante_gestao_financeira                      TEXT,
    tipo_depositante_gestao_financeira                      BIGINT,
    codigo_banco_depositante_gestao_financeira              TEXT,
    codigo_agencia_depositante_gestao_financeira            TEXT,
    dv_agencia_depositante_gestao_financeira                TEXT,
    codigo_conta_depositante_gestao_financeira              TEXT,
    dv_conta_depositante_gestao_financeira                  TEXT,
    doc_favorecido_gestao_financeira                        TEXT,
    nome_favorecido_gestao_financeira                       TEXT,
    tipo_favorecido_gestao_financeira                       BIGINT,
    codigo_banco_favorecido_gestao_financeira               BIGINT,
    codigo_agencia_favorecido_gestao_financeira             TEXT,
    dv_agencia_favorecido_gestao_financeira                 TEXT,
    codigo_conta_favorecido_gestao_financeira               TEXT,
    dv_conta_favorecido_gestao_financeira                   TEXT,
    codigo_categoria_despesa_lancamento_gestao_financeira   BIGINT,
    quantidade_subtransacoes_lancamento_gestao_financeira   BIGINT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.gestao_financeira_lancamentos_especiais IS 'Armazena todos os lançamentos realizados nas contas de gestão financeira especiais.';

-- ============================================================
-- 19. gestao_financeira_subtransacoes_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.gestao_financeira_subtransacoes_especiais (
    id_subtransacao_gestao_financeira                       TEXT PRIMARY KEY,
    estado_subtransacao_gestao_financeira                   BIGINT,
    situacao_pagamento_subtransacao_gestao_financeira       BIGINT,
    data_pagamento_subtransacao_gestao_financeira           DATE,
    valor_subtransacao_gestao_financeira                    NUMERIC,
    codigo_banco_beneficiario_subtransacao_gestao_financeira BIGINT,
    codigo_agencia_beneficiario_subtransacao_gestao_financeira TEXT,
    codigo_conta_beneficiario_subtransacao_gestao_financeira TEXT,
    tipo_pessoa_beneficiario_subtransacao_gestao_financeira BIGINT,
    numero_documento_beneficiario_subtransacao_gestao_financeira TEXT,
    nome_beneficiario_subtransacao_gestao_financeira        TEXT,
    codigo_categoria_despesa_subtransacao_gestao_financeira BIGINT,
    descricao_subtransacao_gestao_financeira                TEXT,
    id_lancamento_gestao_financeira                         TEXT,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.gestao_financeira_subtransacoes_especiais IS 'Detalhamento das subtransações de pagamentos associadas a lançamentos financeiros.';

-- ============================================================
-- 20. saldo_conta_gestao_financeira_especiais
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.saldo_conta_gestao_financeira_especiais (
    id_agencia_conta                                        TEXT PRIMARY KEY,
    agencia_batch                                           BIGINT,
    conta_batch                                             BIGINT,
    data_saldo_conta                                        DATE,
    saldo_final_gestao_financeira                           NUMERIC,
    dt_carga                                                TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.saldo_conta_gestao_financeira_especiais IS 'Tabela responsável por armazenar os saldos de gestão financeira para contas especiais.';

