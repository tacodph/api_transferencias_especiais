# Prompts para Claude Code — Atualização para o Novo Modelo de Dados (v2)

Copie e cole estes prompts no Claude Code (`claude`), na raiz do projeto, **na ordem apresentada** — cada um
depende de arquivos/decisões produzidos pelo anterior. O `agentes\CLAUDE.md` continua sendo lido
automaticamente e descreve o modelo **atual** (v1); os prompts abaixo pedem explicitamente que ele seja
atualizado só no Prompt 8, depois que o novo modelo estiver validado.

## Contexto que todo prompt já assume

- Fonte de verdade do novo modelo: `docs\novo modelos de dados\openapi.json` (endpoints, parâmetros,
  paginação) e `docs\novo modelos de dados\modelos de dados\api-transferegov.api_transferegov_especiais.xml`
  (colunas, tipos, PKs, FKs reais — mais confiável que o HTML gerado pelo SchemaSpy).
- Schema de destino continua o mesmo: `se_api_transferencias_especiais`, banco `campinas.cidades.gov.br`.
- **Estratégia de migração adotada: paralela com corte.** As 20 tabelas novas são criadas *ao lado* das 16
  tabelas antigas no mesmo schema, populadas do zero pela API nova, validadas, e só depois disso os
  consumidores (views, relatório de monitoramento, documentação) são apontados para elas e as tabelas
  antigas são removidas. Não faça `DROP` de nenhuma tabela antiga antes do Prompt 8.
- Mapa preliminar endpoint → tabela (os nomes de endpoint do `openapi.json` nem sempre batem com o nome da
  tabela no XML — confirme/corrija este mapa no Prompt 1, não assuma que está 100% certo):

  | Endpoint (openapi.json) | Tabela (XML) | Tabela antiga equivalente |
  |---|---|---|
  | `/programas_especiais` | `programas_especiais` | `programa_especial` |
  | `/planos_acao_especiais` | `planos_acao_especiais` | `plano_acao_especial` |
  | `/planos_acao_historico_especiais` | `planos_acao_historico_especiais` | *(nova)* |
  | `/beneficiarios_especiais` | `beneficiarios_especiais` | *(nova)* |
  | `/planos_trabalho_especiais` | `planos_trabalho_especiais` | `plano_trabalho_especial` |
  | `/planos_trabalho_analises_especiais` | `planos_trabalho_analises_especiais` | `plano_trabalho_analise_especial` |
  | `/plano_trabalho_analise_historico_especiais` | `pt_analise_historico_especiais` | `plano_trabalho_analise_historico_especial` |
  | `/planos_trabalho_historico` | `pt_historico_especiais` | `plano_trabalho_historico_especial` |
  | `/orgaos_analises_pendentes_especiais` | `orgaos_analises_pendentes_especiais` | `orgao_analise_pendente_especial` |
  | `/relatorios_gestao_especiais` | `relatorios_gestao_especiais` | `relatorio_gestao_especial` |
  | `/relatorios_gestao_novos_especiais` | `relatorios_gestao_novos_especiais` | `relatorio_gestao_novo_especial` |
  | `/empenhos_especiais` | `empenhos_especiais` | `empenho_especial` |
  | `/documentos_habeis_especiais` | `documentos_habeis_especiais` | `documento_habil_especial` |
  | `/ordens_pagamentos_ordens_bancarias_especiais` | `ordens_pagamentos_ordens_bancarias_especiais` | `ordem_pagamento_ordem_bancaria_especial` |
  | `/executores_especiais` | `executor_especiais` | `executor_especial` |
  | `/meta_especiais` | `meta_especiais` | `meta_especial` |
  | `/finalidade_especiais` | `finalidade_pt_especiais` | `finalidade_especial` |
  | `/gestao_financeira_lancamentos_especiais` | `gestao_financeira_lancamentos_especiais` | *(nova)* |
  | `/gestao_financeira_subtransacoes_especiais` | `gestao_financeira_subtransacoes_especiais` | *(nova)* |
  | `/saldo_conta_gestao_financeira_especiais` | `saldo_conta_gestao_financeira_especiais` | *(nova)* |
  | `/data-atualizacao` | *(sem tabela — só timestamp de última atualização)* | — |

  Não tem sucessor: `historico_pagamento_especial` (função absorvida pelo novo módulo de gestão financeira).

- Tabelas **sem chave primária declarada** no XML novo (precisam de estratégia de chave antes do upsert
  funcionar): `executor_especiais`, `finalidade_pt_especiais`, `orgaos_analises_pendentes_especiais`,
  `pt_analise_historico_especiais`, `gestao_financeira_subtransacoes_especiais`.

