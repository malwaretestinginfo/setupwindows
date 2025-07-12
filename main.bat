@echo off
:: -----------------------------
:: 1) Self-elevation via UAC
:: -----------------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Erhöhe Rechte...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
echo Administrative Rechte bestätigt.

:: -----------------------------
:: 2) Download Edge.bat
:: -----------------------------
echo Lade Edge.bat herunter...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat' -OutFile '%~dp0Edge.bat'"

:: -----------------------------
:: 3) Download BraveBrowserSetup
:: -----------------------------
echo Lade BraveBrowserSetup-BRV013.exe herunter...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe' -OutFile '%~dp0BraveBrowserSetup-BRV013.exe'"

:: -----------------------------
:: 4) Ausführen von Edge.bat
:: -----------------------------
echo Starte Edge.bat...
call "%~dp0Edge.bat"

:: -----------------------------
:: 5) Ausführen von BraveBrowserSetup
:: -----------------------------
echo Starte BraveBrowserSetup-BRV013.exe...
start /wait "" "%~dp0BraveBrowserSetup-BRV013.exe"

:: -----------------------------
:: 6) Download und Ausführen Ninite-Installer
:: -----------------------------
echo Lade Ninite-Installer herunter...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Ninite%207Zip%20AnyDesk%20GIMP%20JDK%20AdoptOpenJDK%208%20Installer.exe' -OutFile '%~dp0Ninite-Installer.exe'"

echo Starte Ninite-Installer...
start /wait "" "%~dp0Ninite-Installer.exe"

echo.
echo Alle Schritte abgeschlossen!
pause
