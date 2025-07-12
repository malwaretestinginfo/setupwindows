# SetupAssistant.ps1
# ------------------
# Minimal WinForms test under STA
# Launch via: powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\SetupAssistant.ps1

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Enable visual styles
[System.Windows.Forms.Application]::EnableVisualStyles()

# Create a simple form
$form = New-Object System.Windows.Forms.Form `
    -Property @{
        Text           = 'Setup Assistant'
        Width          = 400
        Height         = 200
        StartPosition  = 'CenterScreen'
        FormBorderStyle= 'FixedSingle'
        MaximizeBox    = $false
    }

# Add a label
$label = New-Object System.Windows.Forms.Label `
    -Property @{
        AutoSize = $true
        Location = New-Object System.Drawing.Point(20,40)
        Text     = 'If you see this window, STA is working!'
    }
$form.Controls.Add($label)

# Run the message loop
[System.Windows.Forms.Application]::Run($form)
