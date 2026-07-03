# This imports .NET libraries built into Windows.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$Global:ConfigFilePath = Join-Path $PSScriptRoot "config.ini"
$XamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"

if (-not (Test-Path $XamlPath)) {
    [System.Windows.MessageBox]::Show("ERROR: MainWindow.xaml could not be found.", "PowerTrackPoint")
    Exit
}

if (-not (Test-Path $Global:config)) {
    # TODO: Add information from registry to ini file 
    # New-item -Path $Global:config -ItemType File -Force
    @"
[RegistryConfig]
Tapforce=0
DoubletapSpeed=0
TapSpeed=0
[WindowConfig]
NightMode=0a
"@ > $Global:ConfigFilePath
}


<#
    This function handles reading .ini Files.

    Credit & Attribution:
    Adapted from an implementation by Alex Marin
    Source: https://www.advancedinstaller.com/read-ini-files-with-powershell.html
#>
function Get-IniContent ($filePath) {
	$ini = @{}
	switch -regex -file $FilePath
	{
    	'^\[(.+)\]' # Section
    	{
        	$section = $matches[1]
        	$ini[$section] = @{}
        	$CommentCount = 0
    	}
    	'^(;.*)$' # Comment
    	{
        	$value = $matches[1]
        	$CommentCount = $CommentCount + 1
        	$name = “Comment” + $CommentCount
        	$ini[$section][$name] = $value
    	}
    	'(.+?)\s*=(.*)' # Key
    	{
        	$name,$value = $matches[1..2]
        	$ini[$section][$name] = $value
    	}
	}
	return $ini
}

$XamlText = Get-Content -Raw -Path $XamlPath

# $XamlText = $XamlText -replace '\{TapForce\}', '15'
# $XamlText = $XamlText -replace '\{DoubletapSpeed\}', '250'
# $XamlText = $XamlText -replace '\{TapSpeed\}', '10'

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$XamlText)
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
