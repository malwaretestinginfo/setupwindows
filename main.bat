@echo off
setlocal enabledelayedexpansion

:: Adminrechte prüfen und als Admin neu starten (maximiert, mit /k für offene Konsole)
net session >nul 2>&1 || (
    echo Starte mit Administratorrechten und maximiert neu...
    powershell -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/k "%~f0"' -WorkingDirectory '%CD%' -WindowStyle Maximized" -Verb RunAs
    exit /b
)

:: Aktuelles Fenster maximieren
powershell -Command "$hwnd = Get-Process -Id $PID | Select-Object -ExpandProperty MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);' -Name Win -Namespace Win; [Win.Win]::ShowWindow($hwnd,3)"

set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop-Ordner nicht gefunden.
    pause
    exit /b 1
)

echo Setze PowerShell ExecutionPolicy auf RemoteSigned...
powershell -Command "Set-ExecutionPolicy RemoteSigned -Force"

set "URL1=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL2=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL3=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "DEBLOAT=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:downloadFile
set "URL=%~1"
set "OUT=%DEST%\%~2"

echo.
echo Lade %~2 auf den Desktop...
powershell -Command "Invoke-WebRequest '%URL%' -OutFile '%OUT%' -UseBasicParsing"
if errorlevel 1 (
    echo Fehler beim Herunterladen von %~2. Versuche erneut...
    goto downloadFile %URL% %~2
)
goto :eof

:: Downloads
call :downloadFile %URL1% BraveBrowserSetup-BRV013.exe
call :downloadFile %URL2% Edge.bat
call :downloadFile %URL3% ninite.exe
call :downloadFile %DEBLOAT% Win11Debloat.ps1

echo Starte Win11Debloat Skript...
powershell -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"

echo.
echo Starte Installationen vom Desktop...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"
start /wait "%DEST%\Edge.bat"
start /wait "%DEST%\ninite.exe"

echo.
echo Setze ExecutionPolicy zurück auf Default...
powershell -Command "if((Get-ExecutionPolicy) -eq 'RemoteSigned'){Set-ExecutionPolicy Default -Force}"

echo Alle Installationen abgeschlossen. Neustart in 10 Sekunden...
timeout /t 10 /nobreak >nul
shutdown /r /t 0

pause
