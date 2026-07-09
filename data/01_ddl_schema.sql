-- ============================================================
-- DDL: Schema se_api_transferencias_especiais
-- Servidor: campinas.cidades.gov.br
-- Fonte: API Transferências Especiais do Transferegov
-- Base URL: https://api.transferegov.dth.api.gov.br/transferenciasespeciais/
-- Gerado em: 2026-06-17
-- ============================================================

-- Cria o schema se não existir
CREATE SCHEMA IF NOT EXISTS se_api_transferencias_especiais;

-- ============================================================
-- 1. programa_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.programa_especial (
    id_programa                                  BIGINT        PRIMARY KEY,
    ano_programa                                 BIGINT,
    modalidade_programa                          VARCHAR(255),
    codigo_programa                              VARCHAR(2000),
    id_orgao_superior_programa                   BIGINT,
    sigla_orgao_superior_programa                TEXT,
    nome_orgao_superior_programa                 TEXT,
    id_orgao_programa                            INTEGER,
    sigla_orgao_programa                         TEXT,
    nome_orgao_programa                          TEXT,
    id_unidade_gestora_programa                  BIGINT,
    documentos_origem_programa                   TEXT,
    id_unidade_orcamentaria_responsavel_programa BIGINT,
    data_inicio_ciencia_programa                 DATE,
    data_fim_ciencia_programa                    DATE,
    valor_necessidade_financeira_programa        NUMERIC,
    valor_total_disponibilizado_programa         NUMERIC,
    valor_impedido_programa                      NUMERIC,
    valor_a_disponibilizar_programa              NUMERIC,
    valor_documentos_habeis_gerados_programa     NUMERIC,
    valor_obs_geradas_programa                   NUMERIC,
    valor_disponibilidade_atual_programa         NUMERIC,
    -- controle de carga
    dt_carga                                     TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.programa_especial IS 'Programas Especiais do Transferegov (EC 105/2019)';

-- ============================================================
-- 2. plano_acao_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.plano_acao_especial (
    id_plano_acao                                          BIGINT        PRIMARY KEY,
    codigo_plano_acao                                      TEXT,
    ano_plano_acao                                         INTEGER,
    modalidade_plano_acao                                  TEXT,
    situacao_plano_acao                                    TEXT,
    cnpj_beneficiario_plano_acao                           VARCHAR(20),
    nome_beneficiario_plano_acao                           TEXT,
    uf_beneficiario_plano_acao                             VARCHAR(2),
    codigo_banco_plano_acao                                TEXT,
    codigo_situacao_dado_bancario_plano_acao               BIGINT,
    nome_banco_plano_acao                                  TEXT,
    numero_agencia_plano_acao                              BIGINT,
    dv_agencia_plano_acao                                  TEXT,
    numero_conta_plano_acao                                INTEGER,
    dv_conta_plano_acao                                    TEXT,
    nome_parlamentar_emenda_plano_acao                     TEXT,
    ano_emenda_parlamentar_plano_acao                      CHAR(4),
    codigo_parlamentar_emenda_plano_acao                   TEXT,
    sequencial_emenda_parlamentar_plano_acao               INTEGER,
    numero_emenda_parlamentar_plano_acao                   TEXT,
    codigo_emenda_parlamentar_formatado_plano_acao         TEXT,
    codigo_descricao_areas_politicas_publicas_plano_acao   TEXT,
    descricao_programacao_orcamentaria_plano_acao          TEXT,
    motivo_impedimento_plano_acao                          TEXT,
    valor_custeio_plano_acao                               NUMERIC,
    valor_investimento_plano_acao                          NUMERIC,
    id_programa                                            BIGINT,
    dt_carga                                               TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.plano_acao_especial IS 'Planos de Ação das Transferências Especiais';

-- ============================================================
-- 3. empenho_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.empenho_especial (
    id_empenho                          BIGINT        PRIMARY KEY,
    id_minuta_empenho                   TEXT,
    numero_empenho                      TEXT,
    situacao_empenho                    INTEGER,
    descricao_situacao_empenho          TEXT,
    tipo_documento_empenho              INTEGER,
    descricao_tipo_documento_empenho    TEXT,
    status_processamento_empenho        TEXT,
    ug_responsavel_empenho              INTEGER,
    ug_emitente_empenho                 INTEGER,
    descricao_ug_emitente_empenho       TEXT,
    fonte_recurso_empenho               TEXT,
    plano_interno_empenho               TEXT,
    ptres_empenho                       BIGINT,
    grupo_natureza_despesa_empenho      TEXT,
    natureza_despesa_empenho            TEXT,
    subitem_empenho                     TEXT,
    categoria_despesa_empenho           TEXT,
    modalidade_despesa_empenho          INTEGER,
    cnpj_beneficiario_empenho           TEXT,
    nome_beneficiario_empenho           TEXT,
    uf_beneficiario_empenho             CHAR(2),
    numero_ro_empenho                   TEXT,
    data_emissao_empenho                DATE,
    prioridade_desbloqueio_empenho      INTEGER,
    valor_empenho                       NUMERIC,
    id_plano_acao                       BIGINT,
    dt_carga                            TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.empenho_especial IS 'Notas de Empenho das Transferências Especiais';

-- ============================================================
-- 4. documento_habil_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.documento_habil_especial (
    id_dh                                           BIGINT        PRIMARY KEY,
    id_minuta_documento_habil                       TEXT,
    numero_documento_habil                          TEXT,
    situacao_dh                                     SMALLINT,
    descricao_situacao_dh                           TEXT,
    tipo_documento_dh                               TEXT,
    ug_emitente_dh                                  BIGINT,
    descricao_ug_emitente_dh                        TEXT,
    data_vencimento_dh                              DATE,
    data_emissao_dh                                 DATE,
    ug_pagadora_dh                                  BIGINT,
    descricao_ug_pagadora_dh                        TEXT,
    variacao_patrimonial_diminuta_dh                TEXT,
    passivo_transferencia_constitucional_legal_dh   TEXT,
    centro_custo_empenho                            TEXT,
    codigo_siorg_empenho                            INTEGER,
    mes_referencia_empenho                          TEXT,
    ano_referencia_empenho                          INTEGER,
    ug_beneficiada_dh                               BIGINT,
    descricao_ug_beneficiada_dh                     TEXT,
    valor_dh                                        NUMERIC,
    valor_rateio_dh                                 NUMERIC,
    id_empenho                                      BIGINT,
    dt_carga                                        TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.documento_habil_especial IS 'Documentos Hábeis das Transferências Especiais';

-- ============================================================
-- 5. ordem_pagamento_ordem_bancaria_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial (
    id_op_ob                                    BIGINT        PRIMARY KEY,
    data_emissao_op                             DATE,
    numero_ordem_pagamento                      TEXT,
    vinculacao_op                               INTEGER,
    situacao_op                                 SMALLINT,
    descricao_situacao_op                       TEXT,
    data_situacao_op                            DATE,
    data_emissao_ob                             DATE,
    numero_ordem_bancaria                       TEXT,
    numero_ordem_lancamento                     TEXT,
    data_assinatura_ordenador_despesa_ob        DATE,
    data_assinatura_gestor_financeiro_ob        DATE,
    id_dh                                       BIGINT,
    dt_carga                                    TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial IS 'Ordens de Pagamento e Ordens Bancárias das Transferências Especiais';

-- ============================================================
-- 6. historico_pagamento_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.historico_pagamento_especial (
    id_historico_op_ob          BIGINT        PRIMARY KEY,
    data_hora_historico_op      TIMESTAMP,
    historico_situacao_op       SMALLINT,
    descricao_historico_situacao_op TEXT,
    id_op_ob                    BIGINT,
    dt_carga                    TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.historico_pagamento_especial IS 'Histórico de Pagamentos das Transferências Especiais';

-- ============================================================
-- 7. relatorio_gestao_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.relatorio_gestao_especial (
    id_relatorio_gestao         INTEGER       PRIMARY KEY,
    situacao_relatorio_gestao   TEXT,
    parecer_relatorio_gestao    TEXT,
    id_plano_acao               BIGINT,
    dt_carga                    TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.relatorio_gestao_especial IS 'Relatórios de Gestão das Transferências Especiais';

-- ============================================================
-- 8. relatorio_gestao_novo_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.relatorio_gestao_novo_especial (
    id_relatorio_gestao_novo                BIGINT        PRIMARY KEY,
    data_e_hora_relatorio_gestao_novo       TIMESTAMP,
    tipo_relatorio_gestao_novo              TEXT,
    valor_executado_relatorio_gestao_novo   NUMERIC,
    valor_pendente_relatorio_gestao_novo    NUMERIC,
    situacao_relatorio_gestao_novo          TEXT,
    id_plano_acao                           BIGINT,
    dt_carga                               TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.relatorio_gestao_novo_especial IS 'Novos Relatórios de Gestão das Transferências Especiais';

-- ============================================================
-- 9. meta_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.meta_especial (
    id_executor                             BIGINT,
    id_meta                                 BIGINT,
    sequencial_meta                         INTEGER,
    nome_meta                               TEXT,
    desc_meta                               TEXT,
    un_medida_meta                          TEXT,
    qt_uniade_meta                          NUMERIC,
    vl_custeio_emenda_especial_meta         NUMERIC,
    vl_investimento_emenda_especial_meta    NUMERIC,
    vl_custeio_recursos_proprios_meta       NUMERIC,
    vl_investimento_recursos_proprios_meta  NUMERIC,
    vl_custeio_rendimento_meta              NUMERIC,
    vl_investimento_rendimento_meta         NUMERIC,
    vl_custeio_doacao_meta                  NUMERIC,
    vl_investimento_doacao_meta             NUMERIC,
    qt_meses_meta                           SMALLINT,
    dt_carga                               TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_executor, id_meta)
);
COMMENT ON TABLE se_api_transferencias_especiais.meta_especial IS 'Metas dos Executores nas Transferências Especiais';

-- ============================================================
-- 10. executor_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.executor_especial (
    id_plano_acao                                   INTEGER,
    id_executor                                     INTEGER,
    cnpj_executor                                   VARCHAR(20),
    nome_executor                                   TEXT,
    objeto_executor                                 TEXT,
    vl_custeio_executor                             NUMERIC,
    vl_investimento_executor                        NUMERIC,
    ind_recursos_gerenciados_conta_especifica_executor TEXT,
    codigo_banco_executor                           TEXT,
    nome_banco_executor                             TEXT,
    numero_agencia_executor                         INTEGER,
    dv_agencia_executor                             TEXT,
    nome_agencia_executor                           TEXT,
    numero_conta_executor                           INTEGER,
    dv_conta_executor                               TEXT,
    codigo_situacao_dado_bancario_executor          INTEGER,
    descricao_situacao_dado_bancario_executor       TEXT,
    dt_carga                                        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_acao, id_executor)
);
COMMENT ON TABLE se_api_transferencias_especiais.executor_especial IS 'Executores das Transferências Especiais';

-- ============================================================
-- 11. plano_trabalho_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.plano_trabalho_especial (
    id_plano_trabalho                           BIGINT        PRIMARY KEY,
    situacao_plano_trabalho                     TEXT,
    ind_orcamento_proprio_plano_trabalho        TEXT,
    data_inicio_execucao_plano_trabalho         TIMESTAMP,
    data_fim_execucao_plano_trabalho            TIMESTAMP,
    prazo_execucao_meses_plano_trabalho         INTEGER,
    id_plano_acao                               BIGINT,
    classificacao_orcamentaria_pt               TEXT,
    ind_justificativa_prorrogacao_atraso_pt     BOOLEAN,
    ind_justificativa_prorrogacao_paralizacao_pt BOOLEAN,
    justificativa_prorrogacao_pt                TEXT,
    dt_carga                                    TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.plano_trabalho_especial IS 'Planos de Trabalho das Transferências Especiais';

-- ============================================================
-- 12. finalidade_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.finalidade_especial (
    id_executor                     BIGINT,
    cd_area_politica_publica_tipo_pt INTEGER,
    area_politica_publica_tipo_pt   TEXT,
    cd_area_politica_publica_pt     INTEGER,
    area_politica_publica_pt        TEXT,
    dt_carga                        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_executor, cd_area_politica_publica_tipo_pt, cd_area_politica_publica_pt)
);
COMMENT ON TABLE se_api_transferencias_especiais.finalidade_especial IS 'Finalidades/Áreas de Política Pública das Transferências Especiais';

-- ============================================================
-- 13. plano_trabalho_analise_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.plano_trabalho_analise_especial (
    id_plano_trabalho_analise       BIGINT        PRIMARY KEY,
    codigo_siorg_orgao_analise_pt   BIGINT,
    nome_orgao_analise_pt           TEXT,
    situacao_planejamento_pt        TEXT,
    situacao_parecer_analise_pt     TEXT,
    texto_parecer_analise_pt        TEXT,
    situacao_analise_pt             TEXT,
    data_analise_pt                 TIMESTAMP,
    valor_reprovado_analise_pt      NUMERIC,
    id_plano_trabalho               BIGINT,
    dt_carga                        TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE se_api_transferencias_especiais.plano_trabalho_analise_especial IS 'Análises dos Planos de Trabalho das Transferências Especiais';

-- ============================================================
-- 14. orgao_analise_pendente_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.orgao_analise_pendente_especial (
    id_analise_pendente             TEXT,
    id_orgao_analise_pendente_pt    BIGINT,
    nome_orgao_analise_pendente_pt  TEXT,
    id_plano_trabalho               BIGINT,
    dt_carga                        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_trabalho, id_orgao_analise_pendente_pt)
);
COMMENT ON TABLE se_api_transferencias_especiais.orgao_analise_pendente_especial IS 'Órgãos com Análises Pendentes nas Transferências Especiais';

-- ============================================================
-- 15. plano_trabalho_historico_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.plano_trabalho_historico_especial (
    id_plano_trabalho_hist          BIGINT,
    data_plano_trabalho_hist        TIMESTAMP,
    cpf_responsavel_plano_trabalho_hist TEXT,
    situacao_plano_trabalho_hist    TEXT,
    id_plano_trabalho               BIGINT,
    dt_carga                        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_trabalho_hist, id_plano_trabalho)
);
COMMENT ON TABLE se_api_transferencias_especiais.plano_trabalho_historico_especial IS 'Histórico dos Planos de Trabalho das Transferências Especiais';

-- ============================================================
-- 16. plano_trabalho_analise_historico_especial
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.plano_trabalho_analise_historico_especial (
    codigo_siorg_orgao_analise_pt_hist  BIGINT,
    nome_orgao_analise_pt_hist          TEXT,
    situacao_parecer_analise_pt_hist    TEXT,
    data_analise_pt_hist                TIMESTAMP,
    situacao_analise_pt_hist            TEXT,
    responsaveis_analise_pt_hist        TEXT,
    id_plano_trabalho_analise           BIGINT,
    dt_carga                            TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id_plano_trabalho_analise, codigo_siorg_orgao_analise_pt_hist, data_analise_pt_hist)
);
COMMENT ON TABLE se_api_transferencias_especiais.plano_trabalho_analise_historico_especial IS 'Histórico das Análises dos Planos de Trabalho das Transferências Especiais';

-- ============================================================
-- Tabela de controle de carga (log de execução)
-- ============================================================
CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.controle_carga (
    id              SERIAL        PRIMARY KEY,
    tabela          VARCHAR(100)  NOT NULL,
    dt_inicio       TIMESTAMP     NOT NULL DEFAULT NOW(),
    dt_fim          TIMESTAMP,
    registros_lidos INTEGER,
    registros_inseridos INTEGER,
    registros_atualizados INTEGER,
    status          VARCHAR(20)   CHECK (status IN ('EXECUTANDO', 'SUCESSO', 'ERRO')),
    mensagem        TEXT
);
COMMENT ON TABLE se_api_transferencias_especiais.controle_carga IS 'Log de controle das cargas da API Transferências Especiais';
