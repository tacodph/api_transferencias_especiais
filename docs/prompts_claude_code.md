# Prompts para Claude Code — Ingestão Transferências Especiais

Copie e cole estes prompts no Claude Code (`claude`) conforme a necessidade.
O arquivo `CLAUDE.md` na pasta do projeto fornecerá o contexto automaticamente.

---

## PROMPT 1 — Inicialização do projeto

```
Estou criando uma rotina de ingestão da API pública de Transferências Especiais do
Transferegov para o banco corporativo campinas.cidades.gov.br.

Os arquivos base já estão nesta pasta:
- agentes/CLAUDE.md → contexto completo do projeto
- data/04_ddl_schema_novo.sql → DDL das 20 tabelas atuais
- ingest_transferencias.py → script principal

Instale as dependências necessárias (requests, psycopg2-binary) e crie o
requirements.txt. Em seguida, verifique se o script está sintaticamente correto
e execute um teste de conectividade com a API nova
(https://api-publica.transferegov.gestao.gov.br/especiais/programas_especiais)
sem gravar no banco.
```

---

## PROMPT 2 — Teste de conexão com o banco

```
Use o arquivo .env já configurado na raiz do projeto para a conexão com o
PostgreSQL (campinas.cidades.gov.br). O script ingest_transferencias.py carrega
esse arquivo automaticamente via python-dotenv — não altere credenciais no script
nem exporte variáveis manualmente.

- Schema: se_api_transferencias_especiais

Instale as dependências (pip install -r requirements.txt) e teste a conexão
usando as variáveis DB_HOST, DB_PORT, DB_NAME, DB_USER e DB_PASSWORD do .env.

Verifique se o schema e as tabelas *_especiais existem. Se não existirem, execute
data/04_ddl_schema_novo.sql e data/07_controle_carga_v2.sql. Após a criação,
liste as tabelas criadas para confirmar.
```

---

## PROMPT 3 — Teste de carga em uma tabela

```
Execute a ingestão apenas da tabela programas_especiais:

    python ingest_transferencias.py --tabela programas_especiais

Mostre o log de execução e faça uma consulta SQL no banco para confirmar que os
registros foram inseridos corretamente. Mostre as primeiras 5 linhas e a contagem
total de registros.
```

---

## PROMPT 4 — Carga completa

```
Execute a carga completa de todas as 20 tabelas:

    python ingest_transferencias.py

Monitore o progresso e, ao final, execute a seguinte consulta no banco para mostrar
o resumo de registros por tabela:

SELECT tablename, n_live_tup AS registros
FROM pg_stat_user_tables
WHERE schemaname = 'se_api_transferencias_especiais'
  AND tablename LIKE '%\_especiais' ESCAPE '\'
ORDER BY tablename;

Mostre também os últimos 20 registros da tabela controle_carga e o ultimo
controle_carga_dia.
```

---

## PROMPT 5 — Implementar carga incremental

```
Implementado em ingest_transferencias.py. Use:

    python ingest_transferencias.py --dias       # ultimos 7 dias (padrao)
    python ingest_transferencias.py --dias 14    # ultimos 14 dias

A API nova so aceita igualdade de data; o script faz loop diario.
Tabelas sem data fazem carga completa. Detalhes em docs/carga_incremental.md.
```

---

## PROMPT 6 — Adicionar paralelismo

```
Implementado em ingest_transferencias.py. Use:

    python ingest_transferencias.py --workers 4    # padrao: 4 threads por nivel
    python ingest_transferencias.py --workers 1    # sequencial

Tabelas do mesmo nivel hierarquico rodam em paralelo; niveis aguardam conclusao
do anterior. Cada worker usa conexao PostgreSQL propria.
```

---

## PROMPT 7 — Agendamento no Windows (Agendador de Tarefas)

```
Arquivos criados:
- scripts\run_ingest.ps1
- scripts\run_ingest.bat
- docs\agendamento_windows.md (instrucoes e schtasks)

Teste manual:
    powershell -ExecutionPolicy Bypass -File scripts\run_ingest.ps1

Criar tarefa diaria as 06:00 — ver docs\agendamento_windows.md
```

---

## PROMPT 8 — Dashboard de monitoramento

```
Relatorio SQL criado em data\relatorio_carga.sql

Execute no pgAdmin/psql conectado ao banco corporativo. O relatorio mostra:
1. Status da ultima carga de cada tabela
2. Registros lidos (ultima vs anterior) e total atual no banco
3. Tempo de execucao em segundos
4. Alertas: ERRO, sem carga hoje, nunca carregada ou em andamento
```

---

## PROMPT 9 — Criar views analíticas

```
Views criadas em data\02_views_analiticas.sql:

1. vw_transferencias_por_uf — valor por UF e ano (plano de acao)
2. vw_pagamentos_pendentes — planos com empenho sem OB emitida
3. vw_resumo_parlamentar — emendas por parlamentar (empenhado x pago)
4. vw_execucao_financeira — empenhado x documentado x pago por programa

Executar no pgAdmin/psql apos a carga das tabelas.
```

---

## PROMPT 10 — Tratamento de erros e alertas por e-mail

```
Implementado em ingest_transferencias.py. Configure no .env:

    SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, EMAIL_FROM, EMAIL_TO

Comportamento:
- Erros registram stack trace completo no log (ingest_*.log)
- E-mail enviado automaticamente se alguma tabela falhar
- Assunto: [ALERTA] Falha na ingestao API Transferencias Especiais
- Corpo: lista de tabelas com erro + stack trace de cada uma

Se SMTP_HOST ou EMAIL_TO nao estiverem configurados, apenas loga aviso.
```

---

## Dicas de uso no Claude Code

- Inicie sempre com `PROMPT 1` em um projeto novo
- O `CLAUDE.md` é lido automaticamente pelo Claude Code — ele já sabe o contexto
- Para debugar uma requisição à API manualmente:
  ```bash
  curl "https://api-publica.transferegov.gestao.gov.br/especiais/programas_especiais?tamanho_da_pagina=5" | python -m json.tool
  ```
