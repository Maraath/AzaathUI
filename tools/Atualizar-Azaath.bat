@echo off
chcp 65001 >nul
cd /d "D:\ProjectAzaath"
if not exist "tools\.cache" mkdir "tools\.cache"
set "LOG=D:\ProjectAzaath\tools\.cache\atualizacao.log"
if exist "%LOG%" move /y "%LOG%" "%LOG%.anterior" >nul

call :main >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
type "%LOG%"
exit /b %RC%

:main
echo [Azaath] Inicio: %date% %time%

echo [Azaath] Verificando dados online...
node tools\map-extract\sync-online.js
if errorlevel 1 echo [Azaath] AVISO: download falhou; seguindo com os dados em cache.

if exist "D:\ProjectAzaath\tools\.cache\polestar\Polestar_QuestDB\Quests.lua" (
    set "POLESTAR_DB=D:\ProjectAzaath\tools\.cache\polestar\Polestar_QuestDB"
)

echo [Azaath] Atualizando banco de missoes, rotas e drops...
node tools\map-extract\questdb.js || goto :falha
node tools\map-extract\itemdrops.js || goto :falha
node tools\map-extract\tryhard-routes.js || goto :falha
rem missoes das masmorras: o cache do cliente ptBR traz as traducoes do que ja foi visto no jogo
node tools\map-extract\dungeonquests.js || goto :falha

if exist "D:\ProjectAzaath\tools\map-extract\extract.js" (
    echo [Azaath] Verificando mapas e areas do cliente...
    node tools\map-extract\extract.js || goto :falha
)

echo [Azaath] Sincronizando addons com a pasta do jogo...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Jogo.ps1" || goto :falha

echo [Azaath] Atualizacao concluida: %date% %time%
exit /b 0

:falha
echo [Azaath] ERRO no passo acima: atualizacao interrompida, nada mais foi copiado para o jogo.
exit /b 1
