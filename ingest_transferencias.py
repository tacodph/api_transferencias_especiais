"""
Rotina de ingestão da API Transferências Especiais do Transferegov
=================================================================
Fonte: https://api.transferegov.dth.api.gov.br/transferenciasespeciais/
Destino: campinas.cidades.gov.br / schema se_api_transferencias_especiais

Uso:
    # Carga completa (API nova / 20 tabelas *_especiais)
    python ingest_transferencias.py

    # Carga de uma tabela específica
    python ingest_transferencias.py --tabela programas_especiais
    python ingest_transferencias.py --tabela gestao_financeira_lancamentos_especiais

    # Carga incremental (loop diário; ver docs/carga_incremental.md)
    python ingest_transferencias.py --dias 7
    python ingest_transferencias.py --dias 7 --tabela empenhos_especiais

    # Paralelismo (respeita hierarquia; padrao: 4 workers)
    python ingest_transferencias.py --workers 4
    python ingest_transferencias.py --workers 1   # sequencial

Variáveis de ambiente (arquivo .env na raiz do projeto ou edite as constantes abaixo):
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
    SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, EMAIL_FROM, EMAIL_TO (alertas)
"""

import os
import sys
import time
import logging
import argparse
import traceback
import smtplib
from email.mime.text import MIMEText
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta

from dotenv import load_dotenv
import requests
import psycopg2

load_dotenv()
from psycopg2.extras import execute_values

# ─────────────────────────────────────────────
# CONFIGURAÇÃO
# ─────────────────────────────────────────────
API_BASE_URL = "https://api.transferegov.dth.api.gov.br/transferenciasespeciais"
API_BASE_URL_V2 = "https://api-publica.transferegov.gestao.gov.br/especiais"
API_PAGE_SIZE = 1000          # PostgREST: máximo de registros por página
API_PAGE_SIZE_V2 = 200        # API v2: máximo aceito (acima disso → HTTP 422)
API_TIMEOUT   = 60            # segundos por requisição
API_MAX_RETRIES = 3           # tentativas em caso de falha
API_RETRY_DELAY = 10          # segundos entre tentativas

DB_HOST     = os.getenv("DB_HOST",     "campinas.cidades.gov.br")
DB_PORT     = os.getenv("DB_PORT",     "5432")
DB_NAME     = os.getenv("DB_NAME",     "seu_banco")          # ajuste
DB_USER     = os.getenv("DB_USER",     "seu_usuario")        # ajuste
DB_PASSWORD = os.getenv("DB_PASSWORD", "sua_senha")          # ajuste
DB_SCHEMA   = "se_api_transferencias_especiais"

SMTP_HOST     = os.getenv("SMTP_HOST", "")
SMTP_PORT     = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER     = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
EMAIL_FROM    = os.getenv("EMAIL_FROM", SMTP_USER)
EMAIL_TO      = os.getenv("EMAIL_TO", "")
EMAIL_SUBJECT = "[ALERTA] Falha na ingestao API Transferencias Especiais"

# ─────────────────────────────────────────────
# TABELAS E SUAS CHAVES PRIMÁRIAS
# Usadas para o UPSERT (INSERT ... ON CONFLICT DO UPDATE)
# ─────────────────────────────────────────────
TABELAS = {
    "programa_especial": {
        "pk": ["id_programa"],
        "order": "id_programa",
        "filtro_data": "data_inicio_ciencia_programa",
    },
    "plano_acao_especial": {
        "pk": ["id_plano_acao"],
        "order": "id_plano_acao",
        "filtro_data": None,
    },
    "empenho_especial": {
        "pk": ["id_empenho"],
        "order": "id_empenho",
        "filtro_data": "data_emissao_empenho",
    },
    "documento_habil_especial": {
        "pk": ["id_dh"],
        "order": "id_dh",
        "filtro_data": "data_emissao_dh",
    },
    "ordem_pagamento_ordem_bancaria_especial": {
        "pk": ["id_op_ob"],
        "order": "id_op_ob",
        "filtro_data": "data_situacao_op",
    },
    "historico_pagamento_especial": {
        "pk": ["id_historico_op_ob"],
        "order": "id_historico_op_ob",
        "filtro_data": "data_hora_historico_op",
    },
    "relatorio_gestao_especial": {
        "pk": ["id_relatorio_gestao"],
        "order": "id_relatorio_gestao",
        "filtro_data": None,
    },
    "relatorio_gestao_novo_especial": {
        "pk": ["id_relatorio_gestao_novo"],
        "order": "id_relatorio_gestao_novo",
        "filtro_data": "data_e_hora_relatorio_gestao_novo",
    },
    "meta_especial": {
        "pk": ["id_executor", "id_meta"],
        "order": "id_executor,id_meta",
        "filtro_data": None,
    },
    "executor_especial": {
        "pk": ["id_plano_acao", "id_executor"],
        "order": "id_plano_acao,id_executor",
        "filtro_data": None,
    },
    "plano_trabalho_especial": {
        "pk": ["id_plano_trabalho"],
        "order": "id_plano_trabalho",
        "filtro_data": "data_inicio_execucao_plano_trabalho",
    },
    "finalidade_especial": {
        "pk": ["id_executor", "cd_area_politica_publica_tipo_pt", "cd_area_politica_publica_pt"],
        "order": "id_executor",
        "filtro_data": None,
    },
    "plano_trabalho_analise_especial": {
        "pk": ["id_plano_trabalho_analise"],
        "order": "id_plano_trabalho_analise",
        "filtro_data": "data_analise_pt",
    },
    "orgao_analise_pendente_especial": {
        "pk": ["id_plano_trabalho", "id_orgao_analise_pendente_pt"],
        "order": "id_plano_trabalho",
        "filtro_data": None,
    },
    "plano_trabalho_historico_especial": {
        "pk": ["id_plano_trabalho_hist", "id_plano_trabalho"],
        "order": "id_plano_trabalho_hist",
        "filtro_data": "data_plano_trabalho_hist",
    },
    "plano_trabalho_analise_historico_especial": {
        "pk": ["id_plano_trabalho_analise", "codigo_siorg_orgao_analise_pt_hist", "data_analise_pt_hist"],
        "order": "id_plano_trabalho_analise",
        "filtro_data": "data_analise_pt_hist",
    },
}

