# Check if running as administrator, if not, relaunch with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Load necessary assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Setup Assistant"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"

# Create a status label to show progress or errors
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 20)
$statusLabel.Size = New-Object System.Drawing.Size(360, 20)
$statusLabel.Text = "Ready to start installations."
$form.Controls.Add($statusLabel)

# Define the desktop path for file downloads
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Define URLs for the files to be downloaded
$urls = @{
    Brave = "https://referrals.brave.com/latest/BraveBrowserSetup.exe"
    Edge = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat"
    Ninite = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe"
    Debloat = "https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1"
}

# Function to download a file from a URL to the specified output path
function Download-File {
    param($url, $outputPath)
    try {
        $statusLabel.Text = "Downloading $(Split-Path $outputPath -Leaf)..."
        Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
        $statusLabel.Text = "Downloaded $(Split-Path $outputPath -Leaf)."
        return $true
    } catch {
        $statusLabel.Text = "Failed to download: $_"
        return $false
    }
}

# Function to run an installer or script
function Run-Installer {
    param($filePath)
    try {
        $statusLabel.Text = "Running $(Split-Path $filePath -Leaf)..."
        $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
        if ($extension -eq ".ps1") {
            # Run PowerShell scripts in a separate window without waiting
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$filePath`""
        } else {
            # Run other files (e.g., .exe, .bat) and wait for completion
            Start-Process -FilePath $filePath -Wait
        }
        $statusLabel.Text = "Completed $(Split-Path $filePath -Leaf)."
    } catch {
        $statusLabel.Text = "Failed to run: $_"
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
        Run-Installer $path
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
        Run-Installer $path
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
        Restart-Computer -Force
    }
})
$form.Controls.Add($restartButton)

# Show the form
$form.ShowDialog()
