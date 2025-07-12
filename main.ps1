# SetupAssistant.ps1

# Initialize logging
$logFile = Join-Path $env:TEMP "SetupAssistant_{0}.log" -f (Get-Random)
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Starting $PSCommandPath" | Out-File -FilePath $logFile -Append

# Check STA and Admin; if missing either, re-launch under STA + elevated
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'

    if (-not ($isAdmin -and $isSTA)) {
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Re-launching under STA + elevated..." | Out-File -FilePath $logFile -Append

        $args = @(
            '-STA'
            '-NoProfile'
            '-ExecutionPolicy'; 'Bypass'
            '-File'; "`"$PSCommandPath`""
        )
        Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
        exit
    }
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Running STA + Administrator" | Out-File -FilePath $logFile -Append
}
catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] STA/Admin check failed: $_" | Out-File -FilePath $logFile -Append
    Write-Error "Could not elevate or set STA: $_"
    exit 1
}

# Save & set ExecutionPolicy for CurrentUser
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] ExecutionPolicy set to Bypass for CurrentUser" | Out-File -FilePath $logFile -Append
}
catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to set ExecutionPolicy: $_" | Out-File -FilePath $logFile -Append
}

# Load WinForms
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Build Form
$form = New-Object System.Windows.Forms.Form `
    -Property @{
        Text = 'Setup Assistant'
        Size = New-Object System.Drawing.Size(400,300)
        StartPosition = 'CenterScreen'
        FormBorderStyle = 'FixedSingle'
        MaximizeBox = $false
    }

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label `
    -Property @{
        Location = New-Object System.Drawing.Point(10,20)
        Size     = New-Object System.Drawing.Size(360,20)
        Text     = 'Ready to start installations.'
    }
$form.Controls.Add($statusLabel)

function Update-Status {
    param([string]$msg)
    $statusLabel.Text = $msg
    $statusLabel.Refresh()
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $msg" | Out-File -FilePath $logFile -Append
}

function Download-File {
    param($url, $out)
    Update-Status "Downloading $([IO.Path]::GetFileName($out))..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path $out)) { throw 'Download failed, file missing' }
        Update-Status "Downloaded $([IO.Path]::GetFileName($out))."
        return $true
    } catch {
        Update-Status "Download error: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to download: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Run-Installer {
    param($path, [bool]$isScript=$false)
    Update-Status "Running $([IO.Path]::GetFileName($path))..."
    try {
        if ($isScript) {
            Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$path`"" -ErrorAction Stop
        } else {
            Start-Process -FilePath $path -Wait -ErrorAction Stop
        }
        Update-Status "Completed $([IO.Path]::GetFileName($path))."
    } catch {
        Update-Status "Run error: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to run: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Determine desktop fallback
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not (Test-Path $desktop)) { $desktop = $env:TEMP; Update-Status "Desktop missing; using TEMP." }

# Download URLs
$urls = @{
    Brave   = 'https://referrals.brave.com/latest/BraveBrowserSetup.exe'
    Edge    = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat'
    Ninite  = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe'
    Debloat = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'
}

# Helper to add a button
function Add-Button {
    param($text, $y, $action)
    $btn = New-Object System.Windows.Forms.Button `
        -Property @{
            Text     = $text
            Size     = New-Object System.Drawing.Size(360,30)
            Location = New-Object System.Drawing.Point(10,$y)
        }
    $btn.Add_Click($action)
    $form.Controls.Add($btn)
}

# Buttons
Add-Button 'Install Brave Browser' 60 {
    $out = Join-Path $desktop 'BraveBrowserSetup.exe'
    if (Download-File $urls.Brave $out) { Run-Installer $out }
}
Add-Button 'Run Edge Batch' 100 {
    $out = Join-Path $desktop 'Edge.bat'
    if (Download-File $urls.Edge $out) { Run-Installer $out $true }
}
Add-Button 'Install Ninite' 140 {
    $out = Join-Path $desktop 'ninite.exe'
    if (Download-File $urls.Ninite $out) { Run-Installer $out }
}
Add-Button 'Run Win11Debloat' 180 {
    $out = Join-Path $desktop 'Win11Debloat.ps1'
    if (Download-File $urls.Debloat $out) { Run-Installer $out $true }
}
Add-Button 'Restart System' 220 {
    if ([System.Windows.Forms.MessageBox]::Show('Restart now?','Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        ) -eq [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status 'Restarting…'
        Restart-Computer -Force
    } else { Update-Status 'Restart canceled.' }
}

# Restore ExecutionPolicy on exit
$form.Add_FormClosing({
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Restored ExecutionPolicy to $originalPolicy" |
            Out-File -FilePath $logFile -Append
    } catch {
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to restore policy: $_" |
            Out-File -FilePath $logFile -Append
    }
})

# Finally, run the GUI loop
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Launching GUI" | Out-File -FilePath $logFile -Append
[System.Windows.Forms.Application]::Run($form)
