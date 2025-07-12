@echo off & setlocal enabledelayedexpansion

:: Start-Pause für Sichtbarkeit
echo Starte Setup-Script... Drücke eine Taste.
pause >nul

:: Adminrechte prüfen und als Admin neu starten
net session >nul 2>&1 || (
    echo Erhalte Administratorrechte...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Maximized"
    exit /b
)

:: Konsole maximieren
powershell -NoProfile -Command "$hwnd=(Get-Process -Id $PID).MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr,int);' -Name Win -Namespace WinAPI; [WinAPI.Win]::ShowWindow($hwnd,3)"

echo Skript läuft mit Admin-Rechten. Drücke eine Taste zum Fortfahren.
pause >nul

:: PS ExecutionPolicy setzen
echo Setze PS ExecutionPolicy auf RemoteSigned...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: Desktop-Pfad prüfen
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden. Skript beendet.
    pause >nul
    exit /b 1
)

:: URLs
set "URL_BRAVE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL_EDGE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL_NINITE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "URL_DEBLOAT=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:: Herunterladen
echo Lade BraveDownloader...
echo URL: !URL_BRAVE! Out: !DEST!\BraveBrowserSetup-BRV013.exe
powershell -NoProfile -Command "Invoke-WebRequest '!URL_BRAVE!' -OutFile '!DEST!\BraveBrowserSetup-BRV013.exe' -UseBasicParsing"
if errorlevel 1 ( echo Fehler beim Download von Brave. Skript beendet.& pause>nul & exit /b 1 )

echo Lade Edge...
echo URL: !URL_EDGE! Out: !DEST!\Edge.bat
powershell -NoProfile -Command "Invoke-WebRequest '!URL_EDGE!' -OutFile '!DEST!\Edge.bat' -UseBasicParsing"
if errorlevel 1 ( echo Fehler beim Download von Edge. Skript beendet.& pause>nul & exit /b 1 )

echo Lade Ninite...
echo URL: !URL_NINITE! Out: !DEST!\ninite.exe
powershell -NoProfile -Command "Invoke-WebRequest '!URL_NINITE!' -OutFile '!DEST!\ninite.exe' -UseBasicParsing"
if errorlevel 1 ( echo Fehler beim Download von Ninite. Skript beendet.& pause>nul & exit /b 1 )

echo Lade Debloat Skript...
echo URL: !URL_DEBLOAT! Out: !DEST!\Win11Debloat.ps1
powershell -NoProfile -Command "Invoke-WebRequest '!URL_DEBLOAT!' -OutFile '!DEST!\Win11Debloat.ps1' -UseBasicParsing"
if errorlevel 1 ( echo Fehler beim Download von Debloat. Skript beendet.& pause>nul & exit /b 1 )

:: Debloat ausführen
echo Führe Win11Debloat aus...
powershell -NoProfile -ExecutionPolicy Bypass -File "!DEST!\Win11Debloat.ps1"
if errorlevel 1 echo Warnung: Debloat-Skript fehlgeschlagen.

:: Installationen starten
echo Starte BraveInstallation...
start /wait "!DEST!\BraveBrowserSetup-BRV013.exe"

echo Starte EdgeBatch...
start /wait "!DEST!\Edge.bat"

echo Starte Ninite...
start /wait "!DEST!\ninite.exe"

:: ExecutionPolicy zurücksetzen
echo Setze PS ExecutionPolicy zurück auf Default...
powershell -NoProfile -Command "if ((Get-ExecutionPolicy) -eq 'RemoteSigned') { Set-ExecutionPolicy Default -Force }"

:: Neustart ankündigen
echo Alle Schritte abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak >nul
shutdown /r /t 0

pause >nul
