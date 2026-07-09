# Execucao agendada da ingestao API Transferencias Especiais
# Uso manual: powershell -ExecutionPolicy Bypass -File scripts\run_ingest.ps1

param(
    [string]$IngestArgs = "--workers 4 --dias 7"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$LogDir = Join-Path $ProjectDir "logs"
$LogFile = Join-Path $LogDir ("ingest_{0:yyyyMMdd}.log" -f (Get-Date))

function Find-Python {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "C:\Program Files\pgAdmin 4\python\python.exe",
        "py",
        "python"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -match "\\") {
            if (Test-Path $candidate) { return $candidate }
        } else {
            $found = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($found -and $found.Source -notmatch "WindowsApps") {
                return $found.Source
            }
        }
    }
    return $null
}

$python = Find-Python
if (-not $python) {
    Write-Error "Python nao encontrado. Instale Python ou ajuste Find-Python em run_ingest.ps1"
    exit 1
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Set-Location $ProjectDir

$header = @"
================================================================================
Ingestao iniciada: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Projeto: $ProjectDir
Python:  $python
Args:    ingest_transferencias.py $IngestArgs
================================================================================
"@

Add-Content -Path $LogFile -Value $header -Encoding UTF8

Write-Host $header

$argList = @("ingest_transferencias.py") + ($IngestArgs -split '\s+' | Where-Object { $_ })
& $python @argList 2>&1 | ForEach-Object {
    $line = $_.ToString()
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 0 }

$footer = "Ingestao finalizada: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | exit_code=$exitCode"
Add-Content -Path $LogFile -Value $footer -Encoding UTF8
Write-Host $footer

exit $exitCode
