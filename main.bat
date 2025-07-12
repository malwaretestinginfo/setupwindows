@echo off & setlocal enabledelayedexpansion

echo Starte Setup-Script... Druecke eine beliebige Taste.
pause >nul

:: Pruefe Administratorrechte, starte neu wenn nicht
net session >nul 2>&1 || (
    echo Erhalte Administratorrechte...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Maximized"
    exit /b
)

:: Maximales Konsolenfenster
powershell -NoProfile -Command "$hwnd = (Get-Process -Id $PID).MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr hWnd,int cmd);' -Name Win -Namespace WinAPI; [WinAPI.Win]::ShowWindow($hwnd,3)"

echo Script laeuft mit Admin-Rechten. Druecke eine Taste zum Fortfahren.
pause >nul

:: Setze PowerShell ExecutionPolicy
echo Setze PS ExecutionPolicy auf RemoteSigned...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: Desktop-Pfad
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden. Druecke eine Taste zum Beenden.
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
    set "URL=!URL_%%A!"
    if "%%A"=="BRAVE" set "OUT=%DEST%\BraveBrowserSetup-BRV013.exe"
    if "%%A"=="EDGE" set "OUT=%DEST%\Edge.bat"
    if "%%A"=="NINITE" set "OUT=%DEST%\ninite.exe"
    if "%%A"=="DEBLOAT" set "OUT=%DEST%\Win11Debloat.ps1"
    echo Lade %%A nach %%OUT%%...
    powershell -NoProfile -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing"
    if errorlevel 1 (
        echo Fehler beim Download von %%A. Druecke eine Taste zum Beenden.
        pause >nul
        exit /b 1
    )
)

:: Debloat-Skript ausfuehren
echo Führe Win11Debloat aus...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"
if errorlevel 1 echo Achtung: Debloat-Skript fehlgeschlagen.

echo Starte Installationsprogramme...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"
start /wait "%DEST%\Edge.bat"
start /wait "%DEST%\ninite.exe"

echo Setze PS ExecutionPolicy zurueck auf Default...
powershell -NoProfile -Command "if((Get-ExecutionPolicy) -eq 'RemoteSigned'){Set-ExecutionPolicy Default -Force}"

echo Alle Schritte abgeschlossen. PC wird in 10 Sekunden neu gestartet...
timeout /t 10 /nobreak >nul
shutdown /r /t 0

pause >nul
