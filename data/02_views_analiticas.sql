-- =============================================================================
-- Views analiticas — Transferencias Especiais
-- Schema: se_api_transferencias_especiais
-- Executar apos a carga das tabelas (01_ddl_schema.sql)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. vw_transferencias_por_uf
-- Total de transferencias (custeio + investimento) por UF e ano do plano de acao
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW se_api_transferencias_especiais.vw_transferencias_por_uf AS
SELECT
    pa.uf_beneficiario_plano_acao AS uf,
    pa.ano_plano_acao AS ano,
    COUNT(DISTINCT pa.id_plano_acao) AS qtd_planos_acao,
    COUNT(DISTINCT pa.id_programa) AS qtd_programas,
    SUM(COALESCE(pa.valor_custeio_plano_acao, 0)
      + COALESCE(pa.valor_investimento_plano_acao, 0)) AS valor_total_plano_acao,
    SUM(COALESCE(pa.valor_custeio_plano_acao, 0)) AS valor_custeio,
    SUM(COALESCE(pa.valor_investimento_plano_acao, 0)) AS valor_investimento
FROM se_api_transferencias_especiais.plano_acao_especial pa
WHERE pa.uf_beneficiario_plano_acao IS NOT NULL
GROUP BY pa.uf_beneficiario_plano_acao, pa.ano_plano_acao;

COMMENT ON VIEW se_api_transferencias_especiais.vw_transferencias_por_uf IS
    'Total de transferencias (valor custeio + investimento) por UF e ano';


-- -----------------------------------------------------------------------------
-- 2. vw_pagamentos_pendentes
-- Planos de acao com empenhos emitidos mas sem ordem bancaria (OB) associada
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW se_api_transferencias_especiais.vw_pagamentos_pendentes AS
WITH planos_empenhados AS (
    SELECT
        e.id_plano_acao,
        COUNT(DISTINCT e.id_empenho) AS qtd_empenhos,
        SUM(COALESCE(e.valor_empenho, 0)) AS valor_empenhado
    FROM se_api_transferencias_especiais.empenho_especial e
    GROUP BY e.id_plano_acao
),
planos_com_ob AS (
    SELECT DISTINCT e.id_plano_acao
    FROM se_api_transferencias_especiais.empenho_especial e
    INNER JOIN se_api_transferencias_especiais.documento_habil_especial dh
        ON dh.id_empenho = e.id_empenho
    INNER JOIN se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial op
        ON op.id_dh = dh.id_dh
    WHERE op.numero_ordem_bancaria IS NOT NULL
      AND TRIM(op.numero_ordem_bancaria) <> ''
)
SELECT
    pa.id_plano_acao,
    pa.codigo_plano_acao,
    pa.ano_plano_acao,
    pa.situacao_plano_acao,
    pa.uf_beneficiario_plano_acao AS uf,
    pa.nome_beneficiario_plano_acao AS beneficiario,
    pa.nome_parlamentar_emenda_plano_acao AS parlamentar,
    pa.codigo_emenda_parlamentar_formatado_plano_acao AS emenda,
    pe.qtd_empenhos,
    pe.valor_empenhado,
    COALESCE(pa.valor_custeio_plano_acao, 0)
      + COALESCE(pa.valor_investimento_plano_acao, 0) AS valor_plano_acao
FROM se_api_transferencias_especiais.plano_acao_especial pa
INNER JOIN planos_empenhados pe ON pe.id_plano_acao = pa.id_plano_acao
LEFT JOIN planos_com_ob pob ON pob.id_plano_acao = pa.id_plano_acao
WHERE pob.id_plano_acao IS NULL;

COMMENT ON VIEW se_api_transferencias_especiais.vw_pagamentos_pendentes IS
    'Planos de acao com empenhos mas sem ordem bancaria (OB) emitida';


-- -----------------------------------------------------------------------------
-- 3. vw_resumo_parlamentar
-- Emendas por parlamentar com valores empenhados e pagos
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW se_api_transferencias_especiais.vw_resumo_parlamentar AS
WITH base AS (
    SELECT
        pa.id_plano_acao,
        pa.nome_parlamentar_emenda_plano_acao AS parlamentar,
        pa.codigo_parlamentar_emenda_plano_acao AS codigo_parlamentar,
        pa.ano_emenda_parlamentar_plano_acao AS ano_emenda,
        pa.codigo_emenda_parlamentar_formatado_plano_acao AS emenda_formatada,
        COALESCE(pa.valor_custeio_plano_acao, 0)
          + COALESCE(pa.valor_investimento_plano_acao, 0) AS valor_plano_acao
    FROM se_api_transferencias_especiais.plano_acao_especial pa
    WHERE pa.nome_parlamentar_emenda_plano_acao IS NOT NULL
),
empenhos AS (
    SELECT
        e.id_plano_acao,
        SUM(COALESCE(e.valor_empenho, 0)) AS valor_empenhado
    FROM se_api_transferencias_especiais.empenho_especial e
    GROUP BY e.id_plano_acao
),
pagos AS (
    SELECT
        e.id_plano_acao,
        SUM(COALESCE(dh.valor_dh, 0)) AS valor_pago
    FROM se_api_transferencias_especiais.empenho_especial e
    INNER JOIN se_api_transferencias_especiais.documento_habil_especial dh
        ON dh.id_empenho = e.id_empenho
    INNER JOIN se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial op
        ON op.id_dh = dh.id_dh
    WHERE op.numero_ordem_bancaria IS NOT NULL
      AND TRIM(op.numero_ordem_bancaria) <> ''
    GROUP BY e.id_plano_acao
)
SELECT
    b.parlamentar,
    b.codigo_parlamentar,
    b.ano_emenda,
    COUNT(DISTINCT b.id_plano_acao) AS qtd_planos_acao,
    COUNT(DISTINCT b.emenda_formatada) AS qtd_emendas,
    SUM(b.valor_plano_acao) AS valor_total_plano_acao,
    SUM(COALESCE(emp.valor_empenhado, 0)) AS valor_empenhado,
    SUM(COALESCE(pag.valor_pago, 0)) AS valor_pago,
    SUM(COALESCE(emp.valor_empenhado, 0)) - SUM(COALESCE(pag.valor_pago, 0)) AS valor_pendente_pagamento
