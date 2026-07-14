# Ingestão API Transferências Especiais — Resumo do Projeto

## Modelo atual

- **API**: `https://api-publica.transferegov.gestao.gov.br/especiais`
- **20 tabelas** `*_especiais` no schema `se_api_transferencias_especiais`
- **Script**: `ingest_transferencias.py` (paginação `pagina`/`tamanho_da_pagina`, upsert, `--dias`, `--workers`)
- **DDL**: `data/04_ddl_schema_novo.sql` + `data/07_controle_carga_v2.sql`
- **Docs de comando**: `agentes/CLAUDE.md`, `docs/carga_incremental.md`, `docs/agendamento_windows.md`

## Como validar

```bash
python ingest_transferencias.py --tabela programas_especiais
```

Carga completa:

```bash
python ingest_transferencias.py --workers 4
```
