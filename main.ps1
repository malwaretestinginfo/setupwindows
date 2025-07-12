# SetupAssistant.ps1

# --- Logging setup ---
$randomId    = Get-Random
$logFileName = "SetupAssistant_{0}.log" -f $randomId
$logFile     = Join-Path $env:TEMP $logFileName
"[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] Starting $PSCommandPath" |
    Out-File -FilePath $logFile -Append

# --- STA & Admin check (relaunch if necessary) ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'

    if (-not ($isAdmin -and $isSTA)) {
        "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] Relaunching under STA + elevated privileges..." |
            Out-File -FilePath $logFile -Append

        $args = @(
            '-STA'
            '-NoProfile'
            '-ExecutionPolicy'; 'Bypass'
            '-File'; "`"$PSCommandPath`""
        )
        Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -ErrorAction Stop
        exit
    }
    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] Running STA + Administrator" |
        Out-File -FilePath $logFile -Append
}
catch {
    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] STA/Admin check failed: $_" |
        Out-File -FilePath $logFile -Append
    exit 1
}

# --- ExecutionPolicy (CurrentUser) ---
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] ExecutionPolicy set to Bypass for CurrentUser" |
        Out-File -FilePath $logFile -Append
} catch {
    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] Failed to set ExecutionPolicy: $_" |
        Out-File -FilePath $logFile -Append
}

# --- Load WinForms ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Build GUI ---
$form = New-Object System.Windows.Forms.Form -Property @{
    Text           = 'Setup Assistant'
    Size           = New-Object System.Drawing.Size(400,200)
    StartPosition  = 'CenterScreen'
    FormBorderStyle= 'FixedSingle'
    MaximizeBox    = $false
}

$statusLabel = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10,20)
    Size     = New-Object System.Drawing.Size(360,20)
    Text     = 'Ready to start installations.'
}
$form.Controls.Add($statusLabel)

$startButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = 'Start Installation'
    Size     = New-Object System.Drawing.Size(360,40)
    Location = New-Object System.Drawing.Point(10,60)
}
$form.Controls.Add($startButton)

# --- Helper functions ---
function Update-Status { param($m) $statusLabel.Text=$m; $statusLabel.Refresh(); "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] $m"| Out-File $logFile -Append }
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
        [System.Windows.Forms.MessageBox]::Show("Download error: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
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
        [System.Windows.Forms.MessageBox]::Show("Run error: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# --- Tasks list ---
$tasks = @(
    @{ Name='Brave';   Url='https://referrals.brave.com/latest/BraveBrowserSetup.exe';    Ext='.exe';   Script=$false },
    @{ Name='Edge';    Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat'; Ext='.bat'; Script=$true  },
    @{ Name='Ninite';  Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe';  Ext='.exe';   Script=$false },
    @{ Name='Debloat'; Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'; Ext='.ps1'; Script=$true  }
)

# --- Single-click handler ---
$startButton.Add_Click({
    # Determine desktop or TEMP
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not (Test-Path $desktop)) { $desktop = $env:TEMP; Update-Status "Using TEMP for downloads." }

    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (-not (Download-File $t.Url $out)) { break }
        Run-Installer $out $t.Script
    }
    Update-Status 'Installation sequence complete.'
})

# --- Restore policy on close ---
$form.Add_FormClosing({
    try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force }
    catch { }
})

# --- Run the GUI ---
Update-Status 'Waiting to start...'
[System.Windows.Forms.Application]::Run($form)
