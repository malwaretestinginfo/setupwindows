# SetupAssistant.ps1

# --- Globale Fehlerbehandlung ---
$ErrorActionPreference = 'Stop'
trap {
    $errMsg = $_.Exception.Message
    Write-Log "UNHANDLED ERROR: $errMsg"
    [System.Windows.Forms.MessageBox]::Show("FATAL ERROR:`n$errMsg","Fehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error)
    break
}

# --- Logging setup ---
$randomId    = Get-Random
$logFileName = "SetupAssistant_{0}.log" -f $randomId
$logFile     = Join-Path $env:TEMP $logFileName

function Write-Log {
    param([string]$msg)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] $msg"
    $line | Out-File -FilePath $logFile -Append
    if ($global:LogBox) {
        $global:LogBox.AppendText($line + [Environment]::NewLine)
        $global:LogBox.ScrollToCaret()
    }
}

# --- Skript-Pfad ermitteln ---
$scriptPath = $MyInvocation.MyCommand.Path
Write-Log "Starting $scriptPath"

# --- STA & Admin check (Relaunch falls nötig) ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'

    if (-not ($isAdmin -and $isSTA)) {
        Write-Log "Relaunching under STA + elevated privileges..."
        $args = @(
            '-STA'
            '-NoProfile'
            '-ExecutionPolicy'; 'Bypass'
            '-NoExit'                   # Konsole offen lassen, damit Fehler sichtbar bleiben
            '-File'; "`"$scriptPath`""
        )
        Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
        exit
    }
    Write-Log "Running STA + Administrator"
}
catch {
    $msg = $_.Exception.Message
    Write-Log "STA/Admin check failed: $msg"
    throw
}

# --- ExecutionPolicy sichern & Bypass setzen ---
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    Write-Log "ExecutionPolicy set to Bypass for CurrentUser"
} catch {
    $msg = $_.Exception.Message
    Write-Log "Failed to set ExecutionPolicy: $msg"
}

# --- WinForms laden & Styles aktivieren ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- GUI erstellen ---
$form = New-Object System.Windows.Forms.Form -Property @{
    Text            = 'Setup Assistant'
    Size            = New-Object System.Drawing.Size(420,480)
    StartPosition   = 'CenterScreen'
    FormBorderStyle = 'FixedSingle'
    MaximizeBox     = $false
}

$statusLabel = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10,10)
    Size     = New-Object System.Drawing.Size(380,20)
    Text     = 'Waiting to start...'
}
$form.Controls.Add($statusLabel)

$startButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = 'Start Installation'
    Size     = New-Object System.Drawing.Size(380,40)
    Location = New-Object System.Drawing.Point(10,40)
}
$form.Controls.Add($startButton)

$logBox = New-Object System.Windows.Forms.TextBox -Property @{
    Multiline   = $true
    ReadOnly    = $true
    ScrollBars  = 'Vertical'
    Location    = New-Object System.Drawing.Point(10, 90)
    Size        = New-Object System.Drawing.Size(380, 340)
    Font        = New-Object System.Drawing.Font('Consolas',10)
}
$form.Controls.Add($logBox)
$global:LogBox = $logBox

# --- Helfer-Funktionen ---
function Update-Status {
    param([string]$m)
    $statusLabel.Text = $m
    $statusLabel.Refresh()
    Write-Log $m
}

function Download-File {
    param($url, $out)
    Update-Status "Downloading $([IO.Path]::GetFileName($out))..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path $out)) { throw 'File missing after download' }
        Update-Status "Downloaded $([IO.Path]::GetFileName($out))."
        return $true
    } catch {
        $msg = $_.Exception.Message
        Update-Status "Download failed: $msg"
        [System.Windows.Forms.MessageBox]::Show("Download error:`n$msg",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Run-Installer {
    param($path, $isScript)
    Update-Status "Running $([IO.Path]::GetFileName($path))..."
    try {
        if ($isScript) {
            Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', "`"$path`"" -ErrorAction Stop
        } else {
            Start-Process $path -Wait -ErrorAction Stop
        }
        Update-Status "Completed $([IO.Path]::GetFileName($path))."
    } catch {
        $msg = $_.Exception.Message
        Update-Status "Run failed: $msg"
        [System.Windows.Forms.MessageBox]::Show("Run error:`n$msg",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        throw
    }
}

# --- Liste der Installationsaufgaben ---
$tasks = @(
    @{ Name='Brave';   Url='https://referrals.brave.com/latest/BraveBrowserSetup.exe';                         Ext='.exe';  Script=$false },
    @{ Name='Edge';    Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat';   Ext='.bat';  Script=$true  },
    @{ Name='Ninite';  Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe'; Ext='.exe';  Script=$false },
    @{ Name='Debloat'; Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'; Ext='.ps1'; Script=$true  }
)

# --- Klick-Event für Start-Button ---
$startButton.Add_Click({
    # Zielordner (Desktop oder TEMP)
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not (Test-Path $desktop)) {
        $desktop = $env:TEMP
        Update-Status "Desktop nicht gefunden; verwende TEMP."
    }

    # Download & Installation
    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (-not (Download-File $t.Url $out)) { break }
        Run-Installer $out $t.Script
    }

    Update-Status 'Installation abgeschlossen.'

    # --- Aufräumen: entferne nur die heruntergeladenen Dateien ---
    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (Test-Path $out) {
            try {
                Remove-Item -Path $out -Force -ErrorAction Stop
                Write-Log "Removed file: $out"
            } catch {
                $msg = $_.Exception.Message
                Write-Log "Failed to remove $out: $msg"
            }
        }
    }
    Update-Status 'Cleanup abgeschlossen: Installationsdateien entfernt.'
})

# --- ExecutionPolicy beim Schließen wiederherstellen ---
$form.Add_FormClosing({
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
        Write-Log "Restored ExecutionPolicy to $originalPolicy"
    } catch {
        $msg = $_.Exception.Message
        Write-Log "Failed to restore policy: $msg"
    }
})

# --- GUI starten ---
Update-Status 'Waiting to start...'
[System.Windows.Forms.Application]::Run($form)
