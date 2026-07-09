@echo off
REM Wrapper para o Agendador de Tarefas do Windows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_ingest.ps1" %*
exit /b %ERRORLEVEL%
