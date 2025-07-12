@echo off & setlocal enabledelayedexpansion

:: Initialize log file with a random suffix to avoid conflicts
set "LOG_FILE=%TEMP%\setup_log_%RANDOM%.txt"
echo [%date% %time%] Starting batch script > "%LOG_FILE%"

:: Start and pause for user visibility
echo Starting setup script... Press any key to continue.
echo [%date% %time%] User prompted to start >> "%LOG_FILE%"
pause >nul

:: Check for admin privileges and relaunch as admin if needed
echo Checking for admin privileges...
echo [%date% %time%] Checking for admin privileges >> "%LOG_FILE%"
net session >nul 2>&1 || (
    echo Elevating to administrator...
    echo [%date% %time%] Elevating to administrator >> "%LOG_FILE%"
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
        echo Failed to elevate to administrator. Check %LOG_FILE% for details.
        echo [%date% %time%] Elevation failed >> "%LOG_FILE%"
        pause >nul
        exit /b 1
    )
    exit /b
)

echo Script is running with admin privileges. Press any key to continue.
echo [%date% %time%] Running with admin privileges >> "%LOG_FILE%"
pause >nul

:: Define path for temporary PowerShell script with a random suffix
set "PS_SCRIPT=%TEMP%\setup_%RANDOM%.ps1"
set "DEST=%USERPROFILE%\Desktop"
echo Checking desktop path: %DEST%
echo [%date% %time%] Desktop path: %DEST% >> "%LOG_FILE%"
if not exist "%DEST%" (
    echo Desktop folder not found at %DEST%. Exiting.
    echo [%date% %time%] Desktop folder not found >> "%LOG_FILE%"
    pause >nul
    exit /b 1
)

:: Create temporary PowerShell script
echo Creating temporary PowerShell GUI script at %PS_SCRIPT%...
echo [%date% %time%] Creating PowerShell script at %PS_SCRIPT% >> "%LOG_FILE%"
(
echo Add-Type -AssemblyName System.Windows.Forms
echo Add-Type -AssemblyName System.Drawing
echo.
echo $form = New-Object System.Windows.Forms.Form
echo $form.Text = "Setup Assistant"
echo $form.Size = New-Object System.Drawing.Size(400, 300)
echo $form.StartPosition = "CenterScreen"
echo.
echo $statusLabel = New-Object System.Windows.Forms.Label
echo $statusLabel.Location = New-Object System.Drawing.Point(10, 20)
echo $statusLabel.Size = New-Object System.Drawing.Size(360, 20)
echo $form.Controls.Add($statusLabel)
echo.
echo $desktopPath = [Environment]::GetFolderPath("Desktop")
echo $urls = @{
echo     Brave = "https://referrals.brave.com/latest/BraveBrowserSetup.exe"
echo     Edge = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
echo     Ninite = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
echo     Debloat = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"
echo }
echo.
echo function Update-Status($message) {
echo     $statusLabel.Text = $message
echo     $statusLabel.Refresh()
echo }
echo.
echo function Download-File($url, $outputPath) {
echo     try {
echo         Update-Status "Downloading $(Split-Path $outputPath -Leaf)..."
echo         Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
echo         Update-Status "Downloaded $(Split-Path $outputPath -Leaf)."
echo         return $true
echo     } catch {
echo         Update-Status "Failed to download: $_"
echo         return $false
echo     }
echo }
echo.
echo function Run-Installer($filePath, $isScript = $false) {
echo     try {
echo         Update-Status "Running $(Split-Path $filePath -Leaf)..."
echo         if ($isScript) {
echo             Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$filePath`""
echo         } else {
echo             Start-Process -FilePath $filePath -Wait
echo         }
echo         Update-Status "Completed $(Split-Path $filePath -Leaf)."
echo     } catch {
echo         Update-Status "Failed to run: $_"
echo     }
echo }
echo.
echo $braveButton = New-Object System.Windows.Forms.Button
echo $braveButton.Location = New-Object System.Drawing.Point(10, 60)
echo $braveButton.Size = New-Object System.Drawing.Size(360, 30)
echo $braveButton.Text = "Install Brave Browser"
echo $braveButton.Add_Click({
echo     $path = Join-Path $desktopPath "BraveBrowserSetup.exe"
echo     if (Download-File $urls.Brave $path) {
echo         Run-Installer $path
echo     }
echo })
echo $form.Controls.Add($braveButton)
echo.
echo $edgeButton = New-Object System.Windows.Forms.Button
echo $edgeButton.Location = New-Object System.Drawing.Point(10, 100)
echo $edgeButton.Size = New-Object System.Drawing.Size(360, 30)
echo $edgeButton.Text = "Run Edge Batch"
echo $edgeButton.Add_Click({
echo     $path = Join-Path $desktopPath "Edge.bat"
echo     if (Download-File $urls.Edge $path) {
echo         Run-Installer $path $true
echo     }
echo })
echo $form.Controls.Add($edgeButton)
echo.
echo $niniteButton = New-Object System.Windows.Forms.Button
echo $niniteButton.Location = New-Object System.Drawing.Point(10, 140)
echo $niniteButton.Size = New-Object System.Drawing.Size(360, 30)
echo $niniteButton.Text = "Install Ninite"
echo $niniteButton.Add_Click({
echo     $path = Join-Path $desktopPath "ninite.exe"
echo     if (Download-File $urls.Ninite $path) {
echo         Run-Installer $path
echo     }
echo })
echo $form.Controls.Add($niniteButton)
echo.
echo $debloatButton = New-Object System.Windows.Forms.Button
echo $debloatButton.Location = New-Object System.Drawing.Point(10, 180)
echo $debloatButton.Size = New-Object System.Drawing.Size(360, 30)
echo $debloatButton.Text = "Run Win11Debloat in Separate Window"
echo $debloatButton.Add_Click({
echo     $path = Join-Path $desktopPath "Win11Debloat.ps1"
echo     if (Download-File $urls.Debloat $path) {
echo         Update-Status "Launching Win11Debloat..."
echo         Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$path`""
echo         Update-Status "Win11Debloat launched."
echo     }
echo })
echo $form.Controls.Add($debloatButton)
echo.
echo $restartButton = New-Object System.Windows.Forms.Button
echo $restartButton.Location = New-Object System.Drawing.Point(10, 220)
echo $restartButton.Size = New-Object System.Drawing.Size(360, 30)
echo $restartButton.Text = "Restart System"
echo $restartButton.Add_Click({
echo     $result = [System.Windows.Forms.MessageBox]::Show("Do you want to restart now?", "Restart Prompt", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
echo     if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
echo         $global:shouldRestart = $true
echo         $form.Close()
echo     }
echo })
echo $form.Controls.Add($restartButton)
echo.
echo $shouldRestart = $false
echo $form.Add_FormClosing({
echo     if ($shouldRestart) {
echo         Restart-Computer -Force
echo     }
echo })
echo.
echo $form.ShowDialog()
) > "%PS_SCRIPT%" 2>> "%LOG_FILE%"