# Niveis de carga paralela (tabelas do mesmo nivel podem rodar juntas)
NIVEIS_CARGA = [
    ["programa_especial"],
    ["plano_acao_especial"],
    [
        "empenho_especial",
        "relatorio_gestao_especial",
        "relatorio_gestao_novo_especial",
        "executor_especial",
    ],
    ["documento_habil_especial", "meta_especial", "finalidade_especial"],
    ["ordem_pagamento_ordem_bancaria_especial", "plano_trabalho_especial"],
    [
        "historico_pagamento_especial",
        "plano_trabalho_analise_especial",
        "plano_trabalho_historico_especial",
        "orgao_analise_pendente_especial",
    ],
    ["plano_trabalho_analise_historico_especial"],
]

# ─────────────────────────────────────────────
# TABELAS v2 (API nova) — nomes = tabelas no XML/banco
# endpoint: path na API quando diferente do nome da tabela
# pk / filtro_data: docs/prompt1_mapa_e_chaves_v2.md e docs/carga_incremental.md
# ─────────────────────────────────────────────
TABELAS_V2 = {
    "programas_especiais": {
        "pk": ["id_programa"],
        "order": "id_programa",
        "filtro_data": "data_inicio_ciencia_programa",
        "endpoint": "programas_especiais",
    },
    "beneficiarios_especiais": {
        "pk": ["id_beneficiario"],
        "order": "id_beneficiario",
        "filtro_data": None,
        "endpoint": "beneficiarios_especiais",
    },
    "planos_acao_especiais": {
        "pk": ["id_plano_acao"],
        "order": "id_plano_acao",
        "filtro_data": "data_aceite_plano_acao",
        "endpoint": "planos_acao_especiais",
    },
    "planos_acao_historico_especiais": {
        "pk": ["id_historico_plano_acao"],
        "order": "id_historico_plano_acao",
        "filtro_data": "data_hora_historico_plano_acao",
        "endpoint": "planos_acao_historico_especiais",
    },
    "empenhos_especiais": {
        "pk": ["id_empenho"],
        "order": "id_empenho",
        "filtro_data": "data_emissao_empenho",
        "endpoint": "empenhos_especiais",
    },
    "documentos_habeis_especiais": {
        "pk": ["id_dh"],
        "order": "id_dh",
        "filtro_data": "data_emissao_dh",
        "endpoint": "documentos_habeis_especiais",
    },
    "ordens_pagamentos_ordens_bancarias_especiais": {
        "pk": ["id_op_ob"],
        "order": "id_op_ob",
        "filtro_data": "data_situacao_op",
        "endpoint": "ordens_pagamentos_ordens_bancarias_especiais",
    },
    "relatorios_gestao_especiais": {
        "pk": ["id_relatorio_gestao"],
        "order": "id_relatorio_gestao",
        "filtro_data": "data_relatorio_gestao",
        "endpoint": "relatorios_gestao_especiais",
    },
    "relatorios_gestao_novos_especiais": {
        "pk": ["id_relatorio_gestao_novo"],
        "order": "id_relatorio_gestao_novo",
        "filtro_data": "data_relatorio_gestao_novo",
        "endpoint": "relatorios_gestao_novos_especiais",
    },
    "executor_especiais": {
        "pk": ["id_plano_acao", "id_executor"],
        "order": "id_plano_acao,id_executor",
        "filtro_data": None,
        "endpoint": "executores_especiais",
    },
    "meta_especiais": {
        "pk": ["id_meta"],
        "order": "id_meta",
        "filtro_data": None,
        "endpoint": "meta_especiais",
    },
    "finalidade_pt_especiais": {
        "pk": [
            "id_executor",
            "cd_area_politica_publica_tipo_pt",
            "cd_area_politica_publica_pt",
        ],
        "order": "id_executor",
        "filtro_data": None,
        "endpoint": "finalidade_especiais",
    },
    "planos_trabalho_especiais": {
        "pk": ["id_plano_trabalho"],
        "order": "id_plano_trabalho",
        "filtro_data": "data_inicio_execucao_plano_trabalho",
        "endpoint": "planos_trabalho_especiais",
    },
    "planos_trabalho_analises_especiais": {
        "pk": ["id_plano_trabalho_analise_pt"],
        "order": "id_plano_trabalho_analise_pt",
        "filtro_data": "data_analise_pt",
        "endpoint": "planos_trabalho_analises_especiais",
    },
    "orgaos_analises_pendentes_especiais": {
        "pk": ["id_plano_trabalho", "id_orgao_analise_pendente_pt"],
        "order": "id_plano_trabalho",
        "filtro_data": None,
        "endpoint": "orgaos_analises_pendentes_especiais",
    },
    "pt_historico_especiais": {
        "pk": ["id_plano_trabalho_hist"],
        "order": "id_plano_trabalho_hist",
        "filtro_data": "data_plano_trabalho_hist",
        "endpoint": "planos_trabalho_historico",
    },
    "pt_analise_historico_especiais": {
        "pk": [
            "id_plano_trabalho_analise_pt",
            "codigo_siorg_orgao_analise_pt_hist",
            "data_analise_pt_hist",
        ],
        "order": "id_plano_trabalho_analise_pt",
        "filtro_data": "data_analise_pt_hist",
        "endpoint": "plano_trabalho_analise_historico_especiais",
    },
    "gestao_financeira_lancamentos_especiais": {
        "pk": ["id_lancamento_gestao_financeira"],
        "order": "id_lancamento_gestao_financeira",
        "filtro_data": "data_lancamento_gestao_financeira",
        "endpoint": "gestao_financeira_lancamentos_especiais",
    },
    "gestao_financeira_subtransacoes_especiais": {
        "pk": ["id_subtransacao_gestao_financeira"],
        "order": "id_subtransacao_gestao_financeira",
        "filtro_data": "data_pagamento_subtransacao_gestao_financeira",
        "endpoint": "gestao_financeira_subtransacoes_especiais",
    },
    "saldo_conta_gestao_financeira_especiais": {
        "pk": ["id_agencia_conta"],
        "order": "id_agencia_conta",
        "filtro_data": "data_saldo_conta",
        "endpoint": "saldo_conta_gestao_financeira_especiais",
    },
}

