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

echo Script is running with admin privileges. Press any key to continue.
pause >nul

:: Save the original PowerShell execution policy for LocalMachine
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine"') do set "original_policy=%%a"

:: Set PowerShell execution policy to RemoteSigned for LocalMachine
echo Configuring PowerShell execution policy...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

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

:: Execute installers
echo Installing Brave...
start /wait "%DEST%\BraveBrowserSetup-BRV013.exe"

echo Running Edge batch...
start /wait "%DEST%\Edge.bat"

echo Running Ninite...
start /wait "%DEST%\ninite.exe"

:: Restore original PowerShell execution policy
echo Restoring original PowerShell execution policy...
powershell -NoProfile -Command "Set-ExecutionPolicy %original_policy% -Scope LocalMachine -Force"

:: Prompt for restart
echo All tasks completed. Do you want to restart now? (Y/N)
choice /c YN /t 10 /d Y /m "Restarting in 10 seconds..."
if errorlevel 2 (
    echo Restart cancelled.
) else (
    shutdown /r /t 0
)

pause >nul