if errorlevel 1 (
    echo Failed to create PowerShell script at %PS_SCRIPT%. Check %LOG_FILE% for details.
    echo [%date% %time%] Failed to create PowerShell script >> "%LOG_FILE%"
    pause >nul
    exit /b 1
)

:: Verify the PowerShell script was created
if not exist "%PS_SCRIPT%" (
    echo PowerShell script not found after creation at %PS_SCRIPT%. Check %LOG_FILE%.
    echo [%date% %time%] PowerShell script not found after creation >> "%LOG_FILE%"
    pause >nul
    exit /b 1
)

:: Run the PowerShell script and wait for it to complete
echo Launching PowerShell GUI setup script from %PS_SCRIPT%...
echo [%date% %time%] Launching PowerShell script >> "%LOG_FILE%"
start /wait powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >> "%LOG_FILE%" 2>&1
set "PS_EXIT_CODE=%errorlevel%"

:: Delete the temporary PowerShell script
echo Deleting temporary PowerShell script at %PS_SCRIPT%...
echo [%date% %time%] Deleting PowerShell script >> "%LOG_FILE%"
del "%PS_SCRIPT%" 2>> "%LOG_FILE%"
if exist "%PS_SCRIPT%" (
    echo Warning: Failed to delete temporary PowerShell script at %PS_SCRIPT%.
    echo [%date% %time%] Failed to delete PowerShell script >> "%LOG_FILE%"
)

:: Check for PowerShell script execution errors
if %PS_EXIT_CODE% neq 0 (
    echo PowerShell script failed with exit code %PS_EXIT_CODE%. Check %LOG_FILE% for details.
    echo [%date% %time%] PowerShell script failed with exit code %PS_EXIT_CODE% >> "%LOG_FILE%"
    pause >nul
    exit /b %PS_EXIT_CODE%
)

echo All tasks completed successfully. Press any key to exit.
echo [%date% %time%] Script completed successfully >> "%LOG_FILE%"
pause >nul
