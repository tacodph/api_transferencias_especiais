-- ============================================================
-- 09: upsert com hash + inativação + parlamentar pelo código do autor
-- Schema: se_api_transferencias_especiais. Idempotente.
--
-- 1) Toda tabela *_especiais ganha:
--      row_hash       md5 dos campos da API; o upsert só regrava a linha quando muda
--      fl_ativo       false quando a chave deixou de vir numa carga completa
--      dt_inativacao  quando foi inativada
--    Consultas devem filtrar fl_ativo. Na primeira carga depois deste script
--    todas as linhas são regravadas uma vez (row_hash ainda nulo).
--
-- 2) vw_emendas_especiais_parlamentar: emenda do plano de ação ligada ao
--    parlamentar de transfere_pro_transferegov (tab_autores_emendas /
--    tab_parlamentares, migration das emendas 2026_10_23_100000). Sem essas
--    tabelas a view não é criada (aviso). Os códigos e grafias desta fonte
--    entram por parlamentar_especiais.py.
--
-- Mesmo DDL na migration do transferepro:
--   database/migrations/transferencias_especiais/2026_10_23_110000_add_hash_inativacao_parlamentar_especiais.php
-- ============================================================

ALTER TABLE se_api_transferencias_especiais.programas_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.beneficiarios_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.planos_acao_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.planos_acao_historico_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.empenhos_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.documentos_habeis_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.ordens_pagamentos_ordens_bancarias_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.relatorios_gestao_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.relatorios_gestao_novos_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.executor_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.meta_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.finalidade_pt_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.planos_trabalho_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.planos_trabalho_analises_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.orgaos_analises_pendentes_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.pt_historico_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.pt_analise_historico_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.gestao_financeira_lancamentos_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.gestao_financeira_subtransacoes_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;
ALTER TABLE se_api_transferencias_especiais.saldo_conta_gestao_financeira_especiais
    ADD COLUMN IF NOT EXISTS row_hash CHAR(32),
    ADD COLUMN IF NOT EXISTS fl_ativo BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS dt_inativacao TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_planos_acao_especiais_codigo_parlamentar
    ON se_api_transferencias_especiais.planos_acao_especiais (codigo_parlamentar_emenda_plano_acao);

-- ============================================================
-- vw_emendas_especiais_parlamentar
-- cod_autor = codigo_parlamentar_emenda_plano_acao com 4 dígitos (o mesmo
-- left(nr_emenda, 4) do siconv); nr_emenda = cod_autor + sequencial com
-- 4 dígitos, no formato do siconv, para cruzar com as outras modalidades.
-- ============================================================
DO $do$
BEGIN
    IF to_regclass('transfere_pro_transferegov.tab_autores_emendas') IS NULL THEN
        RAISE NOTICE 'vw_emendas_especiais_parlamentar não criada: falta transfere_pro_transferegov.tab_autores_emendas';
        RETURN;
    END IF;

    EXECUTE $v$
CREATE OR REPLACE VIEW se_api_transferencias_especiais.vw_emendas_especiais_parlamentar AS
WITH e AS (
    SELECT pa.*,
           CASE WHEN pa.codigo_parlamentar_emenda_plano_acao BETWEEN 0 AND 9999
                THEN lpad(pa.codigo_parlamentar_emenda_plano_acao::text, 4, '0') END AS cod_autor
    FROM se_api_transferencias_especiais.planos_acao_especiais AS pa
    WHERE pa.fl_ativo AND pa.codigo_parlamentar_emenda_plano_acao IS NOT NULL
)
SELECT
    e.id_plano_acao,
    e.codigo_plano_acao,
    e.ano_plano_acao,
    e.situacao_plano_acao,
    e.ano_emenda_parlamentar_plano_acao::smallint AS ano_emenda,
    e.cod_autor::char(4) AS cod_autor,
    e.sequencial_emenda_parlamentar_plano_acao AS sequencial_emenda,
    CASE WHEN e.sequencial_emenda_parlamentar_plano_acao BETWEEN 0 AND 9999
         THEN e.cod_autor || lpad(e.sequencial_emenda_parlamentar_plano_acao::text, 4, '0') END AS nr_emenda,
    e.numero_emenda_parlamentar_plano_acao AS numero_emenda,
    e.codigo_emenda_parlamentar_formatado_plano_acao AS codigo_emenda_formatado,
    a.id_parlamentar,
    COALESCE(p.nome_parlamentar, a.nome_parlamentar, e.nome_parlamentar_emenda_plano_acao) AS nome_parlamentar,
    e.nome_parlamentar_emenda_plano_acao AS nome_parlamentar_origem,
    a.tipo_parlamentar,
    COALESCE(a.fl_revisar, false) AS fl_revisar,
    e.id_beneficiario,
    b.cnpj_beneficiario,
    b.nome_beneficiario,
    b.uf_beneficiario,
    e.id_programa,
    e.valor_custeio_plano_acao,
    e.valor_investimento_plano_acao
FROM e
LEFT JOIN se_api_transferencias_especiais.beneficiarios_especiais AS b
       ON b.id_beneficiario = e.id_beneficiario AND b.fl_ativo
LEFT JOIN transfere_pro_transferegov.tab_autores_emendas AS a ON a.cod_autor = e.cod_autor
LEFT JOIN transfere_pro_transferegov.tab_parlamentares AS p ON p.id_parlamentar = a.id_parlamentar
    $v$;

    EXECUTE $c$
COMMENT ON VIEW se_api_transferencias_especiais.vw_emendas_especiais_parlamentar IS
    'Planos de ação ativos com a emenda (ano, cod_autor, nr_emenda no formato siconv) e o parlamentar pelo código do autor'
    $c$;
END
$do$;