FROM base b
LEFT JOIN empenhos emp ON emp.id_plano_acao = b.id_plano_acao
LEFT JOIN pagos pag ON pag.id_plano_acao = b.id_plano_acao
GROUP BY b.parlamentar, b.codigo_parlamentar, b.ano_emenda;

COMMENT ON VIEW se_api_transferencias_especiais.vw_resumo_parlamentar IS
    'Resumo de emendas por parlamentar com valores empenhados e pagos';


-- -----------------------------------------------------------------------------
-- 4. vw_execucao_financeira
-- Visao consolidada por programa: empenhado x documentado x pago
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW se_api_transferencias_especiais.vw_execucao_financeira AS
WITH financeiro_plano AS (
    SELECT
        pa.id_programa,
        pa.id_plano_acao,
        COALESCE(pa.valor_custeio_plano_acao, 0)
          + COALESCE(pa.valor_investimento_plano_acao, 0) AS valor_plano_acao,
        COALESCE(emp.valor_empenhado, 0) AS valor_empenhado,
        COALESCE(doc.valor_documentado, 0) AS valor_documentado,
        COALESCE(pag.valor_pago, 0) AS valor_pago
    FROM se_api_transferencias_especiais.plano_acao_especial pa
    LEFT JOIN (
        SELECT id_plano_acao, SUM(COALESCE(valor_empenho, 0)) AS valor_empenhado
        FROM se_api_transferencias_especiais.empenho_especial
        GROUP BY id_plano_acao
    ) emp ON emp.id_plano_acao = pa.id_plano_acao
    LEFT JOIN (
        SELECT e.id_plano_acao, SUM(COALESCE(dh.valor_dh, 0)) AS valor_documentado
        FROM se_api_transferencias_especiais.empenho_especial e
        INNER JOIN se_api_transferencias_especiais.documento_habil_especial dh
            ON dh.id_empenho = e.id_empenho
        GROUP BY e.id_plano_acao
    ) doc ON doc.id_plano_acao = pa.id_plano_acao
    LEFT JOIN (
        SELECT e.id_plano_acao, SUM(COALESCE(dh.valor_dh, 0)) AS valor_pago
        FROM se_api_transferencias_especiais.empenho_especial e
        INNER JOIN se_api_transferencias_especiais.documento_habil_especial dh
            ON dh.id_empenho = e.id_empenho
        INNER JOIN se_api_transferencias_especiais.ordem_pagamento_ordem_bancaria_especial op
            ON op.id_dh = dh.id_dh
        WHERE op.numero_ordem_bancaria IS NOT NULL
          AND TRIM(op.numero_ordem_bancaria) <> ''
        GROUP BY e.id_plano_acao
    ) pag ON pag.id_plano_acao = pa.id_plano_acao
)
SELECT
    pr.id_programa,
    pr.ano_programa AS ano,
    pr.codigo_programa,
    pr.nome_orgao_programa AS orgao,
    pr.sigla_orgao_programa AS sigla_orgao,
    COUNT(DISTINCT fp.id_plano_acao) AS qtd_planos_acao,
    SUM(fp.valor_plano_acao) AS valor_autorizado_plano_acao,
    SUM(fp.valor_empenhado) AS valor_empenhado,
    SUM(fp.valor_documentado) AS valor_documentado,
    SUM(fp.valor_pago) AS valor_pago,
    SUM(fp.valor_empenhado) - SUM(fp.valor_documentado) AS saldo_a_documentar,
    SUM(fp.valor_documentado) - SUM(fp.valor_pago) AS saldo_a_pagar,
    COALESCE(pr.valor_total_disponibilizado_programa, 0) AS valor_disponibilizado_programa,
    COALESCE(pr.valor_disponibilidade_atual_programa, 0) AS valor_disponibilidade_atual
FROM se_api_transferencias_especiais.programa_especial pr
LEFT JOIN financeiro_plano fp ON fp.id_programa = pr.id_programa
GROUP BY
    pr.id_programa,
    pr.ano_programa,
    pr.codigo_programa,
    pr.nome_orgao_programa,
    pr.sigla_orgao_programa,
    pr.valor_total_disponibilizado_programa,
    pr.valor_disponibilidade_atual_programa;

COMMENT ON VIEW se_api_transferencias_especiais.vw_execucao_financeira IS
    'Execucao financeira consolidada por programa: empenhado x documentado x pago';

