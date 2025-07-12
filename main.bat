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

:: Define path for temporary PowerShell script
set "PS_SCRIPT=%USERPROFILE%\Desktop\setup.ps1"
set "DEST=%USERPROFILE%\Desktop"
if not exist "%DEST%" (
    echo Desktop folder not found. Exiting.
    pause >nul
    exit /b 1
)

:: Create temporary PowerShell script
echo Creating temporary PowerShell GUI script...
(
echo # Check for admin privileges and relaunch as admin if needed
echo $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
echo if (-not $isAdmin) {
echo     Write-Host "Elevating to administrator..."
echo     Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
echo     exit
echo }
echo.
echo # Load Windows Forms
echo Add-Type -AssemblyName System.Windows.Forms
echo Add-Type -AssemblyName System.Drawing
echo.
echo # Create the main form
echo $form = New-Object System.Windows.Forms.Form
echo $form.Text = "Setup Assistant"
echo $form.Size = New-Object System.Drawing.Size(400, 300)
echo $form.StartPosition = "CenterScreen"
echo $form.FormBorderStyle = "FixedSingle"
echo $form.MaximizeBox = $false
echo.
echo # Create status label
echo $statusLabel = New-Object System.Windows.Forms.Label
echo $statusLabel.Location = New-Object System.Drawing.Point(10, 20)
echo $statusLabel.Size = New-Object System.Drawing.Size(360, 20)
echo $statusLabel.Text = "Ready to start installations."
echo $form.Controls.Add($statusLabel)
echo.
echo # Define desktop path
echo $desktopPath = [Environment]::GetFolderPath("Desktop")
echo if (-not (Test-Path $desktopPath)) {
echo     $statusLabel.Text = "Desktop folder not found. Exiting."
echo     [System.Windows.Forms.MessageBox]::Show("Desktop folder not found. Exiting.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
echo     $form.Close()
echo     exit
echo }
echo.
echo # Define download URLs
echo $urls = @{
echo     Brave = "https://referrals.brave.com/latest/BraveBrowserSetup.exe"
echo     Edge = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
echo     Ninite = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
echo     Debloat = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"
echo }
echo.
echo # Save original execution policy
echo $originalPolicy = Get-ExecutionPolicy -Scope LocalMachine
echo.
echo # Set execution policy to RemoteSigned
echo Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
echo $statusLabel.Text = "PowerShell execution policy set to RemoteSigned."
echo.
echo # Function to update status label
echo function Update-Status($message) {
echo     $statusLabel.Text = $message
echo     $statusLabel.Refresh()
echo }
echo.
echo # Function to download a file
echo function Download-File($url, $outputPath) {
echo     try {
echo         Update-Status "Downloading $(Split-Path $outputPath -Leaf)..."
echo         Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
echo         if (-not (Test-Path $outputPath)) {
echo             throw "File not found after download."
echo         }
echo         Update-Status "Downloaded $(Split-Path $outputPath -Leaf)."
echo         return $true
echo     } catch {
echo         Update-Status "Failed to download $(Split-Path $outputPath -Leaf): $($_.Exception.Message)"
echo         [System.Windows.Forms.MessageBox]::Show("Failed to download $(Split-Path $outputPath -Leaf): $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
echo         return $false
echo     }
echo }
echo.
echo # Function to run an installer
echo function Run-Installer($filePath, $isScript = $false) {
echo     try {
echo         Update-Status "Running $(Split-Path $filePath -Leaf)..."
echo         if ($isScript) {
echo             Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$filePath`"" -NoNewWindow
echo         } else {
echo             Start-Process -FilePath $filePath -Wait
echo         }
echo         Update-Status "Completed $(Split-Path $filePath -Leaf)."
echo     } catch {
echo         Update-Status "Failed to run $(Split-Path $filePath -Leaf): $($_.Exception.Message)"
echo         [System.Windows.Forms.MessageBox]::Show("Failed to run $(Split-Path $filePath -Leaf): $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
echo     }
echo }
echo.
echo # Create buttons
echo $braveButton = New-Object System.Windows.Forms.Button
echo $braveButton.Location = New-Object System.Drawing.Point(10, 60)
echo $braveButton.Size = New-Object System.Drawing.Size(360, 30)
echo $braveButton.Text = "Install Brave Browser"
echo $braveButton.Add_Click({
echo     $bravePath = Join-Path $desktopPath "BraveBrowserSetup.exe"
echo     if (Download-File $urls.Brave $bravePath) {
echo         Run-Installer $bravePath
echo     }
echo })
echo $form.Controls.Add($braveButton)
echo.
echo $edgeButton = New-Object System.Windows.Forms.Button
echo $edgeButton.Location = New-Object System.Drawing.Point(10, 100)
echo $edgeButton.Size = New-Object System.Drawing.Size(360, 30)
echo $edgeButton.Text = "Run Edge Batch"
echo $edgeButton.Add_Click({
echo     $edgePath = Join-Path $desktopPath "Edge.bat"
echo     if (Download-File $urls.Edge $edgePath) {
echo         Run-Installer $edgePath
echo     }
echo })
echo $form.Controls.Add($edgeButton)
echo.
echo $niniteButton = New-Object System.Windows.Forms.Button
echo $niniteButton.Location = New-Object System.Drawing.Point(10, 140)
echo $niniteButton.Size = New-Object System.Drawing.Size(360, 30)
echo $niniteButton.Text = "Install Ninite"
echo $niniteButton.Add_Click({
echo     $ninitePath = Join-Path $desktopPath "ninite.exe"
echo     if (Download-File $urls.Ninite $ninitePath) {
echo         Run-Installer $ninitePath
echo     }
echo })
echo $form.Controls.Add($niniteButton)
echo.
echo $debloatButton = New-Object System.Windows.Forms.Button
echo $debloatButton.Location = New-Object System.Drawing.Point(10, 180)
echo $debloatButton.Size = New-Object System.Drawing.Size(360, 30)
echo $debloatButton.Text = "Run Win11Debloat in Separate Window"
echo $debloatButton.Add_Click({
echo     $debloatPath = Join-Path $desktopPath "Win11Debloat.ps1"
echo     if (Download-File $urls.Debloat $debloatPath) {
echo         Update-Status "Launching Win11Debloat in a separate window..."
echo         Start-Process -FilePath "powershell" STS -ArgumentList "-NoProfile -Command `"Set-Location -Path '$desktopPath'; .\Win11Debloat.ps1 -ExecutionPolicy Bypass`"" -NoNewWindow
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
echo         Update-Status "Restarting system..."
echo         Restart-Computer -Force
echo     } else {
echo         Update-Status "Restart cancelled."
echo     }
echo })
echo $form.Controls.Add($restartButton)
echo.
echo # Form close event to restore execution policy
echo $form.Add_FormClosing({
echo     Update-Status "Restoring original PowerShell execution policy..."
echo     Set-ExecutionPolicy $originalPolicy -Scope LocalMachine -Force
echo })
echo.
echo # Show the form
echo $form.ShowDialog()
) > "%PS_SCRIPT%"

if errorlevel 1 (
    echo Failed to create PowerShell script. Exiting.
    pause >nul
    exit /b 1
)

:: Verify the PowerShell script was created
if not exist "%PS_SCRIPT%" (
    echo PowerShell script (setup.ps1) not found after creation. Exiting.
    pause >nul
    exit /b 1
)

:: Run the PowerShell script
echo Launching PowerShell GUI setup script...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "PS_EXIT_CODE=%errorlevel%"

:: Delete the temporary PowerShell script
echo Deleting temporary PowerShell script...
del "%PS_SCRIPT%" 2>nul
if exist "%PS_SCRIPT%" (
    echo Warning: Failed to delete temporary PowerShell script.
)

:: Check for PowerShell script execution errors
if %PS_EXIT_CODE% neq 0 (
    echo PowerShell script failed with exit code %PS_EXIT_CODE%. Check for errors.
    pause >nul
    exit /b %PS_EXIT_CODE%
)

echo PowerShell script completed. Press any key to exit.
pause >nul
