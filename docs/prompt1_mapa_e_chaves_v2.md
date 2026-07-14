# Prompt 1 — Mapa endpoint → tabela e chaves (API v2)

Data da investigação: 2026-07-13  
URL base confirmada: `https://api-publica.transferegov.gestao.gov.br/especiais`  
Constante no script: `API_BASE_URL_V2` em `ingest_transferencias.py` (a `API_BASE_URL` v1 permanece).

## 1. Endpoints (20/20 OK)

Todos responderam **HTTP 200** com envelope
`data / total_pages / total_items / page_number / page_size`
(`pagina=1&tamanho_da_pagina=1`).

Colunas do primeiro registro batem **100%** com o XML
(`api-transferegov.api_transferegov_especiais.xml`) — `match=True` em todos.

### Mapa confirmado (sem correções)

| Endpoint | Tabela (XML) | PK no XML | total_items (snapshot) | Equivalente antigo |
|---|---|---|---|---|
| `/programas_especiais` | `programas_especiais` | `id_programa` | 15 | `programa_especial` |
| `/planos_acao_especiais` | `planos_acao_especiais` | `id_plano_acao` | 57.827 | `plano_acao_especial` |
| `/planos_acao_historico_especiais` | `planos_acao_historico_especiais` | `id_historico_plano_acao` | 142.497 | *(nova)* |
| `/beneficiarios_especiais` | `beneficiarios_especiais` | `id_beneficiario` | 5.539 | *(nova)* |
| `/planos_trabalho_especiais` | `planos_trabalho_especiais` | `id_plano_trabalho` | 56.416 | `plano_trabalho_especial` |
| `/planos_trabalho_analises_especiais` | `planos_trabalho_analises_especiais` | `id_plano_trabalho_analise_pt` | 106.540 | `plano_trabalho_analise_especial` |
| `/plano_trabalho_analise_historico_especiais` | `pt_analise_historico_especiais` | *(sem PK)* | 62.599 | `plano_trabalho_analise_historico_especial` |
| `/planos_trabalho_historico` | `pt_historico_especiais` | `id_plano_trabalho_hist` | 459.545 | `plano_trabalho_historico_especial` |
| `/orgaos_analises_pendentes_especiais` | `orgaos_analises_pendentes_especiais` | *(sem PK)* | 154 | `orgao_analise_pendente_especial` |
| `/relatorios_gestao_especiais` | `relatorios_gestao_especiais` | `id_relatorio_gestao` | 5.362 | `relatorio_gestao_especial` |
| `/relatorios_gestao_novos_especiais` | `relatorios_gestao_novos_especiais` | `id_relatorio_gestao_novo` | 25.608 | `relatorio_gestao_novo_especial` |
| `/empenhos_especiais` | `empenhos_especiais` | `id_empenho` | 60.322 | `empenho_especial` |
| `/documentos_habeis_especiais` | `documentos_habeis_especiais` | `id_dh` | 57.986 | `documento_habil_especial` |
| `/ordens_pagamentos_ordens_bancarias_especiais` | `ordens_pagamentos_ordens_bancarias_especiais` | `id_op_ob` | 55.148 | `ordem_pagamento_ordem_bancaria_especial` |
| `/executores_especiais` | `executor_especiais` | *(sem PK)* | 57.374 | `executor_especial` |
| `/meta_especiais` | `meta_especiais` | `id_meta` | 155.920 | `meta_especial` |
| `/finalidade_especiais` | `finalidade_pt_especiais` | *(sem PK)* | 94.258 | `finalidade_especial` |
| `/gestao_financeira_lancamentos_especiais` | `gestao_financeira_lancamentos_especiais` | `id_lancamento_gestao_financeira` | 713.166 | *(nova)* |
| `/gestao_financeira_subtransacoes_especiais` | `gestao_financeira_subtransacoes_especiais` | *(sem PK)* | 12.787 | *(nova)* |
| `/saldo_conta_gestao_financeira_especiais` | `saldo_conta_gestao_financeira_especiais` | `id_agencia_conta` | 31.074 | *(nova)* |

Observações:
- `/data-atualizacao` não tem tabela (só timestamp) — fora do escopo de carga tabular.
- Nomes de endpoint ≠ nome da tabela em 4 casos (já previstos no mapa preliminar):
  `executores_especiais`→`executor_especiais`, `finalidade_especiais`→`finalidade_pt_especiais`,
  `plano_trabalho_analise_historico_especiais`→`pt_analise_historico_especiais`,
  `planos_trabalho_historico`→`pt_historico_especiais`.
- Em `meta_especiais`, o XML declara PK simples `id_meta` (antes era composta
  `(id_executor, id_meta)`). Amostra de 2.000 confirma `id_meta` 100% único.

## 2. Chaves para as 5 tabelas sem PK no XML

| Tabela | Chave adotada | Tipo | Evidência | Observação de carga |
|---|---|---|---|---|
| `executor_especiais` | `(id_plano_acao, id_executor)` | composta natural | 2.998/3.000 únicos; os 2 faltantes são **linhas 100% idênticas** na API | Deduplicar por PK antes do upsert (já existe `deduplicar_por_pk`) |
| `finalidade_pt_especiais` | `(id_executor, cd_area_politica_publica_tipo_pt, cd_area_politica_publica_pt)` | composta natural | 3.000/3.000 (100%); igual à PK do modelo antigo | — |
| `orgaos_analises_pendentes_especiais` | `(id_plano_trabalho, id_orgao_analise_pendente_pt)` | composta natural | 154/154 da população completa | — |
| `pt_analise_historico_especiais` | `(id_plano_trabalho_analise_pt, codigo_siorg_orgao_analise_pt_hist, data_analise_pt_hist)` | composta natural | Após remover linhas idênticas, a chave coincide com unicidade da linha inteira (1.610/3.000 → 100% das linhas distintas) | API devolve muitas cópias exatas (até ×356). Deduplicar obrigatório antes do upsert |
| `gestao_financeira_subtransacoes_especiais` | `(id_subtransacao_gestao_financeira)` | natural simples | 3.000/3.000 (100%) | XML não declara PK, mas o campo se comporta como PK |

### Detalhe — `executor_especiais`

- `id_executor` sozinho e `(id_plano_acao, id_executor)` têm a mesma taxa (99,93%).
- Os “conflitos” são pares duplicados byte-a-byte (`cols_diferem=[]`).
- Mantemos a composta `(id_plano_acao, id_executor)` por paridade com o modelo antigo
  e porque `id_plano_acao` existe na API nova (confirmado).

### Detalhe — `pt_analise_historico_especiais`

- Nenhuma combinação de colunas é única **sem** deduplicar, porque a API
  repete linhas idênticas (multiplicidade até 356× na amostra).
- Após dedupe por linha completa, a chave natural antiga adapta bem:
  o campo passou de `id_plano_trabalho_analise` → `id_plano_trabalho_analise_pt`.
- **Não** usar hash MD5 sintético: a chave natural basta com dedupe.

## 3. O que NÃO foi alterado (conforme Prompt 1)

- Schema do banco: intacto.
- `TABELAS` / `NIVEIS_CARGA` / `fetch_all` (v1): intactos.
- Apenas adicionada `API_BASE_URL_V2`.

## 4. Pronto para o Prompt 2

Usar este mapa e estas PKs em `data/04_ddl_schema_novo.sql`.
