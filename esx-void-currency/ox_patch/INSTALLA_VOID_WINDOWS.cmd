@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Installazione Void - ox_inventory

echo INSTALLAZIONE VOID PER OX_INVENTORY
echo Prima di continuare, il server deve essere spento.
echo.

if not exist "%~dp0apply-ox-patch.py" goto missing_files
if not exist "%~dp0void_currency.lua" goto missing_files
where py >nul 2>nul
if errorlevel 1 goto missing_python

set "VOID_PATCH_TARGET="
if not "%~1"=="" set "VOID_PATCH_TARGET=%~1"
if defined VOID_PATCH_TARGET goto have_target
if exist "%~dp0fxmanifest.lua" if exist "%~dp0modules\items\shared.lua" set "VOID_PATCH_TARGET=%~dp0"
if defined VOID_PATCH_TARGET goto have_target
if exist "%CD%\fxmanifest.lua" if exist "%CD%\modules\items\shared.lua" set "VOID_PATCH_TARGET=%CD%"
if defined VOID_PATCH_TARGET goto have_target

echo Incolla il percorso COMPLETO della cartella ox_inventory.
echo Non incollare il simbolo maggiore o altri comandi.
set /p "VOID_PATCH_TARGET=Percorso ox_inventory: "
if not defined VOID_PATCH_TARGET goto invalid_folder

:have_target
set "VOID_PATCH_TARGET=%VOID_PATCH_TARGET:"=%"
if not defined VOID_PATCH_TARGET goto invalid_folder
for %%I in ("%VOID_PATCH_TARGET%\.") do set "VOID_PATCH_TARGET=%%~fI"
if not exist "%VOID_PATCH_TARGET%\fxmanifest.lua" goto invalid_folder
if not exist "%VOID_PATCH_TARGET%\modules\items\shared.lua" goto invalid_folder
if not exist "%VOID_PATCH_TARGET%\modules\inventory\server.lua" goto invalid_folder

echo.
echo Cartella selezionata: "%VOID_PATCH_TARGET%"
echo.
py -3 "%~dp0apply-ox-patch.py" "%VOID_PATCH_TARGET%"
set "VOID_PATCH_RESULT=%ERRORLEVEL%"
echo.
if not "%VOID_PATCH_RESULT%"=="0" goto failed
echo OPERAZIONE COMPLETATA.
echo Installa anche es_extended modificato prima di riavviare il server.
echo Premi un tasto per chiudere.
pause >nul
exit /b 0

:missing_files
echo MANCANO I FILE. Prima usa ESTRAI TUTTO sullo ZIP scaricato.
echo INSTALLA_VOID_WINDOWS.cmd, apply-ox-patch.py e void_currency.lua
echo devono essere tutti nella stessa cartella.
goto stop_error

:missing_python
echo Python non e disponibile tramite il comando py.
echo Verifica che Python e Python Launcher siano installati.
goto stop_error

:invalid_folder
echo CARTELLA NON VALIDA. Seleziona la cartella ox_inventory vera.
echo Deve contenere fxmanifest.lua e la sottocartella modules.
echo Incolla solo il percorso, senza il simbolo maggiore finale.
goto stop_error

:failed
echo INSTALLAZIONE NON COMPLETATA. Leggi l'errore Python sopra.
echo Puoi copiare il messaggio di errore per ricevere assistenza.
echo Premi un tasto per chiudere.
pause >nul
exit /b %VOID_PATCH_RESULT%

:stop_error
echo Nessuna nuova installazione completata.
echo Premi un tasto per chiudere.
pause >nul
exit /b 1
