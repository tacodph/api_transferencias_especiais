# Ingestão API Transferências Especiais — Resumo do Projeto

Aqui está o que foi criado, com base na leitura completa da documentação Swagger da API.

## Cowork vs Claude Code

Optei por uma abordagem híbrida — fiz a pesquisa e geração da estrutura base aqui no Cowork, e preparei tudo para que o desenvolvimento iterativo continue no Claude Code, que é mais adequado para testar conexões reais com banco, rodar scripts e iterar em erros.

## O que está nos arquivos

- **`01_ddl_schema.sql`** — DDL completo com as 16 tabelas mapeadas do Swagger, PKs corretas, tipos PostgreSQL, coluna `dt_carga` e tabela `controle_carga` para log de execução.
- **`ingest_transferencias.py`** — Script Python funcional com paginação automática (PostgREST `limit`/`offset`), upsert via `INSERT ... ON CONFLICT DO UPDATE`, retry automático em falhas de rede, processamento em lotes de 5.000 registros e log estruturado.
- **`CLAUDE.md`** — Contexto completo do projeto (hierarquia das tabelas, endpoints, como rodar) que o Claude Code lê automaticamente ao abrir a pasta.
- **`prompts_claude_code.md`** — 10 prompts prontos para evoluções: teste de conexão, carga incremental, paralelismo, agendamento com systemd, views analíticas e alertas por e-mail.

## Próximo passo

Coloque os 5 arquivos numa pasta no servidor, ajuste `DB_NAME`, `DB_USER` e `DB_PASSWORD` no script (ou via variáveis de ambiente), execute o DDL no banco e rode o comando abaixo para validar antes da carga completa:

```bash
python ingest_transferencias.py --tabela programa_especial
```

Se quiser evoluir o script a partir daí, abra a pasta no Claude Code e use os prompts numerados.
