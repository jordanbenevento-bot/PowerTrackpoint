# This imports .NET libraries built into Windows.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$Global:config = Join-Path $PSScriptRoot "config.ini"
$xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"

if (-not (Test-Path $xamlPath)) {
    [System.Windows.MessageBox]::Show("ERROR: MainWindow.xaml could not be found.", "PowerTrackPoint")
    Exit
}

if (-not (Test-Path $Global:config)) {
    # TODO: Add information from registry to ini file 
    New-item -Path $Global:config -ItemType File -Force
}


function Get-Config {
    [CmdletBinding()]
    param ()


}


$xamlText = Get-Content -Raw -Path $xamlPath

$xamlText = $xamlText -replace '\{TapForce\}', '15'
$xamlText = $xamlText -replace '\{DoubletapSpeed\}', '250'
$xamlText = $xamlText -replace '\{TapSpeed\}', '10'

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xamlText)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$Global:Btnsave = $window.FindName("BtnSave")
$Global:NightMode = $window.findname("ChkNightMode")


function Add-ButtonFunctions {
    [CmdletBinding()]
    param()

    $Global:BtnSave.Add_Click({
        [System.Windows.MessageBox]::Show("Settings Saved!", "PowerTrackPoint")
    })

    $Global:NightMode.Add_Checked({
        [System.Windows.MessageBox]::Show("Checked!", "PowerTrackPoint")
    })
}



# $TapForce  = $window.FindName("TapForce")
# $DoubleTap = $window.FindName("DoubletapSpeed")
# $TapSpeed  = $window.FindName("TapSpeed")
# $NightMode = $window.FindName("ChkNightMode")
# $BtnSave   = $window.FindName("BtnSave")

$window.ShowDialog() | Out-Null
