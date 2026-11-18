# Projeto: Ingestão API Transferências Especiais do Transferegov

## Visão Geral

Rotina Python que consome a API pública de Transferências Especiais do Transferegov e
persiste os dados no banco corporativo do MCID.

## Arquitetura

```
API (dados abertos)
https://api-publica.transferegov.gestao.gov.br/especiais
        │
        ▼
ingest_transferencias.py   ← script principal
        │
        ▼
PostgreSQL: campinas.cidades.gov.br
Schema: se_api_transferencias_especiais
```

## Arquivos do Projeto

| Arquivo | Descrição |
|---|---|
| `ingest_transferencias.py` | Script principal de ingestão (fetch + upsert) |
| `data/04_ddl_schema_novo.sql` | DDL das 20 tabelas do modelo atual |
| `data/07_controle_carga_v2.sql` | Controle de carga (`controle_carga` / `controle_carga_dia`) |
| `data/09_hash_inativacao_parlamentar.sql` | `row_hash` / `fl_ativo` / `dt_inativacao` nas 20 tabelas + `vw_emendas_especiais_parlamentar` |
| `parlamentar_especiais.py` | Liga as emendas dos planos de ação ao parlamentar pelo código do autor |
| `docs/EMENDAS_PARLAMENTAR.md` | Regras do upsert com hash, da inativação e do parlamentar |
| `requirements.txt` | Dependências Python |
| `agentes/CLAUDE.md` | Este arquivo — contexto do projeto |

## API: Detalhes Técnicos

- **Base URL**: `https://api-publica.transferegov.gestao.gov.br/especiais`
- **Paginação**: `pagina` + `tamanho_da_pagina` (máx. 200)
- **Filtros de data**: igualdade `campo=YYYY-MM-DD` (sem `gte.`); incremental via loop diário

### Endpoints principais (20 tabelas)

Ver mapa completo em `docs/prompt1_mapa_e_chaves_v2.md`. Exemplos:  
`/programas_especiais`, `/planos_acao_especiais`, `/empenhos_especiais`,  
`/gestao_financeira_lancamentos_especiais`, `/beneficiarios_especiais`.

## Banco de Dados: Destino

- **Host**: campinas.cidades.gov.br
- **Schema**: `se_api_transferencias_especiais`
- **Banco**: configurar via variável de ambiente `DB_NAME`
- **Estratégia de carga**: UPSERT (INSERT ... ON CONFLICT DO UPDATE) só quando o `row_hash` muda;
  carga completa inativa (`fl_ativo = false`) o que sumiu da API. Consultas devem filtrar `fl_ativo`.
  Ver `docs/EMENDAS_PARLAMENTAR.md`
- **Parlamentar**: pelo código do autor, em `transfere_pro_transferegov.tab_autores_emendas` /
  `tab_parlamentares` (mesmo banco). Consulta: `vw_emendas_especiais_parlamentar`
- **Coluna de controle**: `dt_carga TIMESTAMP` em todas as tabelas
- **Log de execução**: `controle_carga` + `controle_carga_dia`

## Como Executar

### 1. Pré-requisitos

```bash
pip install requests psycopg2-binary
# ou
pip install -r requirements.txt
```

### 2. Configurar conexão com o banco

```bash
export DB_HOST=campinas.cidades.gov.br
export DB_PORT=5432
export DB_NAME=nome_do_banco
export DB_USER=usuario
export DB_PASSWORD=senha
```

Ou edite as constantes diretamente no início de `ingest_transferencias.py`.

### 3. Criar as tabelas (executar apenas uma vez)

```sql
-- Schema novo (20 tabelas):
\i data/04_ddl_schema_novo.sql
\i data/07_controle_carga_v2.sql
\i data/08_fix_tipos_gestao_financeira.sql
\i data/09_hash_inativacao_parlamentar.sql
```

### 4. Executar a ingestão

```bash
# Todas as tabelas (modelo atual)
python ingest_transferencias.py

# Apenas uma tabela
python ingest_transferencias.py --tabela programas_especiais

# Carga incremental (ultimos N dias; ver docs/carga_incremental.md)
python ingest_transferencias.py --dias
python ingest_transferencias.py --dias 14 --tabela empenhos_especiais

# Só religar as emendas ao parlamentar (código do autor), sem chamar a API
python ingest_transferencias.py --parlamentares

# Paralelismo por nivel hierarquico (padrao: 4 workers)
python ingest_transferencias.py --workers 4
python ingest_transferencias.py --workers 1   # sequencial

# Ver logs
tail -f ingest_*.log
```

### 5. Verificar resultado

```sql
-- Checar registros por tabela
SELECT 
    schemaname, tablename,
    n_live_tup AS registros
FROM pg_stat_user_tables
WHERE schemaname = 'se_api_transferencias_especiais'
  AND tablename LIKE '%\_especiais' ESCAPE '\'
ORDER BY tablename;

-- Checar log de cargas
SELECT * FROM se_api_transferencias_especiais.controle_carga
ORDER BY dt_inicio DESC LIMIT 20;

SELECT * FROM se_api_transferencias_especiais.controle_carga_dia
ORDER BY id DESC LIMIT 5;
```

## Agendamento (cron)

Para carga diária às 6h:

```bash
# Editar crontab
crontab -e

# Adicionar linha:
0 6 * * * cd /caminho/do/projeto && python ingest_transferencias.py --workers 4 --dias 7 >> cron.log 2>&1
```

## Convenções de Código

- Python 3.10+
- Tipo de dados: manter os tipos originais da API (sem conversões desnecessárias)
- Erros: logar e continuar para próxima tabela (não abortar toda a carga)
- Lotes: upsert em lotes de 5.000 registros para controlar memória
- Variáveis de ambiente para credenciais (nunca hardcode de senhas)

## Possíveis Melhorias Futuras

1. ~~**Carga incremental**: filtrar por data de modificação (quando a API suportar)~~ — implementado via `--dias` (ver `docs/carga_incremental.md`)
2. ~~**Paralelismo**: processar múltiplas tabelas simultaneamente com `concurrent.futures`~~ — implementado via `--workers` (padrão: 4)
3. **Notificações**: enviar e-mail ou alerta no Teams em caso de erro
4. **Monitoramento**: integrar com Grafana via tabela `controle_carga`
5. **Testes**: adicionar testes unitários para as funções de fetch e upsert
