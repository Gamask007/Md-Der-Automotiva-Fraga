@echo off
chcp 65001 >nul
title Sistema da Oficina Fraga
cd /d "%~dp0"
rem Pasta do MySQL portátil (troque aqui se instalar o MySQL em outro lugar)
set MYSQL=C:\Users\black\Tools\mysql-8.4.13-winx64
set DADOS=C:\Users\black\Tools\mysql-data

echo ==============================================
echo    SISTEMA DA OFICINA FRAGA
echo    Deixe esta janela aberta enquanto usar.
echo    Para desligar, feche esta janela.
echo ==============================================
echo.

rem 1) Liga o banco de dados, se ainda não estiver ligado
tasklist /FI "IMAGENAME eq mysqld.exe" | find /I "mysqld.exe" >nul
if errorlevel 1 (
  echo Ligando o banco de dados...
  start /b "" "%MYSQL%\bin\mysqld.exe" --basedir="%MYSQL%" --datadir="%DADOS%" --port=3307 --bind-address=127.0.0.1 --mysqlx=OFF --log-error="%DADOS%\erros.log"
)

rem espera o banco responder (até 30 segundos)
set /a TENTATIVA=0
:espera
"%MYSQL%\bin\mysqladmin.exe" -uroot -h127.0.0.1 -P3307 ping >nul 2>&1
if not errorlevel 1 goto pronto
set /a TENTATIVA+=1
if %TENTATIVA% GEQ 30 (
  echo Não consegui ligar o banco de dados. Chame o suporte.
  pause
  exit /b 1
)
timeout /t 1 /nobreak >nul
goto espera
:pronto

rem 2) Se o banco da oficina ainda não existe, cria com os dados de exemplo
"%MYSQL%\bin\mysql.exe" -uroot -h127.0.0.1 -P3307 -N -e "SHOW DATABASES LIKE 'fraga_oficina'" | find "fraga_oficina" >nul
if errorlevel 1 (
  echo Criando o banco da oficina pela primeira vez...
  "%MYSQL%\bin\mysql.exe" -uroot -h127.0.0.1 -P3307 --default-character-set=utf8mb4 < "..\..\docs\script.sql" >nul
)

rem 3) Instala as peças do sistema na primeira vez
if not exist node_modules (
  echo Preparando o sistema pela primeira vez...
  call npm install --no-audit --no-fund >nul
)

rem 4) Abre o navegador e liga o sistema
echo Abrindo o sistema no navegador...
set ABRIR_NAVEGADOR=1
node server.js
