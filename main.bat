@echo off & setlocal enabledelayedexpansion

:: Start and pause for user visibility
echo Starting setup script... Press any key to continue.
pause >nul

:: Check for admin privileges and relaunch as admin if needed
net session >nul 2>&1 || (
    echo Elevating to administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Maximized"
    exit /b
)

:: Maximize the console window
powershell -NoProfile -Command "$hwnd=(Get-Process -Id $PID).MainWindowHandle; Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindow(IntPtr,int);' -Name WinAPI -Namespace Win; [WinAPI.WinAPI]::ShowWindow($hwnd,3)"

echo Script is running with admin privileges. Press any key to continue.
pause >nul

:: Set PowerShell execution policy to RemoteSigned
echo Configuring PowerShell execution policy...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Force"

:: Determine desktop folder
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop folder not found. Exiting.
    pause >nul
    exit /b 1
)

:: Define download URLs
set "URL_BRAVE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/BraveBrowserSetup-BRV013.exe"
set "URL_EDGE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
set "URL_NINITE=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
set "URL_DEBLOAT=https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"

:: Download files
echo Downloading Brave installer...
powershell -NoProfile -Command "Invoke-WebRequest '%URL_BRAVE%' -OutFile '%DEST%\BraveBrowserSetup-BRV013.exe' -UseBasicParsing"
if errorlevel 1 ( echo Failed to download Brave. Exiting.& pause>nul & exit /b 1 )

echo Downloading Edge batch...
powershell -NoProfile -Command "Invoke-WebRequest '%URL_EDGE%' -OutFile '%DEST%\Edge.bat' -UseBasicParsing"
if errorlevel 1 ( echo Failed to download Edge. Exiting.& pause>nul & exit /b 1 )

echo Downloading Ninite...
powershell -NoProfile -Command "Invoke-WebRequest '%URL_NINITE%' -OutFile '%DEST%\ninite.exe' -UseBasicParsing"
if errorlevel 1 ( echo Failed to download Ninite. Exiting.& pause>nul & exit /b 1 )

echo Downloading Win11Debloat script...
powershell -NoProfile -Command "Invoke-WebRequest '%URL_DEBLOAT%' -OutFile '%DEST%\Win11Debloat.ps1' -UseBasicParsing"
if errorlevel 1 ( echo Failed to download debloat script. Exiting.& pause>nul & exit /b 1 )

:: Run debloat script
echo Running Win11Debloat script...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\Win11Debloat.ps1"
if errorlevel 1 echo Warning: Debloat script encountered an error.

:: Execute installers
echo Installing Brave...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"

echo Running Edge batch...
start /wait "%DEST%\Edge.bat"

echo Running Ninite...
start /wait "%DEST%\ninite.exe"

:: Reset PowerShell execution policy
echo Resetting PowerShell execution policy...
powershell -NoProfile -Command "if (Get-ExecutionPolicy -Scope LocalMachine -EA SilentlyContinue -ErrorAction SilentlyContinue -eq 'RemoteSigned') { Set-ExecutionPolicy Default -Force }"

:: Announce restart and wait
echo All tasks completed. Restarting in 10 seconds...
timeout /t 10 /nobreak >nul
shutdown /r /t 0

pause >nul
