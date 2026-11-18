"""
Parlamentar das transferências especiais, identificado pelo código do autor
==========================================================================
`planos_acao_especiais.codigo_parlamentar_emenda_plano_acao` é o mesmo código
de autor das emendas do Transferegov (no siconv, left(nr_emenda, 4)). O
parlamentar fica nas tabelas que a carga de emendas (carga_arquivos_transferegov)
mantém em transfere_pro_transferegov: tab_autores_emendas, tab_parlamentares e
tab_parlamentares_alias. Aqui só entram códigos que lá ainda não existem (ou
existem sem nome) e as grafias de nome vistas nesta fonte; o nome do siconv
continua valendo.

Consulta: se_api_transferencias_especiais.vw_emendas_especiais_parlamentar
(data/09_hash_inativacao_parlamentar.sql). Junte pelo cod_autor/id_parlamentar,
nunca pelo nome.

Uso isolado:
    python ingest_transferencias.py --parlamentares
"""

import logging
import re
import unicodedata

from psycopg2.extras import execute_values

log = logging.getLogger(__name__)

TABELA_ORIGEM = "planos_acao_especiais"
ESQUEMA_PARLAMENTAR = "transfere_pro_transferegov"
ORIGEM = "especiais"
CHAVE_TRAVA = 7465100  # pg_advisory_xact_lock comum às cargas que gravam parlamentar (emendas, especiais, faf)


def normalizar_nome(valor):
    """Upper, sem acento, só letras/dígitos e espaço simples (igual ao da carga de emendas)."""
    if not valor:
        return ""
    texto = unicodedata.normalize("NFKD", valor).encode("ascii", "ignore").decode()
    texto = re.sub(r"[^A-Z0-9 ]", " ", texto.upper())
    return re.sub(r"\s+", " ", texto).strip()


def cod_autor(codigo):
    """1331 -> '1331'; 42 -> '0042'; fora de 0..9999 ou vazio -> None (mesma regra da view)."""
    if codigo is None:
        return None
    try:
        valor = int(codigo)
    except (TypeError, ValueError):
        return None
    return f"{valor:04d}" if 0 <= valor <= 9999 else None


# Mesma lógica de _sync_autores/_sync_alias_apoiadores da carga de emendas, no modo "fonte secundária".
_PASSOS = (
    # código novo entra; código existente só ganha nome se ainda não tiver.
    # Transferência especial só existe para emenda individual (CF art. 166-A), então o tipo é INDIVIDUAL.
    ("autores_gravados", """
        INSERT INTO {p}.tab_autores_emendas AS a (cod_autor, nome_parlamentar, nome_normalizado, tipo_parlamentar, origem)
        SELECT DISTINCT ON (cod_autor) cod_autor, NULLIF(nome_parlamentar, ''), NULLIF(nome_normalizado, ''), 'INDIVIDUAL', %(origem)s
        FROM stg_autores_origem
        ORDER BY cod_autor, nome_normalizado = '', nome_normalizado
        ON CONFLICT (cod_autor) DO UPDATE SET
            nome_parlamentar = EXCLUDED.nome_parlamentar, nome_normalizado = EXCLUDED.nome_normalizado,
            origem = EXCLUDED.origem, dte_carga = now()
        WHERE COALESCE(a.nome_normalizado, '') = '' AND EXCLUDED.nome_normalizado IS NOT NULL
    """),
    # códigos gravados antes por esta fonte, sem tipo
    (None, """
        UPDATE {p}.tab_autores_emendas AS a SET tipo_parlamentar = 'INDIVIDUAL', dte_carga = now()
        WHERE a.origem = %(origem)s AND a.tipo_parlamentar IS NULL
    """),
    (None, """
        UPDATE {p}.tab_parlamentares AS p SET tipo_parlamentar = 'INDIVIDUAL'
        WHERE p.tipo_parlamentar IS NULL
          AND EXISTS (SELECT 1 FROM {p}.tab_autores_emendas a WHERE a.id_parlamentar = p.id_parlamentar AND a.origem = %(origem)s)
    """),
    # liga pelo alias já conhecido (a mesma pessoa com outro código)
    (None, """
        UPDATE {p}.tab_autores_emendas AS a SET id_parlamentar = al.id_parlamentar, dte_carga = now()
        FROM {p}.tab_parlamentares_alias AS al
        WHERE a.id_parlamentar IS NULL AND a.nome_normalizado <> '' AND al.nome_normalizado = a.nome_normalizado
    """),
    # cria parlamentar para os nomes ainda sem dono
    ("parlamentares_novos", """
        INSERT INTO {p}.tab_parlamentares (nome_parlamentar, nome_normalizado, tipo_parlamentar)
        SELECT DISTINCT ON (a.nome_normalizado) a.nome_parlamentar, a.nome_normalizado, a.tipo_parlamentar
        FROM {p}.tab_autores_emendas AS a
        WHERE a.id_parlamentar IS NULL AND a.nome_normalizado <> ''
        ORDER BY a.nome_normalizado, a.cod_autor DESC
    """),
    (None, """
        INSERT INTO {p}.tab_parlamentares_alias (nome_normalizado, nome_original, id_parlamentar, origem)
        SELECT p.nome_normalizado, p.nome_parlamentar, p.id_parlamentar, %(origem)s
        FROM {p}.tab_parlamentares AS p
        WHERE NOT EXISTS (SELECT 1 FROM {p}.tab_parlamentares_alias al WHERE al.nome_normalizado = p.nome_normalizado)
        ON CONFLICT (nome_normalizado) DO NOTHING
    """),
    (None, """
        UPDATE {p}.tab_autores_emendas AS a SET id_parlamentar = al.id_parlamentar, dte_carga = now()
        FROM {p}.tab_parlamentares_alias AS al
        WHERE a.id_parlamentar IS NULL AND a.nome_normalizado <> '' AND al.nome_normalizado = a.nome_normalizado
    """),
    # cada grafia desta fonte vira alias do parlamentar do código
    ("alias_novos", """
        INSERT INTO {p}.tab_parlamentares_alias (nome_normalizado, nome_original, id_parlamentar, origem)
        SELECT DISTINCT ON (s.nome_normalizado) s.nome_normalizado, s.nome_parlamentar, a.id_parlamentar, %(origem)s
        FROM stg_autores_origem AS s
        JOIN {p}.tab_autores_emendas AS a ON a.cod_autor = s.cod_autor
        WHERE s.nome_normalizado <> '' AND a.id_parlamentar IS NOT NULL
        ORDER BY s.nome_normalizado, s.cod_autor
        ON CONFLICT (nome_normalizado) DO NOTHING
    """),
    # grafia que já pertence a outro parlamentar: código fica para revisão
    ("autores_revisar", """
        UPDATE {p}.tab_autores_emendas AS a SET fl_revisar = true, dte_carga = now()
        WHERE NOT a.fl_revisar AND EXISTS (
            SELECT 1 FROM stg_autores_origem AS s
            JOIN {p}.tab_parlamentares_alias AS al ON al.nome_normalizado = s.nome_normalizado
            WHERE s.cod_autor = a.cod_autor AND al.id_parlamentar <> a.id_parlamentar
        )
    """),
)


