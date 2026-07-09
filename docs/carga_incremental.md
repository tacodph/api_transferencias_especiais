# Carga incremental — Transferências Especiais

## Uso

```bash
# Ultimos 7 dias (padrao quando --dias e informado sem valor)
python ingest_transferencias.py --dias

# Ultimos N dias
python ingest_transferencias.py --dias 14

# Uma tabela especifica
python ingest_transferencias.py --dias 7 --tabela empenho_especial
```

Sem `--dias`, o script continua fazendo **carga completa** (comportamento anterior).

## Como funciona

O filtro usa operadores PostgREST (`coluna=gte.YYYY-MM-DD`) sobre um campo de data/timestamp
de cada tabela. Apenas registros com data **maior ou igual** ao limite sao buscados na API e
gravados via upsert.

## Tabelas com filtro incremental

| Tabela | Campo filtrado | Tipo |
|--------|----------------|------|
| `programa_especial` | `data_inicio_ciencia_programa` | DATE |
| `empenho_especial` | `data_emissao_empenho` | DATE |
| `documento_habil_especial` | `data_emissao_dh` | DATE |
| `ordem_pagamento_ordem_bancaria_especial` | `data_situacao_op` | DATE |
| `historico_pagamento_especial` | `data_hora_historico_op` | TIMESTAMP |
| `relatorio_gestao_novo_especial` | `data_e_hora_relatorio_gestao_novo` | TIMESTAMP |
| `plano_trabalho_especial` | `data_inicio_execucao_plano_trabalho` | TIMESTAMP |
| `plano_trabalho_analise_especial` | `data_analise_pt` | TIMESTAMP |
| `plano_trabalho_historico_especial` | `data_plano_trabalho_hist` | TIMESTAMP |
| `plano_trabalho_analise_historico_especial` | `data_analise_pt_hist` | TIMESTAMP |

## Tabelas sempre em carga completa (sem campo de data na API)

| Tabela | Motivo |
|--------|--------|
| `plano_acao_especial` | Nenhuma coluna de data no endpoint |
| `relatorio_gestao_especial` | Nenhuma coluna de data no endpoint |
| `meta_especial` | Nenhuma coluna de data no endpoint |
| `executor_especial` | Nenhuma coluna de data no endpoint |
| `finalidade_especial` | Nenhuma coluna de data no endpoint |
| `orgao_analise_pendente_especial` | Nenhuma coluna de data no endpoint |

## Limitacoes

1. **Nao ha campo `updated_at`**: a API nao expoe data de ultima alteracao. O filtro usa
   campos de data de negocio (emissao, analise, historico etc.) como proxy — registros
   alterados sem mudanca nessa data **nao serao recapturados**.

2. **Tabelas sem data**: 6 das 16 tabelas sempre fazem carga completa mesmo com `--dias`.

3. **Hierarquia nao propagada**: filtrar `empenho_especial` pelos ultimos 7 dias nao atualiza
   automaticamente `plano_acao_especial` ou `programa_especial` relacionados.

4. **Registros com data nula**: linhas com o campo de filtro `NULL` sao excluidos pelo
   PostgREST e nao entram na carga incremental.

5. **Campo escolhido e heuristico**: ex. `data_situacao_op` captura mudancas de situacao de OP,
   mas nao necessariamente novas emissoes; `data_inicio_ciencia_programa` em programas reflete
   inicio de ciencia, nao atualizacoes de valores.

6. **Recomendacao operacional**: executar carga completa periodicamente (ex. semanal) e usar
   `--dias` apenas nas cargas diarias intermediarias.
