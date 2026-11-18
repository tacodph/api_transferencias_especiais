# Upsert com hash, inativação e parlamentar (transferências especiais)

Mesmo padrão das emendas do Transferegov (`carga_arquivos_transferegov/docs/EMENDAS_PARLAMENTAR.md`),
adaptado à API: aqui a chave natural já é a PK de cada tabela `*_especiais`, então não há tabela nova
de dados. Entram três colunas em todas as 20 tabelas e uma view com o parlamentar.

DDL: `data/09_hash_inativacao_parlamentar.sql` (migration do transferepro
`transferencias_especiais/2026_10_23_110000_add_hash_inativacao_parlamentar_especiais.php`).

## Upsert com hash

- `row_hash` = md5 dos campos da API (na ordem em que vieram). O `INSERT ... ON CONFLICT DO UPDATE`
  só regrava a linha quando o hash muda ou quando ela estava inativa, e devolve quantas linhas eram
  novas e quantas mudaram (`controle_carga.qtd_registros_inseridos` / `qtd_registros_atualizados`).
- `dt_carga` passa a ser a última vez que a linha mudou.
- Na primeira carga depois do script 09 todas as linhas são regravadas uma vez (hash ainda nulo).

## Inativação

- Só numa carga **completa** da tabela (sem `--dias`, ou tabela sem campo de data) e só quando a
  varredura trouxe exatamente o `total_items` da API.
- Chave ativa que não veio → `fl_ativo = false`, `dt_inativacao = now()`. Se voltar, é reativada.
- Pulada (com aviso) se a API trouxe menos de 80% das linhas ativas.
- A carga com `--dias` só faz upsert; o que foi removido na origem é inativado na próxima carga completa
  (recomendação: completa semanal + `--dias` diária, como já estava).
- **Consultas devem filtrar `fl_ativo`.**

## Parlamentar

- `codigo_parlamentar_emenda_plano_acao` é o **código do autor**, o mesmo `left(nr_emenda, 4)` do siconv.
  O parlamentar fica em `transfere_pro_transferegov` (`tab_autores_emendas`, `tab_parlamentares`,
  `tab_parlamentares_alias`), mantidas pela carga de emendas.
- Depois de carregar `planos_acao_especiais`, `parlamentar_especiais.py`:
  1. grava códigos que lá ainda não existem (`origem = 'especiais'`) e dá nome a códigos sem nome;
     o nome do siconv nunca é sobrescrito;
  2. liga cada código a um parlamentar pelo alias do nome normalizado (cria o parlamentar se não houver);
  3. grava cada grafia desta fonte como alias do parlamentar do código;
  4. marca `tab_autores_emendas.fl_revisar` quando a grafia já pertence a outro parlamentar.
- Usa a mesma trava (`pg_advisory_xact_lock(7465100)`) das outras cargas que gravam parlamentar.
- Se as tabelas de parlamentar não existirem, o passo é pulado com aviso e a carga segue.

Para rodar só esse passo: `python ingest_transferencias.py --parlamentares`.

### vw_emendas_especiais_parlamentar

Uma linha por plano de ação ativo com emenda:

| Coluna | Origem |
| --- | --- |
| `ano_emenda` | `ano_emenda_parlamentar_plano_acao` |
| `cod_autor` | `codigo_parlamentar_emenda_plano_acao` com 4 dígitos (nulo se fora de 0..9999) |
| `nr_emenda` | `cod_autor` + sequencial com 4 dígitos: **mesmo formato do `nr_emenda` do siconv** |
| `id_parlamentar`, `nome_parlamentar` | `tab_autores_emendas` / `tab_parlamentares` |
| `nome_parlamentar_origem` | nome como veio da API |
| `fl_revisar` | código com nome conflitante entre fontes |
| `cnpj_beneficiario` etc. | `beneficiarios_especiais` ativo |

Junte por `id_parlamentar` ou `(ano_emenda, nr_emenda)`, nunca pelo nome. A view antiga
`vw_emenda_parlamentar_plano_acao_especial` continua igual até o app migrar.

## Conferência (só leitura)

```sql
-- o código do autor das especiais bate com o do siconv? (nomes lado a lado)
SELECT v.cod_autor, a.origem, a.nome_parlamentar AS nome_siconv,
       MIN(v.nome_parlamentar_origem) AS nome_especiais, COUNT(*) AS planos
FROM se_api_transferencias_especiais.vw_emendas_especiais_parlamentar v
JOIN transfere_pro_transferegov.tab_autores_emendas a ON a.cod_autor = v.cod_autor
GROUP BY 1, 2, 3
ORDER BY a.origem, planos DESC;

-- planos sem parlamentar e códigos para revisar
SELECT COUNT(*) FILTER (WHERE id_parlamentar IS NULL) AS sem_parlamentar,
       COUNT(*) FILTER (WHERE fl_revisar) AS revisar, COUNT(*) AS total
FROM se_api_transferencias_especiais.vw_emendas_especiais_parlamentar;

-- o formatado é ano + nr_emenda?
SELECT COUNT(*) FILTER (WHERE codigo_emenda_formatado = ano_emenda::text || nr_emenda) AS bate, COUNT(*) AS total
FROM se_api_transferencias_especiais.vw_emendas_especiais_parlamentar;
```