---

## PROMPT 1 — Confirmar o mapa endpoint → tabela na API nova

```
A URL base da nova API já está confirmada (testada ao vivo nesta sessão de
planejamento): https://api-publica.transferegov.gestao.gov.br/especiais
(ex: https://api-publica.transferegov.gestao.gov.br/especiais/programas_especiais
responde com o envelope data/total_pages/total_items/page_number/page_size). Salve essa
URL em uma nova constante API_BASE_URL_V2 em ingest_transferencias.py (não substitua
a API_BASE_URL atual ainda — as tabelas antigas continuam sendo carregadas dela até o
corte no Prompt 8).

1. Usando essa URL, faça uma chamada real para cada um dos 20 endpoints listados
   na tabela "Mapa preliminar endpoint → tabela" no início deste arquivo (peça 1 registro
   de cada, com tamanho_da_pagina=1) e confirme:
   - Que o endpoint responde 200 e devolve o envelope esperado
     (data / total_pages / total_items / page_number / page_size).
   - Que o nome de tabela no XML bate com as chaves do primeiro registro retornado.
   Corrija a tabela de mapeamento se encontrar divergências.

2. Para as 5 tabelas sem PK declarada (executor_especiais, finalidade_pt_especiais,
   orgaos_analises_pendentes_especiais, pt_analise_historico_especiais,
   gestao_financeira_subtransacoes_especiais), busque uma amostra real de cada uma
   (~500-1000 registros) e verifique se alguma combinação de colunas é única o
   suficiente para servir de chave composta no upsert. Proponha, por tabela, ou uma
   chave composta natural ou uma chave sintética (ex: hash MD5 concatenando todas as
   colunas). Documente a decisão tabela por tabela.

Não altere ainda o schema do banco nem o script principal — este prompt é só de
investigação e documentação. Ao final, resuma o que foi confirmado/corrigido no mapa
e a decisão de chave para cada uma das 5 tabelas.
```

---

## PROMPT 2 — Nova DDL (tabelas ao lado das antigas)

```
Com o mapa de tabelas e as chaves definidas no Prompt 1, crie
data\04_ddl_schema_novo.sql com as 20 tabelas do novo modelo, no schema
se_api_transferencias_especiais (mesmo schema das tabelas atuais — não crie um schema
novo). Baseie os nomes/tipos de coluna no XML
"docs\novo modelos de dados\modelos de dados\api-transferegov.api_transferegov_especiais.xml"
(fonte mais confiável que o HTML gerado).

Convenções a manter, iguais ao data\01_ddl_schema.sql atual:
- CREATE TABLE IF NOT EXISTS
- COMMENT ON TABLE com a descrição de cada tabela (vem do XML/index.html)
- Coluna dt_carga TIMESTAMP DEFAULT NOW() em todas as tabelas
- Sem FOREIGN KEY declaradas (mesma convenção do schema atual — relação é só por
  convenção de nome de coluna)
- PRIMARY KEY em todas as tabelas, incluindo as 5 sem PK no schema de origem — use a
  chave definida no Prompt 1

Nomeie as tabelas exatamente como aparecem no XML (plural, sufixo _especiais). Não
toque nas tabelas antigas (*_especial) nem no controle_carga. Ao final, rode o
script contra o banco (usando as credenciais do .env) e confirme que as 20 tabelas
novas foram criadas listando-as com uma query em information_schema.tables filtrando
pelo schema e pelo sufixo _especiais.
```

---

## PROMPT 3 — Investigar paginação, ordenação e filtros de data da API nova

```
Antes de reescrever a carga incremental, preciso saber o que a API nova realmente
suporta. Usando a URL base confirmada no Prompt 1, para cada um dos 20 endpoints:

1. Confirme o comportamento de paginação: parâmetros "pagina" (padrão 1) e
   "tamanho_da_pagina" (padrão 50, máximo 200 segundo o openapi.json — confirme esse
   limite fazendo uma chamada com tamanho_da_pagina=500 e vendo o que a API faz).
2. Verifique se existe algum parâmetro de ordenação (procure no openapi.json por um
   parâmetro tipo "order"/"ordenar_por"; se não existir, teste se a ordem de retorno é
   estável entre chamadas — importante para paginação confiável).
3. Para as tabelas que hoje têm filtro_data no TABELAS do ingest_transferencias.py
   (ver script atual), identifique o parâmetro de data equivalente no endpoint novo e
   teste se ele aceita só igualdade exata ou também operadores de intervalo (ex: dois
   parâmetros data_inicio/data_fim, ou um único parâmetro que pareça aceitar
   "gte."-like). Teste na prática, não só leia o schema — o comportamento real da API
   pode divergir da descrição.

Ao final, monte uma tabela markdown (tabela | suporta filtro de intervalo? | como) e
me apresente antes de eu decidir o que vira do --dias. Não altere o código ainda.
```

