# -AllowClickUAC: saca el prompt de UAC del Secure Desktop (PromptOnSecureDesktop=0)
# para que el TrackPoint pueda clickearlo. BAJA la seguridad de UAC (queda expuesto a
# inyeccion de input). Opt-in: por defecto NO se toca el Secure Desktop.
param([switch]$AllowClickUAC)

$ErrorActionPreference = "Stop"

# 1. Admin privilege check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Error "Este script debe ejecutarse como Administrador. Por favor abre PowerShell como Administrador e inténtalo de nuevo."
    exit 1
}

Write-Output "=== PowerTrackpoint Installer (Alpha) ==="

# 1.5 Detener cualquier helper previo y su tarea (libera el exe para reinstalar)
Unregister-ScheduledTask -TaskName "PowerTrackpoint Helper" -Confirm:$false -ErrorAction SilentlyContinue
Get-Process tphandler_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

# 2. Locate Windows SDK tools (makeappx / signtool)
$sdkPath = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse -ErrorAction SilentlyContinue | 
           Where-Object { $_.DirectoryName -like "*x64*" } | 
           Select-Object -First 1

if (!$sdkPath) {
    Write-Output "Windows SDK no detectado. Intentando instalarlo automáticamente mediante winget..."
    winget install Microsoft.WindowsSDK.10.0.18362 --silent --accept-package-agreements --accept-source-agreements
    
    # Retry locating tools
    $sdkPath = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse -ErrorAction SilentlyContinue | 
               Where-Object { $_.DirectoryName -like "*x64*" } | 
               Select-Object -First 1
               
    if (!$sdkPath) {
        Write-Error "No se pudo instalar o localizar Windows SDK. Instala 'Windows Software Development Kit' manualmente."
        exit 1
    }
}

$binDir = $sdkPath.DirectoryName
$makeappx = Join-Path $binDir "makeappx.exe"
$signtool = Join-Path $binDir "signtool.exe"
Write-Output "Herramientas SDK encontradas en: $binDir"

# 3. Locate the original TrackPoint Quick Menu package
Write-Output "Buscando el paquete original de TrackPoint Quick Menu..."
$origPackage = Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers | Select-Object -First 1
if (!$origPackage) {
    Write-Error "El paquete original 'TrackPoint Quick Menu' no está instalado en el sistema. Instálalo primero desde la Microsoft Store."
    exit 1
}
$origPath = $origPackage.InstallLocation
Write-Output "Paquete original encontrado en: $origPath"

# 4. Define paths and cleanup
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectDir = Split-Path -Parent $scriptDir
$stagingDir = "C:\PowerTrackpointStaging"
$destHelperDir = "C:\Program Files\PowerTrackpoint"
$pfxPath = Join-Path $destHelperDir "cert.pfx"
$cerPath = Join-Path $destHelperDir "cert.cer"
$msixPath = Join-Path $destHelperDir "PowerTrackpoint.msix"

if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
if (Test-Path $destHelperDir) {
    Remove-Item -Recurse -Force $destHelperDir
}
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $destHelperDir | Out-Null

# 5. Clone original app contents to staging (No copyright issues: we build locally)
Write-Output "Clonando recursos originales localmente..."
Copy-Item -Path "$origPath\*" -Destination $stagingDir -Recurse -Force

# Overwrite launcher with our client
Write-Output "Inyectando cliente PowerTrackpoint..."
$clientExePath = Join-Path $projectDir "bin\TrackPointQuickMenu.exe"
if (!(Test-Path $clientExePath)) {
    $clientExePath = Join-Path $scriptDir "TrackPointQuickMenu.exe" # Fallback if run from release folder
}
Copy-Item -Path $clientExePath -Destination (Join-Path $stagingDir "TrackPointQuickMenu\TrackPointQuickMenu.exe") -Force

# Remove the original signature file (will be re-signed) and any stale backup
Remove-Item -Path (Join-Path $stagingDir "AppxSignature.p7x") -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $stagingDir "TrackPointQuickMenu\TrackPointQuickMenu.exe.bak") -ErrorAction SilentlyContinue

# 6. Generate Certificate
Write-Output "Generando certificado auto-firmado..."
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=20E7E2C9-A2A9-4A02-BB29-6FCFB9E042BB" -KeyUsage DigitalSignature -FriendlyName "PowerTrackpoint Cert" -CertStoreLocation "Cert:\CurrentUser\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
$pwd = ConvertTo-SecureString "123456" -AsPlainText -Force
$null = Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd
$null = Export-Certificate -Cert $cert -FilePath $cerPath

