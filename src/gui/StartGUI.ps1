<#
	The variables $Global:RegValue and $RegPath need to be modifed to retrieve information from the
	registry. You also need to change the default values for the ini file located under the Test-Path
	for the Configuration file.

	Implimentation of the save button to modify the registry needs to be added, as well as the nightmode
	boolean. Applying registry information to the configuration file also needs to be added.

	This is a basic demonstration of the window and some functionality. The registry value types are
	unkown to me, I'm not certain as to how to classify them in this script.
#>

# This imports .NET libraries built into Windows.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase


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


$Global:RegValue = @{
	"TapForce" = 0
	"DoubletapSpeed" = 0
	"TapSpeed" = 0
}


# This function grabs information from the Window's Registry.
# The registry Key, value pairs are stored in $Global:RegValue
function Get-RegistryValues {
	[CmdletBinding()]
	param()

	$RegPath = "HKLM:\System\CurrentControlSet\Control\Class\{4d36e96f-e325-11ce-bfc1-08002be10318}\0000\PointStick"

	if (!(Test-Path $RegPath)) {
		[System.Windows.MessageBox]::Show("ERROR: $($RegPath) could not be found.", "PowerTrackPoint")
    	return
	}

	foreach ($Key in $Global:RegValue.Keys.Clone()) {
        $Value = Get-ItemPropertyValue -Path $RegPath -Name $Key -ErrorAction SilentlyContinue

        if ($null -ne $Value) {
            $Global:RegValue.$Key = $Value
        }
	}
}


Get-RegistryValues

$Global:ConfigFilePath = Join-Path $PSScriptRoot "config.ini"
$XamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"

if (-not (Test-Path $XamlPath)) {
    [System.Windows.MessageBox]::Show("ERROR: MainWindow.xaml could not be found.", "PowerTrackPoint")
    Exit
}

$XamlText = Get-Content -Raw -Path $XamlPath

if (-not (Test-Path $Global:ConfigFilePath)) {
	# TODO: Add nightmode boolean and add to MainWindow.xaml.
    @"
[RegistryConfig]
TapForce=$( $Global:RegValue.TapForce )
DoubletapSpeed=$( $Global:RegValue.DoubletapSpeed )
TapSpeed=$( $Global:RegValue.TapSpeed )
[WindowConfig]
NightMode=0
"@ > $Global:ConfigFilePath
}

foreach ($Key in $Global:RegValue.Keys) {
	$XamlText = $XamlText -replace [Regex]::Escape("{$Key}"), $Global:RegValue.$Key
}

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
