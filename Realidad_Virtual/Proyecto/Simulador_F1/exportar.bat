@echo off
rem ==========================================================================
rem  Genera el ejecutable de Windows del Simulador F1 sin abrir el editor.
rem  Resultado: ..\Ejecutable\SimuladorF1.exe (un solo archivo, PCK incrustado).
rem
rem  Antes de usarlo por primera vez, poné en GODOT la ruta de tu Godot 4.7
rem  (conviene la version "_console.exe", que muestra los mensajes aca).
rem  Las plantillas de exportacion 4.7 tienen que estar instaladas en el editor
rem  (Editor > Administrar plantillas de exportacion).
rem ==========================================================================

set "GODOT=C:\Godot\Godot_v4.7-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo No encuentro Godot en: %GODOT%
    echo Edita este archivo y corregi la variable GODOT.
    pause
    exit /b 1
)

cd /d "%~dp0"
if not exist "..\Ejecutable" mkdir "..\Ejecutable"

echo Exportando...
"%GODOT%" --headless --export-release "Windows Desktop" "..\Ejecutable\SimuladorF1.exe"
if errorlevel 1 (
    echo Hubo un error en la exportacion.
) else (
    echo Listo: ..\Ejecutable\SimuladorF1.exe
)
pause
