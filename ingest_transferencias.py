"""
Rotina de ingestão da API Transferências Especiais do Transferegov
=================================================================
Fonte: https://api.transferegov.dth.api.gov.br/transferenciasespeciais/
Destino: campinas.cidades.gov.br / schema se_api_transferencias_especiais

Uso:
    # Carga completa de todas as tabelas
    python ingest_transferencias.py

    # Carga de uma tabela específica
    python ingest_transferencias.py --tabela programa_especial

    # Carga incremental (ultimos N dias; tabelas com campo de data na API)
    python ingest_transferencias.py --dias 7
    python ingest_transferencias.py --dias --tabela empenho_especial

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
API_PAGE_SIZE = 1000          # PostgREST: máximo de registros por página
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
        tuple(r.get(c) for c in colunas_com_carga)
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


def registrar_log(conn, tabela: str, dt_inicio: datetime, status: str,
                  lidos: int = 0, inseridos: int = 0, atualizados: int = 0, mensagem: str = ""):
    """Registra o resultado da carga na tabela de controle."""
    sql = f"""
        INSERT INTO {DB_SCHEMA}.controle_carga
            (tabela, dt_inicio, dt_fim, registros_lidos, registros_inseridos,
             registros_atualizados, status, mensagem)
        VALUES (%s, %s, NOW(), %s, %s, %s, %s, %s)
    """
    with conn.cursor() as cur:
        cur.execute(sql, (tabela, dt_inicio, lidos, inseridos, atualizados, status, mensagem))
    conn.commit()


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

def processar_tabela(conn, nome_tabela: str, config: dict, dias: int | None = None) -> tuple[bool, str]:
    """Faz o fetch da API e o upsert no banco para uma tabela."""
    dt_inicio = datetime.now()
    registros = []
    total_inseridos = 0
    modo_carga = "completa"
    log.info(f"{'='*60}")
    log.info(f"Processando tabela: {nome_tabela}")
    log.info(f"{'='*60}")

    try:
        filtros = None
        if dias is not None:
            col_data = config.get("filtro_data")
            if col_data:
                data_limite = (datetime.now() - timedelta(days=dias)).strftime("%Y-%m-%d")
                filtros = {col_data: f"gte.{data_limite}"}
                modo_carga = f"incremental ({dias} dias, {col_data} >= {data_limite})"
                log.info(f"  Carga incremental: {col_data} >= {data_limite}")
            else:
                log.info(f"  Sem campo de data na API — mantendo carga completa.")

        registros = fetch_all(nome_tabela, config["order"], filtros)

        if not registros:
            log.warning(f"  Nenhum registro retornado para '{nome_tabela}'.")
            registrar_log(conn, nome_tabela, dt_inicio, "SUCESSO", 0, 0, 0, "Nenhum registro na API")
            return True, ""

        # 2. Upsert em lotes para evitar memory overflow
        BATCH_SIZE = 5000
        for i in range(0, len(registros), BATCH_SIZE):
            lote = registros[i:i + BATCH_SIZE]
            inseridos, _ = upsert_dados(conn, nome_tabela, config["pk"], lote)
            total_inseridos += inseridos
            conn.commit()
            log.info(f"  Lote {i//BATCH_SIZE + 1}: {len(lote)} registros processados.")

        log.info(f"  OK '{nome_tabela}': {len(registros):,} registros na API, {total_inseridos:,} upserted no banco.")
        registrar_log(conn, nome_tabela, dt_inicio, "SUCESSO",
                      len(registros), total_inseridos, 0, modo_carga)
        return True, ""

    except Exception as e:
        conn.rollback()
        tb = traceback.format_exc()
        log.error(f"  ERRO em '{nome_tabela}': {e}")
        log.error(tb)
        registrar_log(conn, nome_tabela, dt_inicio, "ERRO",
                      len(registros), total_inseridos, 0, mensagem=str(e)[:2000])
        return False, tb


# ─────────────────────────────────────────────
# ORQUESTRACAO (SEQUENCIAL / PARALELA)
# ─────────────────────────────────────────────

def niveis_para_tabelas(nomes: set[str]) -> list[list[str]]:
    """Filtra NIVEIS_CARGA mantendo apenas as tabelas solicitadas e a ordem hierarquica."""
    niveis = []
    for nivel in NIVEIS_CARGA:
        filtrado = [t for t in nivel if t in nomes]
        if filtrado:
            niveis.append(filtrado)
    return niveis


def _processar_tabela_worker(nome_tabela: str, config: dict, dias: int | None) -> tuple[str, bool, str]:
    """Worker com conexao propria (psycopg2 nao e thread-safe)."""
    conn = get_connection()
    try:
        ok, erro = processar_tabela(conn, nome_tabela, config, dias)
        return nome_tabela, ok, erro
    finally:
        conn.close()


def executar_carga(
    tabelas_alvo: dict,
    dias: int | None = None,
    workers: int = 1,
) -> tuple[dict[str, str], dict[str, str]]:
    """Executa a carga respeitando niveis hierarquicos e paralelismo por nivel."""
    niveis = niveis_para_tabelas(set(tabelas_alvo.keys()))
    resultados: dict[str, str] = {}
    falhas: dict[str, str] = {}

    if workers <= 1:
        conn = get_connection()
        try:
            for i, nivel in enumerate(niveis, 1):
                log.info(f"Nivel {i}/{len(niveis)}: {', '.join(nivel)}")
                for nome in nivel:
                    ok, erro = processar_tabela(conn, nome, tabelas_alvo[nome], dias)
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
            nome, ok, erro = _processar_tabela_worker(nivel[0], tabelas_alvo[nivel[0]], dias)
            resultados[nome] = "OK" if ok else "ERRO"
            if erro:
                falhas[nome] = erro
            continue

        with ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = {
                executor.submit(_processar_tabela_worker, nome, tabelas_alvo[nome], dias): nome
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
    parser.add_argument("--tabela", help="Processa apenas esta tabela (ex: programa_especial)")
    parser.add_argument(
        "--dias",
        type=int,
        nargs="?",
        const=7,
        default=None,
        metavar="N",
        help="Carga incremental: filtra por data >= hoje-N dias (padrao: 7). "
             "Tabelas sem campo de data fazem carga completa. Ver docs/carga_incremental.md",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        metavar="N",
        help="Threads paralelas por nivel hierarquico (padrao: 4). Use 1 para sequencial.",
    )
    args = parser.parse_args()

    if args.workers < 1:
        log.error("--workers deve ser >= 1")
        sys.exit(1)

    # Seleciona quais tabelas processar
    if args.tabela:
        if args.tabela not in TABELAS:
            log.error(f"Tabela '{args.tabela}' não reconhecida. Opções: {list(TABELAS.keys())}")
            sys.exit(1)
        tabelas_alvo = {args.tabela: TABELAS[args.tabela]}
    else:
        tabelas_alvo = TABELAS

    log.info(f"Iniciando ingestão: {len(tabelas_alvo)} tabela(s)")
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

    resultados, falhas = executar_carga(tabelas_alvo, dias=args.dias, workers=args.workers)

    # Resumo final
    log.info(f"\n{'='*60}")
    log.info("RESUMO DA INGESTÃO")
    log.info(f"{'='*60}")
    sucessos = sum(1 for v in resultados.values() if v == "OK")
    for tabela in sorted(resultados.keys(), key=lambda t: list(TABELAS.keys()).index(t)):
        log.info(f"  {tabela}: {resultados[tabela]}")
    log.info(f"\nTotal: {sucessos}/{len(resultados)} tabelas com sucesso.")

    if falhas:
        enviar_alerta_email(falhas)

    if sucessos < len(resultados):
        sys.exit(1)


if __name__ == "__main__":
    main()