# 7. Trust Certificate
Write-Output "Instalando certificado en los almacenes locales de confianza..."
$null = Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\Root"
$null = Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"

# 7.5 Firmar el cliente con Authenticode ANTES de empaquetar.
# uiAccess valida la firma del propio PE (no solo la del paquete MSIX), asi que el
# exe embebido debe estar Authenticode-firmado por el cert de confianza. Sin esto,
# Windows ignora uiAccess=true y el click sigue bloqueado por UIPI.
Write-Output "Firmando el cliente (Authenticode, requisito de uiAccess)..."
$clientInStaging = Join-Path $stagingDir "TrackPointQuickMenu\TrackPointQuickMenu.exe"
& $signtool sign /fd SHA256 /f $pfxPath /p 123456 $clientInStaging | Out-Null

# 8. Pack and Sign MSIX
Write-Output "Empaquetando nuevo MSIX..."
& $makeappx pack /d $stagingDir /p $msixPath /o | Out-Null

Write-Output "Firmando MSIX..."
& $signtool sign /fd SHA256 /a /f $pfxPath /p 123456 $msixPath | Out-Null

# 9. Clean up original package and provision/install the new one
Write-Output "Removiendo registros de la versión previa..."
Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "E0469640.TrackPointQuickMenu" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

Write-Output "Aprovisionando paquete a nivel de máquina..."
$null = Add-AppxProvisionedPackage -Online -PackagePath $msixPath -SkipLicense

# Note: The user can register it themselves later if they run via interactive terminal
Write-Output "Registrando paquete para el usuario actual..."
$null = Add-AppxPackage -Path $msixPath -ErrorAction SilentlyContinue

# 9.5 Instalar el helper uiAccess (hace el SendInput saltando UIPI sobre ventanas de admin).
# Va suelto en Program Files (secure location), firmado Authenticode, y lo lanza una
# Scheduled Task al logon. Lanzado asi (no por activacion MSIX), Windows si honra uiAccess.
Write-Output "Instalando helper uiAccess..."
$helperSrc = Join-Path $projectDir "bin\tphandler_helper.exe"
if (!(Test-Path $helperSrc)) { $helperSrc = Join-Path $scriptDir "tphandler_helper.exe" } # fallback release
$helperDst = Join-Path $destHelperDir "tphandler_helper.exe"
Copy-Item -Path $helperSrc -Destination $helperDst -Force

Write-Output "Firmando helper (Authenticode, requisito de uiAccess)..."
& $signtool sign /fd SHA256 /f $pfxPath /p 123456 $helperDst | Out-Null

Write-Output "Registrando tarea de inicio del helper (al logon, sin elevacion)..."
$taskName = "PowerTrackpoint Helper"
# Un exe uiAccess NO se puede lanzar por CreateProcess directo: Task Scheduler
# devuelve ERROR_ELEVATION_REQUIRED (0x800702E4). Hay que pasar por ShellExecute
# (Start-Process -> AppInfo), que otorga el token UIAccess a apps firmadas en
# secure location sin prompt UAC. Por eso la accion lanza powershell -> Start-Process.
$launchArg = "-NoProfile -WindowStyle Hidden -Command Start-Process -FilePath '$helperDst'"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $launchArg
$trigger = New-ScheduledTaskTrigger -AtLogOn
# uiAccess exige integrity level medium -> RunLevel Limited (NUNCA Highest).
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
$null = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

Write-Output "Iniciando helper..."
Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

# 9.7 (opt-in) Sacar el prompt de UAC del Secure Desktop para poder clickearlo.
# El prompt UAC corre en el Secure Desktop, inalcanzable por SendInput (ni con uiAccess).
# Esto lo mueve al escritorio normal a costa de seguridad. Solo con -AllowClickUAC.
if ($AllowClickUAC) {
    Write-Output "ADVERTENCIA: deshabilitando Secure Desktop de UAC (PromptOnSecureDesktop=0) — baja la seguridad de UAC."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name PromptOnSecureDesktop -Value 0
}

# 10. Cleanup Staging
Remove-Item -Recurse -Force $stagingDir

Write-Output "=== INSTALACION COMPLETADA CON EXITO ==="
Write-Output "PowerTrackpoint está listo (cliente + helper uiAccess). Haz doble tap en tu TrackPoint para probarlo."