# Hierarquia v2: beneficiarios antes de planos_acao; gestao financeira em ramo paralelo
NIVEIS_CARGA_V2 = [
    [
        "programas_especiais",
        "beneficiarios_especiais",
        "saldo_conta_gestao_financeira_especiais",
    ],
    [
        "planos_acao_especiais",
        "gestao_financeira_lancamentos_especiais",
    ],
    [
        "planos_acao_historico_especiais",
        "empenhos_especiais",
        "relatorios_gestao_especiais",
        "relatorios_gestao_novos_especiais",
        "executor_especiais",
        "gestao_financeira_subtransacoes_especiais",
    ],
    [
        "documentos_habeis_especiais",
        "meta_especiais",
        "finalidade_pt_especiais",
    ],
    [
        "ordens_pagamentos_ordens_bancarias_especiais",
        "planos_trabalho_especiais",
    ],
    [
        "planos_trabalho_analises_especiais",
        "pt_historico_especiais",
        "orgaos_analises_pendentes_especiais",
    ],
    ["pt_analise_historico_especiais"],
]

# ─────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f"ingest_{datetime.now():%Y%m%d_%H%M%S}.log"),
    ],
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# FUNÇÕES DE API (PostgREST)
# ─────────────────────────────────────────────

def _make_request(endpoint: str, params: dict, tentativa: int = 1) -> list:
    """Faz uma requisição GET com retry automático."""
    url = f"{API_BASE_URL}/{endpoint}"
    headers = {
        "Accept": "application/json",
        "Prefer": "count=exact",  # retorna total no header Content-Range
    }
    try:
        resp = requests.get(url, params=params, headers=headers, timeout=API_TIMEOUT)
        resp.raise_for_status()
        return resp.json(), resp.headers.get("Content-Range", "")
    except requests.RequestException as e:
        if tentativa < API_MAX_RETRIES:
            log.warning(f"  Tentativa {tentativa}/{API_MAX_RETRIES} falhou: {e}. Aguardando {API_RETRY_DELAY}s...")
            time.sleep(API_RETRY_DELAY)
            return _make_request(endpoint, params, tentativa + 1)
        raise


def fetch_all(tabela: str, order_col: str, filtros: dict | None = None) -> list:
    """
    Busca registros de uma tabela usando paginação PostgREST.
    filtros: dict opcional com filtros PostgREST (ex: {"data_emissao_empenho": "gte.2026-06-10"}).
    """
    todos = []
    offset = 0
    total = None

    modo = "incremental" if filtros else "completa"
    log.info(f"  Iniciando fetch de '{tabela}' (carga {modo})...")

    while True:
        params = {
            "order": order_col,
            "limit": API_PAGE_SIZE,
            "offset": offset,
        }
        if filtros:
            params.update(filtros)

        dados, content_range = _make_request(tabela, params)

        if not dados:
            break

        todos.extend(dados)

        # Extrai total do header Content-Range: "0-999/12345"
        if total is None and "/" in content_range:
            try:
                total = int(content_range.split("/")[1])
                log.info(f"  Total de registros em '{tabela}': {total:,}")
            except (ValueError, IndexError):
                pass

        offset += len(dados)
        log.info(f"  Carregados {offset:,} registros de '{tabela}'...")

        if len(dados) < API_PAGE_SIZE:
            break

    log.info(f"  Fetch concluído: {len(todos):,} registros de '{tabela}'.")
    return todos