---

## PROMPT 4 — Reescrever a camada de acesso à API nova

```
Baseado no que foi confirmado nos Prompts 1 e 3, adicione ao ingest_transferencias.py
(sem remover as funções atuais _make_request/fetch_all, que continuam servindo a
carga das tabelas antigas até o corte no Prompt 8) uma nova camada para a API v2:

- _make_request_v2(endpoint, params): GET contra API_BASE_URL_V2, parâmetros
  "pagina"/"tamanho_da_pagina" em vez de limit/offset, mesmo retry/backoff do
  _make_request atual.
- fetch_all_v2(endpoint, filtros=None): pagina usando o envelope de resposta
  (data/total_pages/total_items/page_number/page_size) em vez do header
  Content-Range — incrementa "pagina" até page_number >= total_pages.
- Ajuste a função de filtro de data conforme o resultado do Prompt 3: se a API só
  aceita igualdade exata, implemente a carga incremental buscando por dia individual
  dentro da janela solicitada (ou outra abordagem que você julgar melhor com base no
  que foi encontrado — mas documente a escolha em docs\carga_incremental.md).

Não ligue essas funções ao fluxo principal (processar_tabela/executar_carga) ainda —
isso é o Prompt 5. Teste fetch_all_v2 isoladamente contra 2-3 endpoints reais e mostre
que a paginação percorre todas as páginas corretamente (bata a contagem final com
total_items).
```

---

## PROMPT 5 — Novo `TABELAS_V2` e `NIVEIS_CARGA_V2`

```
Crie TABELAS_V2 e NIVEIS_CARGA_V2 em ingest_transferencias.py, no mesmo formato dos
TABELAS/NIVEIS_CARGA atuais, cobrindo as 20 tabelas novas:

- pk: usar a chave definida no Prompt 1 para as 5 tabelas sem PK original
- order: coluna de ordenação confirmada no Prompt 3 (ou a PK, se não houver ordenação
  dedicada)
- filtro_data: conforme decidido no Prompt 4

Reorganize a hierarquia de NIVEIS_CARGA_V2 considerando as mudanças de relacionamento:
- beneficiarios_especiais entra num nível anterior a planos_acao_especiais (agora tem
  FK id_beneficiario)
- o módulo de gestão financeira (gestao_financeira_lancamentos_especiais →
  gestao_financeira_subtransacoes_especiais, e saldo_conta_gestao_financeira_especiais)
  roda como ramo paralelo, não depende da árvore de plano_acao/empenho/documento_habil
- planos_acao_historico_especiais depende de planos_acao_especiais
- mantenha o resto da hierarquia equivalente à atual (programa → plano_acao →
  empenho → documento_habil → ordem_pagamento_ordem_bancaria; e plano_acao →
  executor/meta/finalidade → plano_trabalho → análises/histórico)

Adicione um novo argumento de CLI --v2 ao script que, quando presente, usa
TABELAS_V2/NIVEIS_CARGA_V2/fetch_all_v2 em vez das versões atuais, mantendo o
comportamento default (sem --v2) intacto para não afetar a carga em produção das
tabelas antigas.
```

---

## PROMPT 6 — Carga completa e validação em paralelo

```
Rode a carga completa do novo modelo sem afetar as tabelas antigas:

    python ingest_transferencias.py --v2

Acompanhe o log e, ao final:
1. Compare a contagem de registros de cada tabela nova com o total_items reportado
   pela API para o mesmo endpoint (deve bater, ou a diferença deve ser explicável).
2. Para as tabelas que têm equivalente antigo (ver mapa no início deste arquivo),
   compare a ordem de grandeza com a tabela antiga correspondente — grandes
   divergências (não só diferenças esperadas por período/tipo de dado) merecem
   investigação antes de prosseguir.
3. Rode uma checagem de integridade meramente informativa (não é FK de verdade, mas
   confirma que a relação implícita funciona): para planos_acao_especiais, quantos
   id_beneficiario não têm correspondente em beneficiarios_especiais? Idem para
   id_programa em programas_especiais.
Apresente um resumo tabular com os resultados antes de seguirmos para as views.
```

---

## PROMPT 7 — Views analíticas para o novo modelo

