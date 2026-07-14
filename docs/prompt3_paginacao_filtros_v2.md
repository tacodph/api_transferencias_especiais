# Prompt 3 — Paginação, ordenação e filtros de data (API v2)

Data: 2026-07-13  
URL: `https://api-publica.transferegov.gestao.gov.br/especiais`  
Código **não** alterado (só investigação).

---

## 1. Paginação

| Item | Resultado |
|---|---|
| Parâmetros | `pagina` (padrão 1), `tamanho_da_pagina` (padrão **50**) |
| Máximo | **200** (confirmado) |
| `tamanho_da_pagina=200` | HTTP 200, devolve até 200 itens |
| `tamanho_da_pagina=201` ou `500` | HTTP **422** — `Input should be less than or equal to 200` em **todos** os 20 endpoints |
| Envelope | `data`, `total_pages`, `total_items`, `page_number`, `page_size` |

**Recomendação de carga:** sempre `tamanho_da_pagina=200` e paginar com `pagina` até `page_number >= total_pages`.

---

## 2. Ordenação

- **Não existe** parâmetro `order` / `ordenar_por` / `sort` no OpenAPI (o único match de “ordenador” é o campo `data_assinatura_ordenador_despesa_ob`, irrelevante).
- Ordem de retorno é **estável** entre chamadas repetidas (amostra: programas, planos_acao, empenhos, planos_trabalho_historico, gestao_financeira_lancamentos).
- Páginas consecutivas **não se sobrepõem** (`overlap pág1 ∩ pág2 = 0`).

Paginação por `pagina` é confiável **sem** ordenação explícita.

---

## 3. Filtros de data — o que a API aceita de verdade

Testado: igualdade, `gte.YYYY-MM-DD`, `>=YYYY-MM-DD`, `{campo}_inicio/{campo}_fim`, `data_inicio/data_fim`, `periodo_inicio/periodo_fim`.

| Forma | Resultado |
|---|---|
| `campo=YYYY-MM-DD` (igualdade) | **Funciona** — reduz `total_items` e os registros batem a data |
| `gte.YYYY-MM-DD` / `gt.…` | HTTP **422** (validação) |
| `>=YYYY-MM-DD` | HTTP **403** |
| Params extras de intervalo | HTTP 200 mas **ignorados** (`total_items` inalterado) |

Conclusão: **só igualdade exata**. Não há filtro de intervalo/nativo “últimos N dias”.

Em campos **timestamp**, passar só a data (`YYYY-MM-DD`) costuma casar o **dia calendário inteiro** (ex.: `data_plano_trabalho_hist=2026-06-29` → 900 registros com horários diferentes no mesmo dia). Passar o timestamp completo às vezes dá **422**.

---

## 4. Tabela pedida (legado `--dias` → endpoint novo)

| Tabela (nova / endpoint) | Suporta filtro de intervalo? | Como |
|---|---|---|
| `programas_especiais` | **Não** | Igualdade: `data_inicio_ciencia_programa=YYYY-MM-DD` |
| `empenhos_especiais` | **Não** | Igualdade: `data_emissao_empenho=YYYY-MM-DD` |
| `documentos_habeis_especiais` | **Não** | Igualdade: `data_emissao_dh=YYYY-MM-DD` |
| `ordens_pagamentos_ordens_bancarias_especiais` | **Não** | Igualdade: `data_situacao_op=YYYY-MM-DD` (alt.: `data_emissao_op`) |
| `relatorios_gestao_novos_especiais` | **Não** | Preferir `data_relatorio_gestao_novo=YYYY-MM-DD` (campo date); `data_e_hora_…` com dia também filtra |
| `planos_trabalho_especiais` | **Não** | Igualdade: `data_inicio_execucao_plano_trabalho=YYYY-MM-DD` |
| `planos_trabalho_analises_especiais` | **Não** | Igualdade: `data_analise_pt=YYYY-MM-DD` (timestamp; dia inteiro) |
| `pt_historico_especiais` (`/planos_trabalho_historico`) | **Não** | Igualdade: `data_plano_trabalho_hist=YYYY-MM-DD` (dia inteiro) |
| `pt_analise_historico_especiais` | **Não** | Igualdade: `data_analise_pt_hist=YYYY-MM-DD` |
| `historico_pagamento_especial` (antigo) | — | **Sem sucessor** no v2 (absorvido pela gestão financeira) |

### Endpoints novos com param de data (candidatos a `--dias` no v2)

| Endpoint / tabela | Campo de data no OpenAPI |
|---|---|
| `planos_acao_especiais` | `data_aceite_plano_acao` |
| `planos_acao_historico_especiais` | `data_hora_historico_plano_acao` |
| `relatorios_gestao_especiais` | `data_relatorio_gestao` |
| `gestao_financeira_lancamentos_especiais` | `data_lancamento_gestao_financeira` |
| `gestao_financeira_subtransacoes_especiais` | `data_pagamento_subtransacao_gestao_financeira` |
| `saldo_conta_gestao_financeira_especiais` | `data_saldo_conta` |

(mesma limitação: só igualdade; intervalo exige loop por dia)

Tabelas **sem** param de data no OpenAPI (carga incremental por data inviável via API):  
`beneficiarios_especiais`, `executores_especiais`, `meta_especiais`, `finalidade_especiais`, `orgaos_analises_pendentes_especiais`.

---

## 5. Decisão para o `--dias` — **ADOTADA** (2026-07-13)

**Loop diário + híbrido** (opções 1 e 3):

- Tabelas com `filtro_data`: para cada dia em `[hoje−N, hoje]`, `campo=YYYY-MM-DD`, unir, deduplicar por PK, upsert.
- Tabelas sem campo de data: carga completa mesmo com `--dias`.

Registrado em `docs/carga_incremental.md` (seção “API v2”). Implementação no Prompt 4.

---

Bruto dos testes: `docs/_prompt3_raw.json`.