# ─────────────────────────────────────────────
# FUNÇÕES DE API v2 (envelope pagina/tamanho_da_pagina)
# Decisão --dias: loop diário com igualdade YYYY-MM-DD
# (docs/carga_incremental.md — seção API v2)
# ─────────────────────────────────────────────

def _make_request_v2(endpoint: str, params: dict, tentativa: int = 1) -> dict:
    """
    GET contra API_BASE_URL_V2 com retry/backoff.
    Retorna o envelope JSON (data/total_pages/total_items/page_number/page_size).
    """
    url = f"{API_BASE_URL_V2}/{endpoint}"
    headers = {"Accept": "application/json"}
    try:
        resp = requests.get(url, params=params, headers=headers, timeout=API_TIMEOUT)
        resp.raise_for_status()
        body = resp.json()
        if not isinstance(body, dict) or "data" not in body:
            raise ValueError(
                f"Resposta inesperada de '{endpoint}': envelope sem chave 'data'."
            )
        return body
    except (requests.RequestException, ValueError) as e:
        if tentativa < API_MAX_RETRIES:
            log.warning(
                f"  [v2] Tentativa {tentativa}/{API_MAX_RETRIES} falhou: {e}. "
                f"Aguardando {API_RETRY_DELAY}s..."
            )
            time.sleep(API_RETRY_DELAY)
            return _make_request_v2(endpoint, params, tentativa + 1)
        raise


def fetch_all_v2(endpoint: str, filtros: dict | None = None) -> list:
    """
    Busca todos os registros de um endpoint v2 paginando pelo envelope.
    filtros: igualdade exata (ex: {"data_emissao_empenho": "2026-07-01"}).
    Sem suporte a gte./intervalo — use fetch_janela_diaria_v2 para --dias.
    """
    todos: list = []
    pagina = 1
    total_items = None
    total_pages = None

    modo = "filtrada" if filtros else "completa"
    log.info(f"  [v2] Iniciando fetch de '{endpoint}' (carga {modo})...")

    while True:
        params = {
            "pagina": pagina,
            "tamanho_da_pagina": API_PAGE_SIZE_V2,
        }
        if filtros:
            params.update(filtros)

        body = _make_request_v2(endpoint, params)
        dados = body.get("data") or []

        if total_items is None:
            total_items = body.get("total_items")
            total_pages = body.get("total_pages")
            if total_items is not None:
                log.info(
                    f"  [v2] Total em '{endpoint}': {total_items:,} "
                    f"({total_pages} página(s))"
                )

        if not dados:
            break

        todos.extend(dados)
        page_number = body.get("page_number") or pagina
        log.info(
            f"  [v2] Página {page_number}/{total_pages or '?'}: "
            f"{len(todos):,} registros acumulados de '{endpoint}'..."
        )

        if total_pages is not None and page_number >= total_pages:
            break
        if len(dados) < API_PAGE_SIZE_V2 and total_pages is None:
            break

        pagina += 1

    if total_items is not None and len(todos) != total_items:
        log.warning(
            f"  [v2] Contagem divergente em '{endpoint}': "
            f"fetched={len(todos):,} total_items={total_items:,}"
        )
    else:
        log.info(f"  [v2] Fetch concluído: {len(todos):,} registros de '{endpoint}'.")
    return todos


def fetch_janela_diaria_v2(
    endpoint: str,
    campo_data: str,
    dias: int,
    pk_cols: list | None = None,
) -> list:
    """
    Carga incremental v2: para cada dia em [hoje-dias, hoje], filtra com
    campo_data=YYYY-MM-DD (igualdade), une e deduplica pela PK se informada.
    """
    if dias < 0:
        raise ValueError("dias deve ser >= 0")

    hoje = datetime.now().date()
    inicio = hoje - timedelta(days=dias)
    log.info(
        f"  [v2] Janela diária em '{endpoint}': {campo_data} "
        f"de {inicio} a {hoje} ({dias} dia(s) + hoje)"
    )

    todos: list = []
    dia = inicio
    while dia <= hoje:
        data_str = dia.strftime("%Y-%m-%d")
        lote = fetch_all_v2(endpoint, filtros={campo_data: data_str})
        log.info(f"  [v2] {data_str}: {len(lote):,} registro(s)")
        todos.extend(lote)
        dia += timedelta(days=1)

    if pk_cols:
        antes = len(todos)
        todos, removidos = deduplicar_por_pk(todos, pk_cols)
        if removidos:
            log.warning(
                f"  [v2] Deduplicados {removidos} registro(s) na janela "
                f"({antes:,} → {len(todos):,})."
            )

    log.info(
        f"  [v2] Janela diária concluída: {len(todos):,} registros de '{endpoint}'."
    )
    return todos


