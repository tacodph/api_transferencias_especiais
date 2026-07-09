# Projeto: Ingestão API Transferências Especiais do Transferegov

## Visão Geral

Rotina Python que consome a API pública de Transferências Especiais do Transferegov e
persiste os dados no banco corporativo do MCID.

## Arquitetura

```
API (PostgREST)
https://api.transferegov.dth.api.gov.br/transferenciasespeciais/
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
| `01_ddl_schema.sql` | DDL para criar o schema e as 16 tabelas no banco |
| `requirements.txt` | Dependências Python |
| `CLAUDE.md` | Este arquivo — contexto do projeto |

## API: Detalhes Técnicos

- **Tecnologia**: PostgREST 11.2 (dados abertos, sem autenticação)
- **Base URL**: `https://api.transferegov.dth.api.gov.br/transferenciasespeciais/`
- **Documentação Swagger**: `https://docs.api.transferegov.gestao.gov.br/transferenciasespeciais/`
- **Paginação**: via parâmetros `limit` e `offset` (padrão: 1000 registros/página)
- **Ordenação**: parâmetro `order=nome_coluna`
- **Filtros**: operadores PostgREST (ex: `?ano_programa=eq.2024`)

### Endpoints (16 tabelas)

| Endpoint | Chave Primária | Descrição |
|---|---|---|
| `/programa_especial` | id_programa | Programas (nível mais alto) |
| `/plano_acao_especial` | id_plano_acao | Planos de Ação (ligados ao programa) |
| `/empenho_especial` | id_empenho | Notas de Empenho |
| `/documento_habil_especial` | id_dh | Documentos Hábeis |
| `/ordem_pagamento_ordem_bancaria_especial` | id_op_ob | Ordens de Pagamento/Bancárias |
| `/historico_pagamento_especial` | id_historico_op_ob | Histórico de pagamentos |
| `/relatorio_gestao_especial` | id_relatorio_gestao | Relatórios de Gestão |
| `/relatorio_gestao_novo_especial` | id_relatorio_gestao_novo | Relatórios de Gestão (novo modelo) |
| `/meta_especial` | (id_executor, id_meta) | Metas dos Executores |
| `/executor_especial` | (id_plano_acao, id_executor) | Executores |
| `/plano_trabalho_especial` | id_plano_trabalho | Planos de Trabalho |
| `/finalidade_especial` | (id_executor, cd_*) | Finalidades/Áreas de Política Pública |
| `/plano_trabalho_analise_especial` | id_plano_trabalho_analise | Análises dos Planos |
| `/orgao_analise_pendente_especial` | (id_plano_trabalho, id_orgao_*) | Órgãos com análise pendente |
| `/plano_trabalho_historico_especial` | (id_plano_trabalho_hist, id_plano_trabalho) | Histórico dos Planos |
| `/plano_trabalho_analise_historico_especial` | (id_plano_trabalho_analise, codigo_siorg_*, data_analise_*) | Histórico das Análises |

### Hierarquia dos dados

```
programa_especial (1)
  └── plano_acao_especial (N)          [id_programa → id_plano_acao]
        ├── empenho_especial (N)        [id_plano_acao → id_empenho]
        │     └── documento_habil_especial (N) [id_empenho → id_dh]
        │           └── ordem_pagamento_ordem_bancaria_especial (N) [id_dh → id_op_ob]
        │                 └── historico_pagamento_especial (N) [id_op_ob]
        ├── relatorio_gestao_especial (N)
        ├── relatorio_gestao_novo_especial (N)
        └── executor_especial (N)       [id_plano_acao → id_executor]
              ├── meta_especial (N)     [id_executor]
              └── finalidade_especial (N) [id_executor]
                    └── plano_trabalho_especial (1:1)
                          ├── plano_trabalho_analise_especial (N)
                          │     └── plano_trabalho_analise_historico_especial (N)
                          ├── plano_trabalho_historico_especial (N)
                          └── orgao_analise_pendente_especial (N)
```

## Banco de Dados: Destino

- **Host**: campinas.cidades.gov.br
- **Schema**: `se_api_transferencias_especiais`
- **Banco**: configurar via variável de ambiente `DB_NAME`
- **Estratégia de carga**: UPSERT (INSERT ... ON CONFLICT DO UPDATE)
- **Coluna de controle**: `dt_carga TIMESTAMP` em todas as tabelas
- **Log de execução**: tabela `controle_carga`

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
-- Conectar ao banco e executar:
\i 01_ddl_schema.sql
```

### 4. Executar a ingestão

```bash
# Todas as tabelas
python ingest_transferencias.py

# Apenas uma tabela
python ingest_transferencias.py --tabela programa_especial

# Carga incremental (ultimos N dias; ver docs/carga_incremental.md)
python ingest_transferencias.py --dias
python ingest_transferencias.py --dias 14 --tabela historico_pagamento_especial

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
ORDER BY tablename;

-- Checar log de cargas
SELECT * FROM se_api_transferencias_especiais.controle_carga
ORDER BY dt_inicio DESC LIMIT 20;
```

## Agendamento (cron)

Para carga diária às 6h:

```bash
# Editar crontab
crontab -e

# Adicionar linha:
0 6 * * * cd /caminho/do/projeto && python ingest_transferencias.py >> cron.log 2>&1
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
