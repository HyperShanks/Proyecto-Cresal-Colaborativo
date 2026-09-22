@echo off
echo =======================================================
echo  1/2: Compilando Cresal App para Windows en Release...
echo =======================================================
cd /d "%~dp0"
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Fallo la compilacion de Flutter para Windows.
    pause
    exit /b %errorlevel%
)

echo.
echo =======================================================
echo  2/2: Generando Instalador Cresal_Setup.exe con Inno Setup...
echo =======================================================
set ISCC_PATH="C:\Program Files (x86)\Inno Setup 6\iscc.exe"
if exist %ISCC_PATH% (
    %ISCC_PATH% "%~dp0windows\installer\cresal_setup.iss"
) else (
    iscc "%~dp0windows\installer\cresal_setup.iss"
)

if %errorlevel% neq 0 (
    echo.
    echo [ADVERTENCIA] No se pudo ejecutar el compilador de Inno Setup automaticamente.
    echo Si aun no has instalado Inno Setup 6, descargalo gratis en:
    echo https://jrsoftware.org/isdl.php
    echo O abre windows\installer\cresal_setup.iss directamente desde Inno Setup GUI.
    pause
    exit /b %errorlevel%
)

echo.
echo =======================================================
echo  [EXITO] Instalador generado correctamente en:
echo  frontend\build\installer\Cresal_Setup.exe
echo =======================================================
pause
