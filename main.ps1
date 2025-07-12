# SetupAssistant.ps1

# --- Hide the console window ---
Add-Type -Name Win32 -Namespace Console -MemberDefinition @"
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@
$hwnd = [Console.Win32]::GetConsoleWindow()
# 0 = SW_HIDE
[Console.Win32]::ShowWindow($hwnd, 0)

# --- Logging setup ---
$randomId    = Get-Random
$logFileName = "SetupAssistant_{0}.log" -f $randomId
$logFile     = Join-Path $env:TEMP $logFileName

function Write-Log {
    param([string]$msg)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] $msg"
    # Append to file
    $line | Out-File -FilePath $logFile -Append
    # Append to GUI log box if initialized
    if ($global:LogBox) {
        $global:LogBox.AppendText($line + [Environment]::NewLine)
        $global:LogBox.ScrollToCaret()
    }
}

Write-Log "Starting $PSCommandPath"

# --- STA & Admin check (relaunch if necessary) ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'

    if (-not ($isAdmin -and $isSTA)) {
        Write-Log "Relaunching under STA + elevated privileges..."
        $args = @(
            '-STA'
            '-WindowStyle'; 'Hidden'
            '-NoProfile'
            '-ExecutionPolicy'; 'Bypass'
            '-File'; "`"$PSCommandPath`""
        )
        Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
        exit
    }
    Write-Log "Running STA + Administrator"
}
catch {
    Write-Log "STA/Admin check failed: $_"
    exit 1
}

# --- ExecutionPolicy (CurrentUser) ---
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    Write-Log "ExecutionPolicy set to Bypass for CurrentUser"
} catch {
    Write-Log "Failed to set ExecutionPolicy: $_"
}

# --- Load WinForms ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Build GUI ---
$form = New-Object System.Windows.Forms.Form -Property @{
    Text           = 'Setup Assistant'
    Size           = New-Object System.Drawing.Size(420,480)
    StartPosition  = 'CenterScreen'
    FormBorderStyle= 'FixedSingle'
    MaximizeBox    = $false
}

# Status label
$statusLabel = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10,10)
    Size     = New-Object System.Drawing.Size(380,20)
    Text     = 'Ready to start installations.'
}
$form.Controls.Add($statusLabel)

# Start button
$startButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = 'Start Installation'
    Size     = New-Object System.Drawing.Size(380,40)
    Location = New-Object System.Drawing.Point(10,40)
}
$form.Controls.Add($startButton)

# Log text box
$logBox = New-Object System.Windows.Forms.TextBox -Property @{
    Multiline   = $true
    ReadOnly    = $true
    ScrollBars  = 'Vertical'
    Location    = New-Object System.Drawing.Point(10, 90)
    Size        = New-Object System.Drawing.Size(380, 340)
    Font        = New-Object System.Drawing.Font('Consolas',10)
}
$form.Controls.Add($logBox)
# Expose globally for Write-Log
$global:LogBox = $logBox

# --- Helper functions ---
function Update-Status {
    param([string]$m)
    $statusLabel.Text = $m
    $statusLabel.Refresh()
    Write-Log $m
}

function Download-File {
    param($url,$out)
    Update-Status "Downloading $([IO.Path]::GetFileName($out))..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path $out)) { throw 'Missing after download' }
        Update-Status "Downloaded $([IO.Path]::GetFileName($out))."
        return $true
    } catch {
        Update-Status "Download failed: $_"
        [System.Windows.Forms.MessageBox]::Show("Download error: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Run-Installer {
    param($path,$isScript)
    Update-Status "Running $([IO.Path]::GetFileName($path))..."
    try {
        if ($isScript) {
            Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$path`"" -ErrorAction Stop
        } else {
            Start-Process $path -Wait -ErrorAction Stop
        }
        Update-Status "Completed $([IO.Path]::GetFileName($path))."
    } catch {
        Update-Status "Run failed: $_"
        [System.Windows.Forms.MessageBox]::Show("Run error: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        throw
    }
}

# --- Tasks list ---
$tasks = @(
    @{ Name='Brave';   Url='https://referrals.brave.com/latest/BraveBrowserSetup.exe';    Ext='.exe';   Script=$false },
    @{ Name='Edge';    Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat'; Ext='.bat'; Script=$true  },
    @{ Name='Ninite';  Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe';  Ext='.exe';   Script=$false },
    @{ Name='Debloat'; Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'; Ext='.ps1'; Script=$true  }
)

# --- Button click action ---
$startButton.Add_Click({
    # Determine download folder
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not (Test-Path $desktop)) {
        $desktop = $env:TEMP
        Update-Status "Desktop missing; using TEMP."
    }

    # Installieren
    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (-not (Download-File $t.Url $out)) { break }
        Run-Installer $out $t.Script
    }

    Update-Status 'Installation sequence complete.'

    # --- Cleanup: entferne alle heruntergeladenen Dateien außer dem PS1-Skript ---
    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (Test-Path $out) {
            try {
                Remove-Item -Path $out -Force -ErrorAction Stop
                Write-Log "Removed file: $out"
            }
            catch {
                Write-Log "Failed to remove $out: $_"
            }
        }
    }
    Update-Status 'Cleanup complete: Installation artifacts removed.'
})

# --- Restore execution policy on close ---
$form.Add_FormClosing({
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
        Write-Log "Restored ExecutionPolicy to $originalPolicy"
    } catch {
        Write-Log "Failed to restore policy: $_"
    }
})

# --- Launch GUI ---
Update-Status 'Waiting to start...'
[System.Windows.Forms.Application]::Run($form)
