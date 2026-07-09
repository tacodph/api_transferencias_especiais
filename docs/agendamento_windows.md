# Agendamento no Windows — Transferências Especiais

Execução diária às **06:00** via Agendador de Tarefas.

## Arquivos

| Arquivo | Função |
|---------|--------|
| `scripts\run_ingest.ps1` | Script principal (Python, log, args) |
| `scripts\run_ingest.bat` | Wrapper para o Agendador de Tarefas |
| `logs\ingest_YYYYMMDD.log` | Log diário da execução agendada |

O `.env` na raiz do projeto é carregado automaticamente pelo `ingest_transferencias.py`.

## 1. Testar manualmente

No PowerShell, na pasta do projeto:

```powershell
cd d:\SE_CORPORATIVO\APIS\tranferencias_especiais
powershell -ExecutionPolicy Bypass -File scripts\run_ingest.ps1
```

Ou pelo batch:

```cmd
scripts\run_ingest.bat
```

Verifique o log:

```powershell
Get-Content logs\ingest_$(Get-Date -Format 'yyyyMMdd').log -Tail 30
```

### Argumentos customizados

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_ingest.ps1 -IngestArgs "--workers 4 --dias 14"
```

## 2. Criar tarefa agendada (linha de comando)

Substitua `DOMINIO\usuario` pela sua conta corporativa:

```cmd
schtasks /Create ^
  /TN "Ingest Transferencias Especiais" ^
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"d:\SE_CORPORATIVO\APIS\tranferencias_especiais\scripts\run_ingest.ps1\"" ^
  /SC DAILY ^
  /ST 06:00 ^
  /RU "DOMINIO\usuario" ^
  /RP *
```

O `/RP *` solicita a senha interativamente. Para tarefa que roda com usuário logado:

```cmd
schtasks /Create ^
  /TN "Ingest Transferencias Especiais" ^
  /TR "d:\SE_CORPORATIVO\APIS\tranferencias_especiais\scripts\run_ingest.bat" ^
  /SC DAILY ^
  /ST 06:00
```

## 3. Criar tarefa pelo Agendador de Tarefas (GUI)

1. Abra **Agendador de Tarefas** (`taskschd.msc`)
2. **Criar Tarefa...** (não “Criar Tarefa Básica”)
3. **Geral**
   - Nome: `Ingest Transferencias Especiais`
   - Marque: *Executar estando o usuário conectado ou não* (se precisar rodar sem login)
   - Marque: *Executar com privilégios mais altos* apenas se necessário
4. **Disparadores** → Novo → Diariamente às **06:00:00**
5. **Ações** → Novo → Iniciar um programa:
   - Programa: `powershell.exe`
   - Argumentos: `-NoProfile -ExecutionPolicy Bypass -File "d:\SE_CORPORATIVO\APIS\tranferencias_especiais\scripts\run_ingest.ps1"`
   - Iniciar em: `d:\SE_CORPORATIVO\APIS\tranferencias_especiais`
6. **Condições**: desmarque *Iniciar a tarefa somente se o computador estiver em energia CA* se for servidor sempre ligado
7. **Configurações**: marque *Executar tarefa o mais rápido possível após perder um agendamento*

## 4. Comandos úteis

```cmd
REM Executar agora (teste)
schtasks /Run /TN "Ingest Transferencias Especiais"

REM Ver status
schtasks /Query /TN "Ingest Transferencias Especiais" /V /FO LIST

REM Remover tarefa
schtasks /Delete /TN "Ingest Transferencias Especiais" /F
```

## 5. Verificar resultado no banco

```sql
SELECT tabela, status, dt_inicio, dt_fim, registros_lidos, mensagem
FROM se_api_transferencias_especiais.controle_carga
ORDER BY dt_inicio DESC
LIMIT 20;
```

## Observações

- A conta da tarefa precisa de **acesso de rede** a `campinas.cidades.gov.br` e à API `api.transferegov.dth.api.gov.br`.
- Se `python` não estiver no PATH da conta da tarefa, edite `Find-Python` em `run_ingest.ps1` com o caminho completo.
- O script também gera `ingest_YYYYMMDD_HHMMSS.log` na raiz do projeto (log interno do Python).
