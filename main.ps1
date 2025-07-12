# SetupAssistant.ps1

# --- Globale Fehlerbehandlung ---
$ErrorActionPreference = 'Stop'
trap {
    $msg = $_.Exception.Message
    Write-Log "UNHANDLED ERROR: $msg"
    [System.Windows.Forms.MessageBox]::Show("FATAL ERROR:`n$msg","Fehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error)
    break
}

# --- Logging setup ---
$randomId    = Get-Random
$logFile     = Join-Path $env:TEMP ("SetupAssistant_{0}.log" -f $randomId)
function Write-Log {
    param([string]$m)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] $m"
    $line | Out-File -FilePath $logFile -Append
    if ($global:LogBox) {
        $global:LogBox.AppendText($line + [Environment]::NewLine)
        $global:LogBox.ScrollToCaret()
    }
}

# --- Skript-Pfad ermitteln ---
$scriptPath = $MyInvocation.MyCommand.Path
Write-Log "Starting $scriptPath"

# --- STA/Admin Relaunch (falls nötig) ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'
    if (-not ($isAdmin -and $isSTA)) {
        Write-Log "Relaunching elevated..."
        $args = '-STA','-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',"`"$scriptPath`""
        Start-Process powershell.exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
        exit
    }
    Write-Log "Running elevated +和

# --- ExecutionPolicy sichern & Bypass setzen ---
$originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force

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
    Location    = New-Object System.Drawing.Point(10,90)
    Size        = New-Object System.Drawing.Size(380,340)
    Font        = New-Object System.Drawing.Font('Consolas',10)
}
$form.Controls.Add($logBox)
$global:LogBox = $logBox

# --- Helper-Funktionen ---
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
        Update-Status "Downloaded $([IO.Path]::GetFileName($out))"
        return $true
    } catch {
        $msg = $_.Exception.Message
        Update-Status "Download failed: $msg"
        [System.Windows.Forms.MessageBox]::Show("Download error:`n$msg","Error",
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
            Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', "`"$path`"" -Wait -ErrorAction Stop
        } else {
            Start-Process $path -Wait -ErrorAction Stop
        }
        Update-Status "Completed $([IO.Path]::GetFileName($path))"
    } catch {
        $msg = $_.Exception.Message
        Update-Status "Run failed: $msg"
        [System.Windows.Forms.MessageBox]::Show("Run error:`n$msg","Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        throw
    }
}

# --- Aufgabenliste mit korrigierter Edge-Konfiguration ---
$tasks = @(
    @{ Name='Brave';   Url='https://referrals.brave.com/latest/BraveBrowserSetup.exe';                                            Ext='.exe';  Script=$false },
    @{ Name='Edge';    Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat';                     Ext='.bat';  Script=$false },
    @{ Name='Ninite';  Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe';                    Ext='.exe';  Script=$false },
    @{ Name='Debloat'; Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1';   Ext='.ps1';  Script=$true  }
)

# --- Klick-Event für Start-Button ---
$startButton.Add_Click({
    # Zielordner (Desktop oder TEMP)
    $folder = [Environment]::GetFolderPath('Desktop')
    if (-not (Test-Path $folder)) {
        $folder = $env:TEMP
        Update-Status "Desktop nicht gefunden; verwende TEMP."
    }

    # Download & Installation
    foreach ($t in $tasks) {
        $out = Join-Path $folder ($t.Name + $t.Ext)
        if (-not (Download-File $t.Url $out)) { break }
        Run-Installer $out $t.Script
    }

    Update-Status 'Installation sequence complete.'

    # Cleanup: entferne alle heruntergeladenen Dateien außer dem PS1-Skript
    foreach ($t in $tasks) {
        $out = Join-Path $folder ($t.Name + $t.Ext)
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
    Update-Status 'Cleanup complete: Installation artifacts removed.'
})

# --- ExecutionPolicy beim Schließen zurücksetzen ---
$form.Add_FormClosing({
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
    Write-Log "Restored ExecutionPolicy to $originalPolicy"
})

# --- GUI starten ---
Update-Status 'Waiting to start...'
[System.Windows.Forms.Application]::Run($form)