```
Reescreva as 4 views de data\02_views_analiticas.sql contra as tabelas novas, em um
novo arquivo data\05_views_analiticas_v2.sql (não mexa no arquivo atual, que continua
servindo as tabelas antigas até o corte):

1. vw_transferencias_por_uf — hoje usa pa.uf_beneficiario_plano_acao e
   pa.nome_beneficiario_plano_acao, que não existem mais em planos_acao_especiais.
   Faça JOIN com beneficiarios_especiais via id_beneficiario para obter
   uf_beneficiario/nome_beneficiario.
2. vw_pagamentos_pendentes e vw_resumo_parlamentar e vw_execucao_financeira — adapte
   os nomes de tabela/coluna conforme o mapa (empenhos_especiais,
   documentos_habeis_especiais, ordens_pagamentos_ordens_bancarias_especiais,
   planos_acao_especiais, programas_especiais), mantendo a mesma lógica de negócio
   (ex: "pago" continua sendo numero_ordem_bancaria preenchido e não vazio).

Além disso, proponha e crie 1-2 views novas que só fazem sentido com o módulo de
gestão financeira que não existia antes, por exemplo:
- saldo atual por conta (a partir de saldo_conta_gestao_financeira_especiais)
- subtransações pendentes/bloqueadas por lançamento (join
  gestao_financeira_lancamentos_especiais + gestao_financeira_subtransacoes_especiais
  filtrando pela situação de pagamento)

Rode as views contra o banco depois de criadas e mostre 5 linhas de cada uma como
prova de que funcionam.
```

---

## PROMPT 8 — Corte (cutover) para o novo modelo

```
Só execute este prompt depois que os Prompts 6 e 7 tiverem sido validados e você tiver
confirmado comigo que os números batem.

1. Atualize data\relatorio_carga.sql: troque a lista hardcoded de 16 tabelas no
   unnest(ARRAY[...]) pelas 20 tabelas novas.
2. Atualize agentes\CLAUDE.md: tabela de endpoints, diagrama de hierarquia, URL base
   da API, e a seção "Convenções de Código" se algo tiver mudado (ex: paginação
   agora é por página, não por offset).
3. Atualize docs\carga_incremental.md com o que foi decidido no Prompt 3/4 sobre carga
   incremental no novo modelo.
4. Remova o argumento --v2 tornando TABELAS_V2/NIVEIS_CARGA_V2/fetch_all_v2 o caminho
   padrão do script (renomeie removendo o sufixo _v2, ou apenas troque as referências
   em main()) — mantenha uma tag/branch de controle de versão do arquivo original
   antes de fazer essa troca, para poder reverter se necessário.
5. Depois de tudo funcionando com o script "sem --v2" já apontando para o modelo novo,
   renomeie as tabelas antigas para um sufixo _bak (não delete ainda) com ALTER TABLE
   ... RENAME TO, e deixe registrado neste arquivo a data do corte e a data prevista
   para dropar de vez as tabelas _bak.

Pare e confirme comigo antes do passo 5 — é a parte irreversível (mesmo que reversível
via _bak, é a que muda o comportamento em produção).
```

---

## PROMPT 9 — Confirmar agendamento e alertas continuam válidos

```
Depois do corte (Prompt 8), confirme que scripts\run_ingest.ps1, scripts\run_ingest.bat
e o alerta por e-mail (enviar_alerta_email em ingest_transferencias.py) continuam
funcionando sem alteração — eles não referenciam nomes de tabela diretamente, só
chamam o script principal. Rode manualmente:

    powershell -ExecutionPolicy Bypass -File scripts\run_ingest.ps1

e confirme no log que a carga usou o modelo novo (sem --v2, já que foi promovido a
padrão no Prompt 8). Não é necessário recriar a tarefa agendada no Windows a menos que
o comando ou caminho do script tenha mudado.
```

---

## Dicas de uso no Claude Code

- Siga a ordem dos prompts — cada um assume que o anterior já rodou e que os arquivos
  que ele criou existem.
- Nenhuma tabela antiga é removida antes do Prompt 8, e mesmo aí primeiro são
  renomeadas para `_bak`, não deletadas — o corte é reversível até uma limpeza manual
  posterior.
- Se algum prompt encontrar uma divergência importante em relação ao que está descrito
  aqui (ex: a API nova não existir no domínio esperado, ou algum endpoint não bater com
  a tabela do XML), ele deve parar e reportar em vez de assumir e seguir em frente.
- Para debugar uma chamada manualmente contra a API nova (depois que a URL for
  confirmada no Prompt 1):
  ```bash
  curl "https://api-publica.transferegov.gestao.gov.br/especiais/programas_especiais?tamanho_da_pagina=5" | python -m json.tool
  ```
