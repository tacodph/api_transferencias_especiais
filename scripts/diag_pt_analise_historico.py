"""
Diagnóstico: duplicatas em pt_analise_historico_especiais (endpoint da API)
===========================================================================
Não usa banco nem .env. Só chama a API pública e analisa o que ela devolve.

Responde:
  1. A API devolve o mesmo registro (linha idêntica) em mais de uma página?
     (sintoma de paginação instável: sem ORDER BY, o OFFSET pode repetir/pular linhas)
  2. A chave de 3 colunas usada hoje no script é realmente única?
  3. Qual combinação de colunas identifica de fato cada linha?

Uso (na pasta do projeto):
    python scripts/diag_pt_analise_historico.py --max-paginas 40     # teste rápido
    python scripts/diag_pt_analise_historico.py                      # completo (~7 min)

Gera: diag_pt_analise_historico.json (amostras e contagens) na pasta atual.
"""
import argparse
import json
import sys
import time
from collections import Counter, defaultdict

import requests

BASE = "https://api-publica.transferegov.gestao.gov.br/especiais"
ENDPOINT = "plano_trabalho_analise_historico_especiais"
PK_ATUAL = [
    "id_plano_trabalho_analise_pt",
    "codigo_siorg_orgao_analise_pt_hist",
    "data_analise_pt_hist",
]
TAMANHO = 200


def get(url, params, tentativas=4):
    for i in range(1, tentativas + 1):
        try:
            r = requests.get(url, params=params, timeout=60,
                             headers={"Accept": "application/json"})
            if r.status_code == 429:
                espera = int(r.headers.get("Retry-After", 15))
                print(f"  429 — aguardando {espera}s")
                time.sleep(espera)
                continue
            r.raise_for_status()
            return r.json()
        except requests.RequestException as e:
            if i == tentativas:
                raise
            print(f"  tentativa {i} falhou: {e}; aguardando {5 * i}s")
            time.sleep(5 * i)


def chave(row, cols):
    return tuple(row.get(c) for c in cols)


def linha_completa(row):
    return json.dumps(row, sort_keys=True, ensure_ascii=False, default=str)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-paginas", type=int, default=None)
    args = ap.parse_args()

    url = f"{BASE}/{ENDPOINT}"
    pagina = 1
    total_items = total_pages = None
    linhas = []              # (pagina, row)
    inicio = time.time()

    while True:
        body = get(url, {"pagina": pagina, "tamanho_da_pagina": TAMANHO})
        if total_items is None:
            total_items = body.get("total_items")
            total_pages = body.get("total_pages")
            print(f"total_items={total_items} total_pages={total_pages}")
        dados = body.get("data") or []
        if not dados:
            break
        linhas.extend((pagina, r) for r in dados)
        if pagina % 20 == 0:
            print(f"  página {pagina}/{total_pages} — {len(linhas)} linhas "
                  f"({time.time() - inicio:.0f}s)")
        if total_pages and pagina >= total_pages:
            break
        if args.max_paginas and pagina >= args.max_paginas:
            print(f"(parando em --max-paginas={args.max_paginas})")
            break
        pagina += 1

    colunas = sorted({c for _, r in linhas for c in r})
    print(f"\nlinhas baixadas: {len(linhas)}  colunas: {len(colunas)}")
    print("colunas:", colunas)

    # 1) linhas completamente idênticas
    por_linha = defaultdict(list)
    for pg, r in linhas:
        por_linha[linha_completa(r)].append(pg)
    distintas = len(por_linha)
    repetidas = [(k, v) for k, v in por_linha.items() if len(v) > 1]
    em_paginas_diferentes = [(k, v) for k, v in repetidas if len(set(v)) > 1]

    # 2) chave atual
    por_pk = defaultdict(list)
    for pg, r in linhas:
        por_pk[chave(r, PK_ATUAL)].append(r)
    pk_dup = {k: v for k, v in por_pk.items() if len(v) > 1}
    # destas, quantas têm conteúdo DIFERENTE entre si (colisão real da chave)
    colisao_real = {k: v for k, v in pk_dup.items()
                    if len({linha_completa(x) for x in v}) > 1}

    # 3) a coluna sozinha ou outras combinações
    candidatas = {
        "atual (3 colunas)": PK_ATUAL,
        "só id_plano_trabalho_analise_pt": ["id_plano_trabalho_analise_pt"],
    }
    # procura a menor combinação extra que torna as linhas distintas
    extras = [c for c in colunas if c not in PK_ATUAL]
    for c in extras:
        candidatas[f"atual + {c}"] = PK_ATUAL + [c]
    candidatas["todas as colunas"] = colunas
    unicidade = {}
    for nome, cols in candidatas.items():
        unicidade[nome] = len({chave(r, cols) for _, r in linhas})

    print("\n=== RESULTADO ===")
    print(f"total_items da API ........................ {total_items}")
    print(f"linhas baixadas ........................... {len(linhas)}")
    print(f"linhas distintas (conteúdo inteiro) ....... {distintas}")
    print(f"linhas repetidas em páginas DIFERENTES .... {len(em_paginas_diferentes)}"
          "   <- >0 indica paginação instável")
    print(f"chaves atuais distintas ................... {len(por_pk)}")
    print(f"chaves atuais repetidas ................... {len(pk_dup)}")
    print(f"  das quais com conteúdo diferente ........ {len(colisao_real)}"
          "   <- >0 indica chave atual insuficiente")
    print("\nlinhas distintas por combinação de colunas:")
    for nome, n in unicidade.items():
        print(f"  {n:8d}  {nome}")

    saida = {
        "total_items": total_items,
        "baixadas": len(linhas),
        "distintas_conteudo": distintas,
        "repetidas_paginas_diferentes": len(em_paginas_diferentes),
        "pk_atual_distintas": len(por_pk),
        "pk_atual_repetidas": len(pk_dup),
        "pk_atual_colisao_conteudo_diferente": len(colisao_real),
        "unicidade_por_combinacao": unicidade,
        "amostra_repetidas_paginas": [
            {"paginas": v[:6], "linha": json.loads(k)}
            for k, v in em_paginas_diferentes[:5]
        ],
        "amostra_colisao_chave": [
            {"chave": dict(zip(PK_ATUAL, k)), "linhas": v[:3]}
            for k, v in list(colisao_real.items())[:5]
        ],
    }
    with open("diag_pt_analise_historico.json", "w", encoding="utf-8") as f:
        json.dump(saida, f, ensure_ascii=False, indent=2, default=str)
    print("\nDetalhes gravados em diag_pt_analise_historico.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