def tabelas_prontas(conn) -> bool:
    with conn.cursor() as cur:
        cur.execute("SELECT to_regclass(%s)", (f"{ESQUEMA_PARLAMENTAR}.tab_autores_emendas",))
        existe = cur.fetchone()[0]
    if existe is None:
        log.warning(
            "Parlamentares não sincronizados: falta %s.tab_autores_emendas (migration das emendas)",
            ESQUEMA_PARLAMENTAR,
        )
    return existe is not None


def sincronizar(conn, esquema_origem: str) -> dict | None:
    """Grava os códigos de autor e as grafias desta fonte. Devolve contagens, ou None se as tabelas não existem."""
    if not tabelas_prontas(conn):
        return None
    resumo = {"planos_com_emenda": 0, "codigos_invalidos": 0}
    autores: dict[tuple[str, str], str] = {}
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT codigo_parlamentar_emenda_plano_acao, nome_parlamentar_emenda_plano_acao, COUNT(*)
            FROM {esquema_origem}.{TABELA_ORIGEM}
            WHERE fl_ativo AND codigo_parlamentar_emenda_plano_acao IS NOT NULL
            GROUP BY 1, 2
            """
        )
        for codigo, nome, qtd in cur.fetchall():
            resumo["planos_com_emenda"] += qtd
            cod = cod_autor(codigo)
            if cod is None:
                resumo["codigos_invalidos"] += qtd
                continue
            normalizado = normalizar_nome(nome)
            autores.setdefault((cod, normalizado), (nome or "").strip() if normalizado else "")

        cur.execute("SELECT pg_advisory_xact_lock(%s)", (CHAVE_TRAVA,))
        cur.execute(
            "CREATE TEMP TABLE stg_autores_origem (cod_autor char(4), nome_parlamentar varchar(200), "
            "nome_normalizado varchar(200)) ON COMMIT DROP"
        )
        execute_values(
            cur,
            "INSERT INTO stg_autores_origem VALUES %s",
            [(cod, nome[:200], norm[:200]) for (cod, norm), nome in autores.items()],
        )
        resumo["codigos"] = len({cod for cod, _ in autores})
        for chave, texto in _PASSOS:
            cur.execute(texto.format(p=ESQUEMA_PARLAMENTAR), {"origem": ORIGEM})
            if chave:
                resumo[chave] = cur.rowcount
    conn.commit()
    if resumo.get("autores_revisar"):
        log.warning(
            "%s código(s) de autor marcados para revisão (nome das especiais pertence a outro parlamentar)",
            resumo["autores_revisar"],
        )
    if resumo["codigos_invalidos"]:
        log.warning("%s plano(s) com código de parlamentar fora de 0..9999", resumo["codigos_invalidos"])
    return resumo