# ─────────────────────────────────────────────
# FUNÇÕES DE BANCO DE DADOS
# ─────────────────────────────────────────────

def get_connection():
    """Cria e retorna uma conexão com o banco corporativo."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=30,
    )


def deduplicar_por_pk(registros: list, pk_cols: list) -> tuple[list, int]:
    """Remove registros com PK duplicada, mantendo a última ocorrência."""
    unicos = {}
    for r in registros:
        unicos[tuple(r.get(c) for c in pk_cols)] = r
    removidos = len(registros) - len(unicos)
    return list(unicos.values()), removidos


def _normalizar_valor_api(valor):
    """
    A API nova mascara dados sensíveis com '***' (ou variantes).
    Mantém a máscara como texto; não tenta forçar conversão numérica aqui.
    """
    if isinstance(valor, str) and valor.strip("*") == "" and "*" in valor:
        return valor.strip() or "***"
    return valor


def upsert_dados(conn, tabela: str, pk_cols: list, registros: list) -> tuple[int, int]:
    """
    Insere ou atualiza registros usando INSERT ... ON CONFLICT DO UPDATE.
    Retorna (inseridos, atualizados) — nota: o PostgreSQL não diferencia facilmente,
    então retornamos (total_upserted, 0) para simplificar.
    """
    if not registros:
        return 0, 0

    registros, removidos = deduplicar_por_pk(registros, pk_cols)
    if removidos > 0:
        log.warning(f"  Deduplicados {removidos} registros com PK repetida em '{tabela}'.")

    if not registros:
        return 0, 0

    # Descobre as colunas a partir do primeiro registro
    colunas = list(registros[0].keys())

    # Adiciona dt_carga
    agora = datetime.now()
    for r in registros:
        r["dt_carga"] = agora
    colunas_com_carga = colunas + ["dt_carga"]

    # Monta os valores
    valores = [
        tuple(_normalizar_valor_api(r.get(c)) for c in colunas_com_carga)
        for r in registros
    ]

    # Monta a cláusula SET para atualização (exclui PKs)
    set_cols = [c for c in colunas if c not in pk_cols]
    set_clause = ", ".join(f"{c} = EXCLUDED.{c}" for c in set_cols + ["dt_carga"])

    sql = f"""
        INSERT INTO {DB_SCHEMA}.{tabela} ({', '.join(colunas_com_carga)})
        VALUES %s
        ON CONFLICT ({', '.join(pk_cols)})
        DO UPDATE SET {set_clause}
    """

    with conn.cursor() as cur:
        execute_values(cur, sql, valores, page_size=500)
        return cur.rowcount, 0


def iniciar_controle_dia(conn, log_arquivo: str | None = None) -> int:
    """Abre um registro em controle_carga_dia e retorna o id."""
    sql_seq = f"""
        SELECT COALESCE(MAX(seq_execucao_dia), 0) + 1
        FROM {DB_SCHEMA}.controle_carga_dia
        WHERE dt_carga = CURRENT_DATE
    """
    sql_ins = f"""
        INSERT INTO {DB_SCHEMA}.controle_carga_dia
            (dt_carga, seq_execucao_dia, dt_inicio, status, log_arquivo)
        VALUES (CURRENT_DATE, %s, NOW(), 'EXECUTANDO', %s)
        RETURNING id
    """
    with conn.cursor() as cur:
        cur.execute(sql_seq)
        seq = cur.fetchone()[0]
        cur.execute(sql_ins, (seq, log_arquivo))
        id_dia = cur.fetchone()[0]
    conn.commit()
    log.info(f"Controle dia id={id_dia} seq={seq} iniciado.")
    return id_dia


def iniciar_controle_endpoint(
    conn,
    id_controle_carga_dia: int | None,
    endpoint: str,
) -> int:
    """Insere linha EXECUTANDO em controle_carga e retorna o id."""
    sql = f"""
        INSERT INTO {DB_SCHEMA}.controle_carga
            (id_controle_carga_dia, endpoint, dt_inicio, status)
        VALUES (%s, %s, NOW(), 'EXECUTANDO')
        RETURNING id
    """
    with conn.cursor() as cur:
        cur.execute(sql, (id_controle_carga_dia, endpoint))
        id_ctrl = cur.fetchone()[0]
    conn.commit()
    return id_ctrl


def finalizar_controle_endpoint(
    conn,
    id_controle: int,
    status: str,
    total_registros: int = 0,
    inseridos: int = 0,
    atualizados: int = 0,
    mensagem: str = "",
):
    """Atualiza o registro de controle do endpoint ao final da carga."""
    sql = f"""
        UPDATE {DB_SCHEMA}.controle_carga
        SET dt_fim = NOW(),
            status = %s,
            total_registros = %s,
            qtd_registros_inseridos = %s,
            qtd_registros_atualizados = %s,
            mensagem = %s
        WHERE id = %s
    """
    with conn.cursor() as cur:
        cur.execute(
            sql,
            (status, total_registros, inseridos, atualizados, mensagem[:4000] if mensagem else None, id_controle),
        )
    conn.commit()


def finalizar_controle_dia(
    conn,
    id_controle_carga_dia: int,
    resultados: dict[str, str],
    mensagem: str = "",
):
    """Fecha o controle_carga_dia com totais derivados dos resultados."""
    carregados = sum(1 for v in resultados.values() if v == "OK")
    erros = sum(1 for v in resultados.values() if v == "ERRO")
    total = len(resultados)
    if erros == 0:
        status = "SUCESSO"
    elif carregados == 0:
        status = "ERRO"
    else:
        status = "PARCIAL"

    sql = f"""
        UPDATE {DB_SCHEMA}.controle_carga_dia
        SET dt_fim = NOW(),
            status = %s,
            qtd_arquivos_extraidos = %s,
            qtd_arquivos_carregados = %s,
            qtd_arquivos_erro = %s,
            qtd_arquivos_pulados = 0,
            mensagem = %s
        WHERE id = %s
    """
    with conn.cursor() as cur:
        cur.execute(
            sql,
            (status, total, carregados, erros, mensagem or None, id_controle_carga_dia),
        )
    conn.commit()
    log.info(
        f"Controle dia id={id_controle_carga_dia} finalizado: "
        f"status={status} ok={carregados} erro={erros}"
    )


def registrar_log(conn, tabela: str, dt_inicio: datetime, status: str,
                  lidos: int = 0, inseridos: int = 0, atualizados: int = 0, mensagem: str = "",
                  id_controle_carga_dia: int | None = None,
                  id_controle: int | None = None,
                  endpoint: str | None = None):
    """
    Compatibilidade: se id_controle já existe, finaliza; senão insere linha completa.
    Preferir iniciar_controle_endpoint + finalizar_controle_endpoint.
    """
    nome_endpoint = endpoint or tabela
    if id_controle is not None:
        finalizar_controle_endpoint(
            conn, id_controle, status, lidos, inseridos, atualizados, mensagem
        )
        return id_controle

    sql = f"""
        INSERT INTO {DB_SCHEMA}.controle_carga
            (id_controle_carga_dia, endpoint, dt_inicio, dt_fim, status,
             total_registros, qtd_registros_inseridos, qtd_registros_atualizados, mensagem)
        VALUES (%s, %s, %s, NOW(), %s, %s, %s, %s, %s)
        RETURNING id
    """
    with conn.cursor() as cur:
        cur.execute(
            sql,
            (
                id_controle_carga_dia,
                nome_endpoint,
                dt_inicio,
                status,
                lidos,
                inseridos,
                atualizados,
                mensagem or None,
            ),
        )
        new_id = cur.fetchone()[0]
    conn.commit()
    return new_id


# ─────────────────────────────────────────────
# ALERTAS POR E-MAIL
# ─────────────────────────────────────────────

def enviar_alerta_email(falhas: dict[str, str]) -> bool:
    """Envia e-mail com tabelas que falharam. Retorna True se enviado."""
    if not falhas:
        return False

    if not SMTP_HOST or not EMAIL_TO:
        log.warning(
            "Falha(s) na ingestao, mas SMTP_HOST ou EMAIL_TO nao configurados — e-mail nao enviado."
        )
        return False

    destinatarios = [e.strip() for e in EMAIL_TO.split(",") if e.strip()]
    if not destinatarios:
        log.warning("EMAIL_TO vazio — e-mail de alerta nao enviado.")
        return False

    linhas = [
        "Falha na ingestao da API Transferencias Especiais do Transferegov.",
        f"Data/hora: {datetime.now():%Y-%m-%d %H:%M:%S}",
        f"Destino: {DB_HOST}/{DB_NAME} schema={DB_SCHEMA}",
        "",
        f"Tabelas com erro ({len(falhas)}):",
        "",
    ]
    for tabela, detalhe in sorted(falhas.items()):
        linhas.append(f"--- {tabela} ---")
        linhas.append(detalhe.strip())
        linhas.append("")

    corpo = "\n".join(linhas)
    msg = MIMEText(corpo, "plain", "utf-8")
    msg["Subject"] = EMAIL_SUBJECT
    msg["From"] = EMAIL_FROM or SMTP_USER
    msg["To"] = ", ".join(destinatarios)

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
            server.ehlo()
            if SMTP_PORT == 587:
                server.starttls()
                server.ehlo()
            if SMTP_USER and SMTP_PASSWORD:
                server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(msg["From"], destinatarios, msg.as_string())
        log.info(f"E-mail de alerta enviado para: {', '.join(destinatarios)}")
        return True
    except Exception:
        log.exception("Falha ao enviar e-mail de alerta:")
        return False


# ─────────────────────────────────────────────
# PROCESSAMENTO DE UMA TABELA
# ─────────────────────────────────────────────

def processar_tabela(
    conn,
    nome_tabela: str,
    config: dict,
    dias: int | None = None,
    api_v2: bool = False,
    id_controle_carga_dia: int | None = None,
) -> tuple[bool, str]:
    """Faz o fetch da API e o upsert no banco para uma tabela."""
    dt_inicio = datetime.now()
    registros = []
    total_inseridos = 0
    modo_carga = "completa"
    endpoint_ctrl = config.get("endpoint", nome_tabela) if api_v2 else nome_tabela
    id_controle = iniciar_controle_endpoint(conn, id_controle_carga_dia, endpoint_ctrl)

    log.info(f"{'='*60}")
    log.info(f"Processando tabela: {nome_tabela}" + (" [v2]" if api_v2 else ""))
    log.info(f"{'='*60}")

    try:
        if api_v2:
            endpoint = config.get("endpoint", nome_tabela)
            col_data = config.get("filtro_data")
            if dias is not None and col_data:
                modo_carga = (
                    f"incremental v2 ({dias} dias, loop diario {col_data})"
                )
                log.info(f"  Carga incremental v2: {col_data} dia a dia ({dias} dias)")
                registros = fetch_janela_diaria_v2(
                    endpoint, col_data, dias, pk_cols=config["pk"]
                )
            else:
                if dias is not None:
                    log.info("  Sem campo de data na API — mantendo carga completa.")
                registros = fetch_all_v2(endpoint)
                modo_carga = "completa v2"
        else:
            filtros = None
            if dias is not None:
                col_data = config.get("filtro_data")
                if col_data:
                    data_limite = (datetime.now() - timedelta(days=dias)).strftime("%Y-%m-%d")
                    filtros = {col_data: f"gte.{data_limite}"}
                    modo_carga = f"incremental ({dias} dias, {col_data} >= {data_limite})"
                    log.info(f"  Carga incremental: {col_data} >= {data_limite}")
                else:
                    log.info("  Sem campo de data na API — mantendo carga completa.")

            registros = fetch_all(nome_tabela, config["order"], filtros)

        if not registros:
            log.warning(f"  Nenhum registro retornado para '{nome_tabela}'.")
            finalizar_controle_endpoint(
                conn, id_controle, "SUCESSO", 0, 0, 0, "Nenhum registro na API"
            )
            return True, ""

        # Upsert em lotes para evitar memory overflow
        BATCH_SIZE = 5000
        for i in range(0, len(registros), BATCH_SIZE):
            lote = registros[i:i + BATCH_SIZE]
            inseridos, _ = upsert_dados(conn, nome_tabela, config["pk"], lote)
            total_inseridos += inseridos
            conn.commit()
            log.info(f"  Lote {i//BATCH_SIZE + 1}: {len(lote)} registros processados.")

        log.info(
            f"  OK '{nome_tabela}': {len(registros):,} registros na API, "
            f"{total_inseridos:,} upserted no banco."
        )
        finalizar_controle_endpoint(
            conn,
            id_controle,
            "SUCESSO",
            len(registros),
            total_inseridos,
            0,
            modo_carga,
        )
        return True, ""

    except Exception as e:
        conn.rollback()
        tb = traceback.format_exc()
        log.error(f"  ERRO em '{nome_tabela}': {e}")
        log.error(tb)
        try:
            finalizar_controle_endpoint(
                conn,
                id_controle,
                "ERRO",
                len(registros),
                total_inseridos,
                0,
                str(e)[:2000],
            )
        except Exception:
            log.exception("Falha ao registrar ERRO no controle_carga")
        return False, tb


# ─────────────────────────────────────────────
# ORQUESTRACAO (SEQUENCIAL / PARALELA)
# ─────────────────────────────────────────────

def niveis_para_tabelas(
    nomes: set[str],
    niveis_carga: list[list[str]] | None = None,
) -> list[list[str]]:
    """Filtra niveis de carga mantendo apenas as tabelas solicitadas e a ordem hierarquica."""
    base = niveis_carga if niveis_carga is not None else NIVEIS_CARGA
    niveis = []
    for nivel in base:
        filtrado = [t for t in nivel if t in nomes]
        if filtrado:
            niveis.append(filtrado)
    return niveis


def _processar_tabela_worker(
    nome_tabela: str,
    config: dict,
    dias: int | None,
    api_v2: bool = False,
    id_controle_carga_dia: int | None = None,
) -> tuple[str, bool, str]:
    """Worker com conexao propria (psycopg2 nao e thread-safe)."""
    conn = get_connection()
    try:
        ok, erro = processar_tabela(
            conn,
            nome_tabela,
            config,
            dias,
            api_v2=api_v2,
            id_controle_carga_dia=id_controle_carga_dia,
        )
        return nome_tabela, ok, erro
    finally:
        conn.close()


def executar_carga(
    tabelas_alvo: dict,
    dias: int | None = None,
    workers: int = 1,
    api_v2: bool = False,
    id_controle_carga_dia: int | None = None,
) -> tuple[dict[str, str], dict[str, str]]:
    """Executa a carga respeitando niveis hierarquicos e paralelismo por nivel."""
    niveis_def = NIVEIS_CARGA_V2 if api_v2 else NIVEIS_CARGA
    niveis = niveis_para_tabelas(set(tabelas_alvo.keys()), niveis_def)
    resultados: dict[str, str] = {}
    falhas: dict[str, str] = {}

    if workers <= 1:
        conn = get_connection()
        try:
            for i, nivel in enumerate(niveis, 1):
                log.info(f"Nivel {i}/{len(niveis)}: {', '.join(nivel)}")
                for nome in nivel:
                    ok, erro = processar_tabela(
                        conn,
                        nome,
                        tabelas_alvo[nome],
                        dias,
                        api_v2=api_v2,
                        id_controle_carga_dia=id_controle_carga_dia,
                    )
                    resultados[nome] = "OK" if ok else "ERRO"
                    if erro:
                        falhas[nome] = erro
        finally:
            conn.close()
        return resultados, falhas

    for i, nivel in enumerate(niveis, 1):
        n_workers = min(workers, len(nivel))
        log.info(
            f"Nivel {i}/{len(niveis)}: {len(nivel)} tabela(s), "
            f"{n_workers} worker(s) — {', '.join(nivel)}"
        )
        if len(nivel) == 1:
            nome, ok, erro = _processar_tabela_worker(
                nivel[0],
                tabelas_alvo[nivel[0]],
                dias,
                api_v2=api_v2,
                id_controle_carga_dia=id_controle_carga_dia,
            )
            resultados[nome] = "OK" if ok else "ERRO"
            if erro:
                falhas[nome] = erro
            continue

        with ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = {
                executor.submit(
                    _processar_tabela_worker,
                    nome,
                    tabelas_alvo[nome],
                    dias,
                    api_v2,
                    id_controle_carga_dia,
                ): nome
                for nome in nivel
            }
            for future in as_completed(futures):
                nome, ok, erro = future.result()
                resultados[nome] = "OK" if ok else "ERRO"
                if erro:
                    falhas[nome] = erro

    return resultados, falhas


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Ingestão API Transferências Especiais → Banco Corporativo")
    parser.add_argument(
        "--tabela",
        help="Processa apenas esta tabela (ex: programas_especiais, empenhos_especiais)",
    )
    parser.add_argument(
        "--dias",
        type=int,
        nargs="?",
        const=7,
        default=None,
        metavar="N",
        help="Carga incremental: loop diario com igualdade YYYY-MM-DD (padrao: 7). "
             "Tabelas sem campo de data fazem carga completa. Ver docs/carga_incremental.md",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        metavar="N",
        help="Threads paralelas por nivel hierarquico (padrao: 4). Use 1 para sequencial.",
    )
    parser.add_argument(
        "--v2",
        action="store_true",
        help=argparse.SUPPRESS,  # compatibilidade; o modelo novo e o padrao
    )
    args = parser.parse_args()

    if args.workers < 1:
        log.error("--workers deve ser >= 1")
        sys.exit(1)

    # Modelo atual (API publica + tabelas *_especiais)
    catalogo = TABELAS_V2
    ordem_resumo = list(catalogo.keys())
    api_v2 = True

    # Seleciona quais tabelas processar
    if args.tabela:
        if args.tabela not in catalogo:
            log.error(
                f"Tabela '{args.tabela}' não reconhecida. Opções: {list(catalogo.keys())}"
            )
            sys.exit(1)
        tabelas_alvo = {args.tabela: catalogo[args.tabela]}
    else:
        tabelas_alvo = catalogo

    log.info(f"Iniciando ingestão: {len(tabelas_alvo)} tabela(s)")
    log.info(f"API: {API_BASE_URL_V2}")
    log.info(f"Destino: {DB_HOST}/{DB_NAME} schema={DB_SCHEMA}")
    log.info(f"Workers: {args.workers} ({'sequencial' if args.workers == 1 else 'paralelo por nivel'})")

    if args.dias is not None:
        log.info(f"Modo incremental ativo: ultimos {args.dias} dia(s)")

    try:
        log.info("Testando conexao com o banco...")
        _test = get_connection()
        _test.close()
        log.info("Conexao com o banco estabelecida.")
    except Exception as e:
        log.exception(f"Falha ao conectar ao banco: {e}")
        enviar_alerta_email({"conexao_banco": traceback.format_exc()})
        sys.exit(1)

    # Nome do arquivo de log do FileHandler, se houver
    log_arquivo = None
    for h in log.handlers:
        if isinstance(h, logging.FileHandler):
            log_arquivo = getattr(h, "baseFilename", None)
            break

    conn_ctrl = get_connection()
    try:
        id_dia = iniciar_controle_dia(conn_ctrl, log_arquivo=log_arquivo)
    finally:
        conn_ctrl.close()

    resultados, falhas = executar_carga(
        tabelas_alvo,
        dias=args.dias,
        workers=args.workers,
        api_v2=api_v2,
        id_controle_carga_dia=id_dia,
    )

    conn_ctrl = get_connection()
    try:
        finalizar_controle_dia(conn_ctrl, id_dia, resultados)
    finally:
        conn_ctrl.close()

    # Resumo final
    log.info(f"\n{'='*60}")
    log.info("RESUMO DA INGESTÃO")
    log.info(f"{'='*60}")
    sucessos = sum(1 for v in resultados.values() if v == "OK")
    for tabela in sorted(resultados.keys(), key=lambda t: ordem_resumo.index(t)):
        log.info(f"  {tabela}: {resultados[tabela]}")
    log.info(f"\nTotal: {sucessos}/{len(resultados)} tabelas com sucesso.")

    if falhas:
        enviar_alerta_email(falhas)

    if sucessos < len(resultados):
        sys.exit(1)


if __name__ == "__main__":
    main()
