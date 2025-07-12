@echo off & setlocal enabledelayedexpansion

:: Adminrechte prüfen und als Admin neu starten (maximiert, /k für offene Konsole)
net session >nul 2>&1 || (
    echo Erhalte Administratorrechte...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k "%~f0"' -Verb RunAs -WindowStyle Maximized"
    exit /b
)

:: Pause für Debugging
pause

:: Zielordner Desktop
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden.
    pause
    exit /b 1
)

:: Powershell ExecutionPolicy setzen
echo Setze ExecutionPolicy auf RemoteSigned...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: URL-Definitionen
set "FILES=BraveBrowserSetup-BRV013.exe Edge.bat ninite.exe Win11Debloat.ps1"
set "URL1=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL2=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL3=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "URL4=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:: Funktion zum Herunterladen
:downloadFile
set "URL=%~1" & set "OUT=%DEST%\%~2"
echo.
echo Lade %~2...
powershell -NoProfile -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing"
if errorlevel 1 (
    echo Fehler beim Herunterladen von %~2. Versuche erneut...
    goto downloadFile %URL% %~2
)
exit /b 0

:: Downloads ausführen
call :downloadFile %URL1% BraveBrowserSetup-BRV013.exe
call :downloadFile %URL2% Edge.bat
call :downloadFile %URL3% ninite.exe
call :downloadFile %URL4% Win11Debloat.ps1

:: Debloat-Skript ausführen
echo Starte Win11Debloat...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"

:: Installer starten
for %%F in (BraveBrowserSetup-BRV013.exe Edge.bat ninite.exe) do (
    echo Starte %%F...
    start /wait "%DEST%\%%F"
)

:: ExecutionPolicy zurücksetzen
echo Setze ExecutionPolicy auf Default...
powershell -NoProfile -Command "if((Get-ExecutionPolicy) -eq 'RemoteSigned'){Set-ExecutionPolicy Default -Force}"

:: Neustart ankündigen
echo Alle Installationen abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak
shutdown /r /t 0

pause
