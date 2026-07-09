-- =============================================================================
-- Relatorio diario de monitoramento da carga — Transferencias Especiais
-- Fonte: se_api_transferencias_especiais.controle_carga
-- Uso: executar no pgAdmin/psql conectado ao banco corporativo
-- =============================================================================

WITH tabelas_esperadas AS (
    SELECT unnest(ARRAY[
        'programa_especial',
        'plano_acao_especial',
        'empenho_especial',
        'documento_habil_especial',
        'ordem_pagamento_ordem_bancaria_especial',
        'historico_pagamento_especial',
        'relatorio_gestao_especial',
        'relatorio_gestao_novo_especial',
        'meta_especial',
        'executor_especial',
        'plano_trabalho_especial',
        'finalidade_especial',
        'plano_trabalho_analise_especial',
        'orgao_analise_pendente_especial',
        'plano_trabalho_historico_especial',
        'plano_trabalho_analise_historico_especial'
    ]) AS tabela
),

historico AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER (PARTITION BY c.tabela ORDER BY c.dt_inicio DESC) AS rn
    FROM se_api_transferencias_especiais.controle_carga c
),

ultima_carga AS (
    SELECT * FROM historico WHERE rn = 1
),

carga_anterior AS (
    SELECT * FROM historico WHERE rn = 2
),

registros_atuais AS (
    SELECT
        schemaname || '.' || relname AS tabela_full,
        relname AS tabela,
        n_live_tup AS registros_no_banco
    FROM pg_stat_user_tables
    WHERE schemaname = 'se_api_transferencias_especiais'
      AND relname <> 'controle_carga'
)

SELECT
    te.tabela,

    -- 1. Status da ultima carga
  COALESCE(u.status, 'SEM_CARGA') AS status_ultima_carga,
    u.dt_inicio AS dt_inicio_ultima,
    u.dt_fim AS dt_fim_ultima,

    -- 3. Tempo de execucao (ultima carga)
    CASE
        WHEN u.dt_inicio IS NOT NULL AND u.dt_fim IS NOT NULL
        THEN ROUND(EXTRACT(EPOCH FROM (u.dt_fim - u.dt_inicio))::numeric, 1)
    END AS duracao_segundos,

    -- 2. Registros: ultima carga vs carga anterior
    u.registros_lidos AS registros_lidos_ultima,
    a.registros_lidos AS registros_lidos_anterior,
    u.registros_lidos - COALESCE(a.registros_lidos, 0) AS delta_registros_lidos,
    ra.registros_no_banco AS registros_no_banco_agora,

    u.registros_inseridos AS registros_inseridos_ultima,
    u.mensagem AS mensagem_ultima,

    -- 4. Alertas
    CASE
        WHEN u.id IS NULL
            THEN 'ALERTA: tabela nunca carregada'
        WHEN u.status = 'ERRO'
            THEN 'ALERTA: ultima carga com ERRO'
        WHEN u.dt_inicio::date < CURRENT_DATE
            THEN 'ALERTA: sem carga hoje'
        WHEN u.status = 'EXECUTANDO'
            THEN 'ALERTA: carga em andamento'
        ELSE 'OK'
    END AS alerta,

    CASE
        WHEN u.id IS NULL THEN 1
        WHEN u.status = 'ERRO' THEN 1
        WHEN u.dt_inicio::date < CURRENT_DATE THEN 1
        WHEN u.status = 'EXECUTANDO' THEN 1
        ELSE 0
    END AS tem_alerta

FROM tabelas_esperadas te
LEFT JOIN ultima_carga u ON u.tabela = te.tabela
LEFT JOIN carga_anterior a ON a.tabela = te.tabela
LEFT JOIN registros_atuais ra ON ra.tabela = te.tabela
ORDER BY tem_alerta DESC, te.tabela;


-- =============================================================================
-- Resumo executivo (quantidade de alertas do dia)
-- =============================================================================
-- SELECT
--     COUNT(*) FILTER (WHERE tem_alerta = 1) AS tabelas_com_alerta,
--     COUNT(*) FILTER (WHERE status_ultima_carga = 'SUCESSO' AND tem_alerta = 0) AS tabelas_ok,
--     COUNT(*) AS total_tabelas
-- FROM (
--     -- cole aqui a query principal acima, ou use como VIEW
-- ) relatorio;


-- =============================================================================
-- Ultimas 20 execucoes (detalhe para investigacao)
-- =============================================================================
-- SELECT
--     tabela,
--     status,
--     dt_inicio,
--     dt_fim,
--     ROUND(EXTRACT(EPOCH FROM (dt_fim - dt_inicio))::numeric, 1) AS duracao_seg,
--     registros_lidos,
--     registros_inseridos,
--     LEFT(mensagem, 120) AS mensagem
-- FROM se_api_transferencias_especiais.controle_carga
-- ORDER BY dt_inicio DESC
-- LIMIT 20;
