# SetupInstaller.ps1

# Global error handling
$ErrorActionPreference = 'Stop'
try {
    # Logging setup
    $randomId = Get-Random
    $logFile = Join-Path $env:TEMP ("SetupInstaller_$randomId.log")
    function Write-Log {
        param([string]$message)
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $line = "[$timestamp] $message"
        $line | Out-File -FilePath $logFile -Append
        if ($global:LogBox) {
            $global:LogBox.AppendText("$line`r`n")
            $global:LogBox.SelectionStart = $global:LogBox.Text.Length
            $global:LogBox.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    Write-Log "Script started"

    # Check admin rights and STA mode
    Write-Log "Checking admin rights and STA mode"
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'
    if (-not $isAdmin) {
        throw "This script must be run as an Administrator."
    }
    if (-not $isSTA) {
        throw "This script must be run in STA mode. Use 'powershell -STA'."
    }
    Write-Log "Admin and STA mode verified"

    # Set ExecutionPolicy
    Write-Log "Setting ExecutionPolicy to Bypass"
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force

    # Load assemblies
    Write-Log "Loading assemblies"
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Create GUI
    Write-Log "Creating GUI"
    $SetupInstaller                  = New-Object system.Windows.Forms.Form
    $SetupInstaller.ClientSize       = New-Object System.Drawing.Point(407,390)
    $SetupInstaller.text             = "Setup Installer"
    $SetupInstaller.TopMost          = $false
    $SetupInstaller.BackColor        = [System.Drawing.ColorTranslator]::FromHtml("#4a4a4a")

    $Button1                         = New-Object system.Windows.Forms.Button
    $Button1.text                    = "Start Installation"
    $Button1.width                   = 228
    $Button1.height                  = 69
    $Button1.location                = New-Object System.Drawing.Point(90,62)
    $Button1.Font                    = New-Object System.Drawing.Font('Comic Sans MS',20)

    $TextBox1                        = New-Object system.Windows.Forms.TextBox
    $TextBox1.multiline              = $true
    $TextBox1.width                  = 229
    $TextBox1.height                 = 100
    $TextBox1.location               = New-Object System.Drawing.Point(91,205)
    $TextBox1.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
    $TextBox1.ReadOnly               = $true
    $TextBox1.ScrollBars             = [System.Windows.Forms.ScrollBars]::Vertical
    $global:LogBox                   = $TextBox1

    $ProgressBar1                    = New-Object system.Windows.Forms.ProgressBar
    $ProgressBar1.width              = 244
    $ProgressBar1.height             = 25
    $ProgressBar1.location           = New-Object System.Drawing.Point(83,320)
    $ProgressBar1.Minimum            = 0
    $ProgressBar1.Maximum            = 100
    $ProgressBar1.Value              = 0

    $SetupInstaller.controls.AddRange(@($Button1,$TextBox1,$ProgressBar1))
    Write-Log "GUI created successfully"

    # Helper functions
    function Download-File {
        param($url, $output)
        Write-Log "Downloading $([System.IO.Path]::GetFileName($output))"
        try {
            Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
            Write-Log "Downloaded $([System.IO.Path]::GetFileName($output))"
            return $true
        } catch {
            Write-Log "Download failed: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Download error: $($_.Exception.Message)", "Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return $false
        }
    }

    function Run-Installer {
        param($path, $isScript)
        Write-Log "Running $([System.IO.Path]::GetFileName($path))"
        try {
            if ($isScript) {
                Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$path`"" -Wait
            } else {
                Start-Process $path -Wait
            }
            Write-Log "Completed $([System.IO.Path]::GetFileName($path))"
        } catch {
            Write-Log "Run failed: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Run error: $($_.Exception.Message)", "Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
            throw
        }
    }

    # Installation tasks
    $tasks = @(
        @{ Name = 'Brave';   Url = 'https://referrals.brave.com/latest/BraveBrowserSetup.exe'; Ext = '.exe'; Script = $false },
        @{ Name = 'Edge';    Url = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/Edge.bat'; Ext = '.bat'; Script = $false },
        @{ Name = 'Ninite';  Url = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/main/ninite.exe'; Ext = '.exe'; Script = $false },
        @{ Name = 'Debloat'; Url = 'https://raw.githubusercontent.com/malwaretestinginfo/setupwindows/refs/heads/main/Win11Debloat.ps1'; Ext = '.ps1'; Script = $true }
    )

    # Button click event
    $Button1.Add_Click({
        try {
            $Button1.Enabled = $false
            $ProgressBar1.Value = 0
            $TextBox1.Text = ""
            $downloadPath = Join-Path $env:TEMP "SetupInstaller_Downloads"
            if (-not (Test-Path $downloadPath)) { New-Item -ItemType Directory -Path $downloadPath | Out-Null }
            Write-Log "Starting installation process"

            $totalSteps = $tasks.Count * 2  # Download + install for each task
            $stepIncrement = 100 / $totalSteps
            $currentProgress = 0

            foreach ($task in $tasks) {
                $filePath = Join-Path $downloadPath ($task.Name + $task.Ext)
                if (Download-File $task.Url $filePath) {
                    $currentProgress += $stepIncrement
                    $ProgressBar1.Value = [Math]::Min([Math]::Round($currentProgress), 100)
                    Run-Installer $filePath $task.Script
                    $currentProgress += $stepIncrement
                    $ProgressBar1.Value = [Math]::Min([Math]::Round($currentProgress), 100)
                } else {
                    break
                }
            }

            Write-Log "Installation sequence complete"
            try {
                Remove-Item -Path $downloadPath -Recurse -Force
                Write-Log "Cleaned up downloaded files"
            } catch {
                Write-Log "Cleanup failed: $($_.Exception.Message)"
            }
        } catch {
            Write-Log "Installation error: $($_.Exception.Message)"
        } finally {
            $Button1.Enabled = $true
            $ProgressBar1.Value = 100
        }
    })

    # Restore ExecutionPolicy on form close
    $SetupInstaller.Add_FormClosing({
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
            Write-Log "Restored ExecutionPolicy to $originalPolicy"
        } catch {
            Write-Log "Failed to restore ExecutionPolicy: $($_.Exception.Message)"
        }
    })

    # Show the form
    Write-Log "Starting GUI"
    [void]$SetupInstaller.ShowDialog()
} catch {
    $errorMsg = $_.Exception.Message
    Write-Log "Fatal error: $errorMsg"
    [System.Windows.Forms.MessageBox]::Show("An error occurred: $errorMsg", "Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}
