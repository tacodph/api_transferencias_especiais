# Carga incremental — Transferências Especiais (modelo atual)

API: `https://api-publica.transferegov.gestao.gov.br/especiais`  
Tabelas: 20 × `*_especiais` no schema `se_api_transferencias_especiais`

## Uso

```bash
# Ultimos 7 dias (padrao quando --dias e informado sem valor)
python ingest_transferencias.py --dias

# Ultimos N dias
python ingest_transferencias.py --dias 14

# Uma tabela especifica
python ingest_transferencias.py --dias 7 --tabela empenhos_especiais
```

Sem `--dias`, o script faz **carga completa**.

## Como funciona

A API nova **só aceita igualdade** de data (`campo=YYYY-MM-DD`), sem `gte.`/intervalo.

Com `--dias N`, o script itera cada dia em `[hoje−N, hoje]`, busca com igualdade,
une os registros, **deduplica pela PK** e faz upsert.

## Tabelas com filtro incremental

| Tabela | Campo filtrado |
|--------|----------------|
| `programas_especiais` | `data_inicio_ciencia_programa` |
| `planos_acao_especiais` | `data_aceite_plano_acao` |
| `planos_acao_historico_especiais` | `data_hora_historico_plano_acao` |
| `empenhos_especiais` | `data_emissao_empenho` |
| `documentos_habeis_especiais` | `data_emissao_dh` |
| `ordens_pagamentos_ordens_bancarias_especiais` | `data_situacao_op` |
| `relatorios_gestao_especiais` | `data_relatorio_gestao` |
| `relatorios_gestao_novos_especiais` | `data_relatorio_gestao_novo` |
| `planos_trabalho_especiais` | `data_inicio_execucao_plano_trabalho` |
| `planos_trabalho_analises_especiais` | `data_analise_pt` |
| `pt_historico_especiais` | `data_plano_trabalho_hist` |
| `pt_analise_historico_especiais` | `data_analise_pt_hist` |
| `gestao_financeira_lancamentos_especiais` | `data_lancamento_gestao_financeira` |
| `gestao_financeira_subtransacoes_especiais` | `data_pagamento_subtransacao_gestao_financeira` |
| `saldo_conta_gestao_financeira_especiais` | `data_saldo_conta` |

## Tabelas sempre em carga completa (sem campo de data na API)

| Tabela |
|--------|
| `beneficiarios_especiais` |
| `executor_especiais` |
| `meta_especiais` |
| `finalidade_pt_especiais` |
| `orgaos_analises_pendentes_especiais` |

## Paginação

- Parâmetros: `pagina` + `tamanho_da_pagina` (máx. **200**)
- Sem parâmetro de ordenação; ordem estável entre chamadas

## Limitacoes

1. **Nao ha `updated_at`**: o filtro usa data de negocio — alteracoes sem mudanca nessa data nao entram no incremental.
2. **Tabelas sem data**: sempre full mesmo com `--dias`.
3. **Custo do loop diario**: ate `N+1` varreduras paginadas por tabela filtravel.
4. **Recomendacao**: carga completa periodica (ex. semanal) + `--dias` nas cargas diarias.
