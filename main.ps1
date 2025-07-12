# Set execution policy for the current process to bypass restrictions
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force

# Initialize log file
$logFile = "$env:TEMP\SetupAssistant_$(Get-Random).log"
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Starting SetupAssistant.ps1" | Out-File -FilePath $logFile -Append

# Check if running as administrator, relaunch if not
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Not running as admin, attempting to elevate..." | Out-File -FilePath $logFile -Append
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Elevation command issued" | Out-File -FilePath $logFile -Append
        exit
    } catch {
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Elevation failed: $_" | Out-File -FilePath $logFile -Append
        Write-Host "Failed to elevate to administrator: $_"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Running as administrator" | Out-File -FilePath $logFile -Append

# Load necessary assemblies for GUI
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Loaded System.Windows.Forms and System.Drawing" | Out-File -FilePath $logFile -Append
} catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to load assemblies: $_" | Out-File -FilePath $logFile -Append
    [System.Windows.Forms.MessageBox]::Show("Failed to load GUI assemblies: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Create the main form
try {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Setup Assistant"
    $form.Size = New-Object System.Drawing.Size(400, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Created main form" | Out-File -FilePath $logFile -Append
} catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to create form: $_" | Out-File -FilePath $logFile -Append
    [System.Windows.Forms.MessageBox]::Show("Failed to create GUI form: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Create a status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 20)
$statusLabel.Size = New-Object System.Drawing.Size(360, 20)
$statusLabel.Text = "Ready to start installations."
$form.Controls.Add($statusLabel)

# Define desktop path with fallback
$desktopPath = [Environment]::GetFolderPath("Desktop")
if (-not (Test-Path $desktopPath)) {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Desktop path not found, using TEMP: $env:TEMP" | Out-File -FilePath $logFile -Append
    $desktopPath = $env:TEMP
}
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Using desktop path: $desktopPath" | Out-File -FilePath $logFile -Append

# Define URLs for downloads
$urls = @{
    Brave = "https://referrals.brave.com/latest/BraveBrowserSetup.exe"
    Edge = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
    Ninite = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
    Debloat = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"
}

# Function to update status label
function Update-Status($message) {
    $statusLabel.Text = $message
    $statusLabel.Refresh()
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Status: $message" | Out-File -FilePath $logFile -Append
}

# Function to download a file
function Download-File($url, $outputPath) {
    try {
        Update-Status "Downloading $(Split-Path $outputPath -Leaf)..."
        Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
        if (-not (Test-Path $outputPath)) {
            throw "File not found after download"
        }
        Update-Status "Downloaded $(Split-Path $outputPath -Leaf)."
        return $true
    } catch {
        Update-Status "Failed to download $(Split-Path $outputPath -Leaf): $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to download $(Split-Path $outputPath -Leaf): $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Download failed: $_" | Out-File -FilePath $logFile -Append
        return $false
    }
}

# Function to run an installer or script
function Run-Installer($filePath, $isScript = $false) {
    try {
        Update-Status "Running $(Split-Path $filePath -Leaf)..."
        if ($isScript) {
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$filePath`""
        } else {
            Start-Process -FilePath $filePath -Wait
        }
        Update-Status "Completed $(Split-Path $filePath -Leaf)."
    } catch {
        Update-Status "Failed to run $(Split-Path $filePath -Leaf): $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to run $(Split-Path $filePath -Leaf): $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Run failed: $_" | Out-File -FilePath $logFile -Append
    }
}

# Button to install Brave Browser
$braveButton = New-Object System.Windows.Forms.Button
$braveButton.Location = New-Object System.Drawing.Point(10, 60)
$braveButton.Size = New-Object System.Drawing.Size(360, 30)
$braveButton.Text = "Install Brave Browser"
$braveButton.Add_Click({
    $path = Join-Path $desktopPath "BraveBrowserSetup.exe"
    if (Download-File $urls.Brave $path) {
        Run-Installer $path
    }
})
$form.Controls.Add($braveButton)

# Button to run Edge batch script
$edgeButton = New-Object System.Windows.Forms.Button
$edgeButton.Location = New-Object System.Drawing.Point(10, 100)
$edgeButton.Size = New-Object System.Drawing.Size(360, 30)
$edgeButton.Text = "Run Edge Batch"
$edgeButton.Add_Click({
    $path = Join-Path $desktopPath "Edge.bat"
    if (Download-File $urls.Edge $path) {
        Run-Installer $path $true
    }
})
$form.Controls.Add($edgeButton)

# Button to install Ninite
$niniteButton = New-Object System.Windows.Forms.Button
$niniteButton.Location = New-Object System.Drawing.Point(10, 140)
$niniteButton.Size = New-Object System.Drawing.Size(360, 30)
$niniteButton.Text = "Install Ninite"
$niniteButton.Add_Click({
    $path = Join-Path $desktopPath "ninite.exe"
    if (Download-File $urls.Ninite $path) {
        Run-Installer $path
    }
})
$form.Controls.Add($niniteButton)

# Button to run Win11Debloat in a separate window
$debloatButton = New-Object System.Windows.Forms.Button
$debloatButton.Location = New-Object System.Drawing.Point(10, 180)
$debloatButton.Size = New-Object System.Drawing.Size(360, 30)
$debloatButton.Text = "Run Win11Debloat in Separate Window"
$debloatButton.Add_Click({
    $path = Join-Path $desktopPath "Win11Debloat.ps1"
    if (Download-File $urls.Debloat $path) {
        Run-Installer $path $true
    }
})
$form.Controls.Add($debloatButton)

# Button to restart the system
$restartButton = New-Object System.Windows.Forms.Button
$restartButton.Location = New-Object System.Drawing.Point(10, 220)
$restartButton.Size = New-Object System.Drawing.Size(360, 30)
$restartButton.Text = "Restart System"
$restartButton.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Do you want to restart now?", "Restart Prompt", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status "Restarting system..."
        Restart-Computer -Force
    } else {
        Update-Status "Restart cancelled."
    }
})
$form.Controls.Add($restartButton)

# Save original execution policy and restore on form close
$originalPolicy = Get-ExecutionPolicy -Scope LocalMachine
$form.Add_FormClosing({
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Restoring execution policy" | Out-File -FilePath $logFile -Append
    Set-ExecutionPolicy $originalPolicy -Scope LocalMachine -Force
})

# Show the form
try {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Displaying form" | Out-File -FilePath $logFile -Append
    $form.ShowDialog()
} catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to show form: $_" | Out-File -FilePath $logFile -Append
    [System.Windows.Forms.MessageBox]::Show("Failed to show GUI: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
