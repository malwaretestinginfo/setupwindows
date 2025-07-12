@echo off
setlocal enabledelayedexpansion

:: Pruefe auf Adminrechte
net session >nul 2>&1 || (
    echo Starte mit Administratorrechten neu...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden.
    exit /b 1
)

set "URL1=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL2=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL3=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"

:downloadFile
set "URL=%~1"
set "OUT=%DEST%\%~2"

echo.
echo Downloading %~2 to Desktop...
PowerShell -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing -ProgressPreference Continue"
if errorlevel 1 (
    echo Fehler beim Herunterladen von %~2. Versuche erneut...
    goto downloadFile %URL% %~2
)
exit /b 0

call :downloadFile %URL1% BraveBrowserSetup-BRV013.exe
call :downloadFile %URL2% Edge.bat
call :downloadFile %URL3% ninite.exe

echo.
echo Starte Installationen von Desktop...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"
start /wait "%DEST%\Edge.bat"
start /wait "%DEST%\ninite.exe"

echo.
echo Alle Installationen abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak >nul
shutdown /r /t 0
