-- ============================================================
-- Controle de carga alinhado ao padrão transfere_pro_transferegov
-- Schema: se_api_transferencias_especiais
-- Substitui o controle_carga antigo (colunas tabela/registros_*)
-- ============================================================

-- Remove o modelo antigo (incompatível)
DROP TABLE IF EXISTS se_api_transferencias_especiais.controle_carga CASCADE;

CREATE SEQUENCE IF NOT EXISTS se_api_transferencias_especiais.controle_carga_dia_id_seq;
CREATE SEQUENCE IF NOT EXISTS se_api_transferencias_especiais.controle_carga_id_seq;

CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.controle_carga_dia
(
    id                      integer       NOT NULL DEFAULT nextval('se_api_transferencias_especiais.controle_carga_dia_id_seq'::regclass),
    dt_carga                date          NOT NULL DEFAULT CURRENT_DATE,
    seq_execucao_dia        smallint      NOT NULL,
    dt_inicio               timestamp without time zone NOT NULL,
    dt_fim                  timestamp without time zone,
    status                  character varying NOT NULL DEFAULT 'EXECUTANDO',
    qtd_arquivos_extraidos  integer       NOT NULL DEFAULT 0,
    qtd_arquivos_carregados integer       NOT NULL DEFAULT 0,
    qtd_arquivos_erro       integer       NOT NULL DEFAULT 0,
    qtd_arquivos_pulados    integer       NOT NULL DEFAULT 0,
    mensagem                text,
    log_arquivo             character varying,
    CONSTRAINT controle_carga_dia_pkey PRIMARY KEY (id),
    CONSTRAINT uq_controle_carga_dia_data_seq UNIQUE (dt_carga, seq_execucao_dia),
    CONSTRAINT chk_controle_carga_dia_status CHECK (
        status::text = ANY (ARRAY[
            'EXECUTANDO'::text,
            'CARREGANDO'::text,
            'SUCESSO'::text,
            'CORRIGIDO/SUCESSO'::text,
            'ERRO'::text,
            'PARCIAL'::text
        ])
    )
);

CREATE TABLE IF NOT EXISTS se_api_transferencias_especiais.controle_carga
(
    id                          integer       NOT NULL DEFAULT nextval('se_api_transferencias_especiais.controle_carga_id_seq'::regclass),
    id_controle_carga_dia       integer,
    endpoint                    character varying NOT NULL,
    dt_inicio                   timestamp without time zone NOT NULL,
    dt_fim                      timestamp without time zone,
    status                      character varying NOT NULL DEFAULT 'EXECUTANDO',
    total_registros             integer,
    qtd_registros_inseridos     integer,
    qtd_registros_atualizados   integer,
    id_controle_carga_refatorado integer,
    mensagem                    text,
    CONSTRAINT controle_carga_pkey PRIMARY KEY (id),
    CONSTRAINT fk_controle_carga_dia FOREIGN KEY (id_controle_carga_dia)
        REFERENCES se_api_transferencias_especiais.controle_carga_dia (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_controle_carga_refatorado FOREIGN KEY (id_controle_carga_refatorado)
        REFERENCES se_api_transferencias_especiais.controle_carga (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT chk_status CHECK (
        status::text = ANY (ARRAY[
            'EXECUTANDO'::text,
            'CARREGANDO'::text,
            'SUCESSO'::text,
            'CORRIGIDO/SUCESSO'::text,
            'ERRO'::text,
            'ERRO NÃO CORRIGIDO'::text,
            'PARCIAL'::text,
            'PULADO'::text
        ])
    )
);

CREATE INDEX IF NOT EXISTS ix_controle_carga_dia
    ON se_api_transferencias_especiais.controle_carga (id_controle_carga_dia);

CREATE INDEX IF NOT EXISTS ix_controle_carga_endpoint_dt
    ON se_api_transferencias_especiais.controle_carga (endpoint, dt_inicio DESC);

COMMENT ON TABLE se_api_transferencias_especiais.controle_carga_dia IS
    'Controle diário das execuções de carga da API Transferências Especiais';
COMMENT ON TABLE se_api_transferencias_especiais.controle_carga IS
    'Log por endpoint/tabela de cada execução de carga';
