@echo off
setlocal enabledelayedexpansion

:: Prüfe auf Administratorrechte
net session >nul 2>&1 || (
    echo Bitte gewähre Administratorrechte...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Maximales Konsolenfenster
powershell -NoProfile -Command "$hwnd = (Get-Process -Id $PID).MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr hWnd,int cmd);' -Name a -Namespace b; [b.a]::ShowWindow($hwnd,3)"

:: Debug-Pause für Sichtbarkeit
echo Script wurde mit Admin-Rechten gestartet.
pause

:: Setze ExecutionPolicy auf RemoteSigned
echo Setze PS ExecutionPolicy auf RemoteSigned...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: Zielordner Desktop
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden.
    pause
    exit /b 1
)

:: URLs
set "URL_BRAVE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL_EDGE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL_NINITE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "URL_DEBLOAT=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:: Download-Funktion
for %%A in (BRAVE EDGE NINITE DEBLOAT) do (
    set "URL=!URL_%%A!"
    set "OUT=%DEST%\%%A"
    if "%%A"=="BRAVE" set "OUT=%DEST%\BraveBrowserSetup-BRV013.exe"
    if "%%A"=="EDGE" set "OUT=%DEST%\Edge.bat"
    if "%%A"=="NINITE" set "OUT=%DEST%\ninite.exe"
    if "%%A"=="DEBLOAT" set "OUT=%DEST%\Win11Debloat.ps1"
    echo Lade %%A...
    powershell -NoProfile -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing"
    if errorlevel 1 (
        echo Fehler beim Download von %%A. Abbruch.
        pause
        exit /b 1
    )
)

:: Debloat-Skript ausführen
echo Führe Win11Debloat aus...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"
if errorlevel 1 (
    echo Debloat-Skript fehlgeschlagen.
    pause
)

:: Installationen
echo Starte Installationen...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"
start /wait "%DEST%\Edge.bat"
start /wait "%DEST%\ninite.exe"

:: ExecutionPolicy zurücksetzen
echo Setze PS ExecutionPolicy auf Default...
powershell -NoProfile -Command "if((Get-ExecutionPolicy) -eq 'RemoteSigned'){Set-ExecutionPolicy Default -Force}"

:: Neustart ankündigen
echo Alle Vorgänge abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak
shutdown /r /t 0

pause
