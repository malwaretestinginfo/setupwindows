# SetupAssistant.ps1

# --- Logging setup ---
$randomId    = Get-Random
$logFileName = "SetupAssistant_{0}.log" -f $randomId
$logFile     = Join-Path $env:TEMP $logFileName
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Starting $PSCommandPath" |
    Out-File -FilePath $logFile -Append

# --- STA & Admin check (relaunch if necessary) ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA   = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'

    if (-not ($isAdmin -and $isSTA)) {
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Relaunching under STA + elevated privileges..." |
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

    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Running STA + Administrator" |
        Out-File -FilePath $logFile -Append
}
catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] STA/Admin check failed: $_" |
        Out-File -FilePath $logFile -Append
    Write-Error "Could not elevate or set STA: $_"
    exit 1
}

# --- ExecutionPolicy (CurrentUser) ---
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] ExecutionPolicy set to Bypass for CurrentUser" |
        Out-File -FilePath $logFile -Append
}
catch {
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to set ExecutionPolicy: $_" |
        Out-File -FilePath $logFile -Append
}

# --- Load WinForms ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Build the form & status label ---
$form = New-Object System.Windows.Forms.Form -Property @{
    Text           = 'Setup Assistant'
    Size           = New-Object System.Drawing.Size(400,340)
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

# --- Helper functions ---
function Update-Status {
    param([string]$msg)
    $statusLabel.Text = $msg
    $statusLabel.Refresh()
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $msg" |
        Out-File -FilePath $logFile -Append
}

function Download-File {
    param($url, $outPath)
    Update-Status "Downloading $([IO.Path]::GetFileName($outPath))..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path $outPath)) { throw 'File missing after download' }
        Update-Status "Downloaded $([IO.Path]::GetFileName($outPath))."
        return $true
    } catch {
        Update-Status "Download failed: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to download: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Run-Installer {
    param($filePath, [bool]$isScript=$false)
    Update-Status "Running $([IO.Path]::GetFileName($filePath))..."
    try {
        if ($isScript) {
            Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$filePath`"" -ErrorAction Stop
        } else {
            Start-Process -FilePath $filePath -Wait -ErrorAction Stop
        }
        Update-Status "Completed $([IO.Path]::GetFileName($filePath))."
    } catch {
        Update-Status "Run failed: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to run: $_",'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# --- Determine Desktop path (fallback to TEMP) ---
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not (Test-Path $desktop)) {
    $desktop = $env:TEMP
    Update-Status "Desktop not found; using TEMP."
}

# --- Download URLs & file extensions ---
$tasks = @(
    @{ Name='Brave';   Url='https://referrals.brave.com/latest/BraveBrowserSetup.exe';    Ext='.exe';   IsScript=$false },
    @{ Name='Edge';    Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat'; Ext='.bat'; IsScript=$true  },
    @{ Name='Ninite';  Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe';  Ext='.exe';   IsScript=$false },
    @{ Name='Debloat'; Url='https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'; Ext='.ps1'; IsScript=$true  }
)

# --- Button factory ---
function Add-Button {
    param($text, $yPos, $scriptBlock)
    $btn = New-Object System.Windows.Forms.Button -Property @{
        Text     = $text
        Size     = New-Object System.Drawing.Size(360,30)
        Location = New-Object System.Drawing.Point(10,$yPos)
    }
    $btn.Add_Click($scriptBlock)
    $form.Controls.Add($btn)
}

# --- Individual buttons (optional) ---
Add-Button 'Install Brave Browser'      60 {
    $t = $tasks | Where Name -eq 'Brave'
    $out = Join-Path $desktop ($t.Name + $t.Ext)
    if (Download-File $t.Url $out) { Run-Installer $out $t.IsScript }
}

Add-Button 'Run Edge Batch'             100 {
    $t = $tasks | Where Name -eq 'Edge'
    $out = Join-Path $desktop ($t.Name + $t.Ext)
    if (Download-File $t.Url $out) { Run-Installer $out $t.IsScript }
}

Add-Button 'Install Ninite'             140 {
    $t = $tasks | Where Name -eq 'Ninite'
    $out = Join-Path $desktop ($t.Name + $t.Ext)
    if (Download-File $t.Url $out) { Run-Installer $out $t.IsScript }
}

Add-Button 'Run Win11Debloat'           180 {
    $t = $tasks | Where Name -eq 'Debloat'
    $out = Join-Path $desktop ($t.Name + $t.Ext)
    if (Download-File $t.Url $out) { Run-Installer $out $t.IsScript }
}

# --- NEW: Start Installation button ---
Add-Button 'Start Installation (All)'   220 {
    foreach ($t in $tasks) {
        $out = Join-Path $desktop ($t.Name + $t.Ext)
        if (-not (Download-File $t.Url $out)) { break }
        Run-Installer $out $t.IsScript
    }
    Update-Status 'All tasks completed (or halted on error).'
}

# --- Restart System button ---
Add-Button 'Restart System'             260 {
    if ([System.Windows.Forms.MessageBox]::Show('Restart now?','Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        ) -eq [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status 'Restarting…'
        Restart-Computer -Force
    } else {
        Update-Status 'Restart canceled.'
    }
}

# --- Restore ExecutionPolicy on exit ---
$form.Add_FormClosing({
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Forces
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Restored ExecutionPolicy to $originalPolicy" |
            Out-File -FilePath $logFile -Append
    } catch {
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Failed to restore policy: $_" |
            Out-File -FilePath $logFile -Append
    }
})

# --- Launch the GUI ---
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Launching GUI" |
    Out-File -FilePath $logFile -Append
[System.Windows.Forms.Application]::Run($form)
