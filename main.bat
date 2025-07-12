@echo off & setlocal enabledelayedexpansion

:: Start-Pause für Visibility
echo Starte Setup-Script... Drücke eine Taste.
pause >nul

:: Prüfe Adminrechte und starte neu als Admin (maximiert)
net session >nul 2>&1 || (
    echo Erhalte Administratorrechte...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Maximized"
    exit /b
)

:: Maximieren des Konsolenfensters
powershell -NoProfile -Command "$hwnd=(Get-Process -Id $PID).MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr, int);' -Name WinAPI -Namespace Win; [WinAPI.WinAPI]::ShowWindow($hwnd,3)"

echo Skript läuft mit Admin-Rechten. Drücke eine Taste zum Fortfahren.
pause >nul

:: PowerShell ExecutionPolicy setzen
echo Setze PS ExecutionPolicy auf RemoteSigned...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: Zielordner Desktop
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden. Skript beendet.
    pause >nul
    exit /b 1
)

:: URLs definieren
set "URL_BRAVE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL_EDGE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL_NINITE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "URL_DEBLOAT=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:: Dateien herunterladen
for %%A in (BRAVE EDGE NINITE DEBLOAT) do (
    call set "URL=%%URL_%%A%%%"
    if "%%A"=="BRAVE" ( set "OUT=%DEST%\BraveBrowserSetup-BRV013.exe" )
    if "%%A"=="EDGE"  ( set "OUT=%DEST%\Edge.bat" )
    if "%%A"=="NINITE"( set "OUT=%DEST%\ninite.exe" )
    if "%%A"=="DEBLOAT"( set "OUT=%DEST%\Win11Debloat.ps1" )
    echo Lade %%A herunter nach %OUT%...
    powershell -NoProfile -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing"
    if errorlevel 1 (
        echo Fehler beim Download von %%A. Skript beendet.
        pause >nul
        exit /b 1
    )
)

:: Debloat-Skript ausführen
echo Führe Win11Debloat-Skript aus...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"
if errorlevel 1 echo Warnung: Debloat-Skript-Fehler.

:: Installationsprogramme starten
echo Starte Installationsprogramme...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"
start /wait "%DEST%\Edge.bat"
start /wait "%DEST%\ninite.exe"

:: ExecutionPolicy zurücksetzen
echo Setze PS ExecutionPolicy zurück auf Default...
powershell -NoProfile -Command "if((Get-ExecutionPolicy) -eq 'RemoteSigned'){Set-ExecutionPolicy Default -Force}"

:: Neustart ankündigen
echo Alle Schritte abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak >nul
shutdown /r /t 0

pause >nul
