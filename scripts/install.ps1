param([switch]$AllowClickUAC)

$ErrorActionPreference = "Stop"

# PowerTrackpoint installer - click INSTANTANEO + sobre ventanas de Administrador.
#
# Arquitectura (por que es instantaneo y funciona sobre admin):
#   1. Mock MSIX: clona el Quick Menu de Lenovo y le QUITA la extension de
#      protocolo del manifest. El paquete sigue instalado y firmado, asi
#      shtctky.exe lo valida y sigue disparando el doble-tap, pero Windows ya NO
#      intercepta lenovo-trackpointmenu:// como app UWP (la activacion UWP metia
#      ~100ms de arranque - ese era el lag).
#   2. Protocol handler Win32: el protocolo queda mapeado en el registro a un exe
#      Win32 suelto en Program Files -> Windows lo lanza al instante (sin UWP).
#   3. Helper elevado: corre como Administrador (Scheduled Task RunLevel Highest),
#      duerme esperando un Named Event y al despertar hace SendInput con
#      privilegios -> salta UIPI y clickea sobre cualquier ventana de admin.
#
# Flujo: doble-tap -> shtctky dispara el protocolo -> el registro lanza el cliente
# Win32 (instantaneo) -> el cliente senaliza el event -> el helper admin despierta
# y hace el click. (El prompt de UAC sigue en el Secure Desktop: inalcanzable por
# diseno, y eso es lo deseable.)
#
# -AllowClickUAC (opt-in): saca el prompt de UAC del Secure Desktop. BAJA la
# seguridad de UAC. Por defecto NO se toca.

# 1. Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Error "Este script debe ejecutarse como Administrador. Abre PowerShell como Administrador y reintenta."
    exit 1
}

Write-Output "=== PowerTrackpoint Installer (Alpha) ==="

# 1.5 Detener cualquier helper/tarea previa (libera el exe para reinstalar)
Unregister-ScheduledTask -TaskName "PowerTrackpoint Helper" -Confirm:$false -ErrorAction SilentlyContinue
Get-Process tphandler_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

# 2. Localizar tools del Windows SDK (makeappx / signtool)
$sdkPath = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse -ErrorAction SilentlyContinue |
           Where-Object { $_.DirectoryName -like "*x64*" } | Select-Object -First 1
if (!$sdkPath) {
    Write-Output "Windows SDK no detectado. Instalando via winget..."
    winget install Microsoft.WindowsSDK.10.0.18362 --silent --accept-package-agreements --accept-source-agreements
    $sdkPath = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.DirectoryName -like "*x64*" } | Select-Object -First 1
    if (!$sdkPath) { Write-Error "No se pudo localizar el Windows SDK. Instalalo manualmente."; exit 1 }
}
$binDir = $sdkPath.DirectoryName
$makeappx = Join-Path $binDir "makeappx.exe"
$signtool = Join-Path $binDir "signtool.exe"
Write-Output "Herramientas SDK en: $binDir"

# 3. Localizar el paquete Quick Menu original de Lenovo
Write-Output "Buscando el paquete TrackPoint Quick Menu..."
$origPackage = Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers | Select-Object -First 1
if (!$origPackage) {
    Write-Error "El paquete 'TrackPoint Quick Menu' no esta instalado. Instalalo desde la Microsoft Store primero."
    exit 1
}
$origPath = $origPackage.InstallLocation
Write-Output "Quick Menu encontrado en: $origPath"

# 4. Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectDir = Split-Path -Parent $scriptDir
$stagingDir = "C:\PowerTrackpointStaging"
$destDir = "C:\Program Files\PowerTrackpoint"
$pfxPath = Join-Path $destDir "cert.pfx"
$cerPath = Join-Path $destDir "cert.cer"
$msixPath = Join-Path $destDir "PowerTrackpoint.msix"

if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
if (Test-Path $destDir)    { Remove-Item -Recurse -Force $destDir }
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

# 5. Clonar el Quick Menu a staging (clean room: clona lo que ya tienes instalado)
Write-Output "Clonando recursos del Quick Menu..."
Copy-Item -Path "$origPath\*" -Destination $stagingDir -Recurse -Force
Remove-Item -Path (Join-Path $stagingDir "AppxSignature.p7x") -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $stagingDir "TrackPointQuickMenu\TrackPointQuickMenu.exe.bak") -ErrorAction SilentlyContinue

# 5.5 MOCK: quitar la extension <Extensions> (la del protocolo windows.protocol).
# Asi Windows ya no intercepta lenovo-trackpointmenu:// como UWP; queda libre para
# el handler Win32 del registro (instantaneo). shtctky solo valida que el paquete
# exista, asi que sigue disparando el doble-tap.
Write-Output "Neutralizando el protocolo UWP del paquete (mock)..."
$manifestPath = Join-Path $stagingDir "AppxManifest.xml"
$mf = Get-Content -Raw $manifestPath
$mf = $mf -replace '(?s)\s*<Extensions>.*?</Extensions>', ''
[System.IO.File]::WriteAllText($manifestPath, $mf, (New-Object System.Text.UTF8Encoding($false)))

# 6. Certificado auto-firmado
Write-Output "Generando certificado auto-firmado..."
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=20E7E2C9-A2A9-4A02-BB29-6FCFB9E042BB" -KeyUsage DigitalSignature -FriendlyName "PowerTrackpoint Cert" -CertStoreLocation "Cert:\CurrentUser\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
$pwd = ConvertTo-SecureString "123456" -AsPlainText -Force
$null = Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd
$null = Export-Certificate -Cert $cert -FilePath $cerPath

# 7. Confiar el certificado
Write-Output "Instalando el certificado en los almacenes de confianza..."
$null = Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\Root"
$null = Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"

# 8. Empaquetar y firmar el MSIX mock
Write-Output "Empaquetando el MSIX mock..."
& $makeappx pack /d $stagingDir /p $msixPath /o | Out-Null
Write-Output "Firmando el MSIX..."
& $signtool sign /fd SHA256 /a /f $pfxPath /p 123456 $msixPath | Out-Null

# 9. Reemplazar el Quick Menu original por el mock
Write-Output "Instalando el paquete mock..."
Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "E0469640.TrackPointQuickMenu" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
$null = Add-AppxProvisionedPackage -Online -PackagePath $msixPath -SkipLicense
$null = Add-AppxPackage -Path $msixPath -ErrorAction SilentlyContinue

# 10. Instalar cliente + helper SUELTOS en Program Files (Win32, no empaquetados)
Write-Output "Instalando cliente y helper Win32 en Program Files..."
Copy-Item -Path (Join-Path $projectDir "bin\TrackPointQuickMenu.exe") -Destination (Join-Path $destDir "TrackPointQuickMenu.exe") -Force
Copy-Item -Path (Join-Path $projectDir "bin\tphandler_helper.exe")    -Destination (Join-Path $destDir "tphandler_helper.exe") -Force
# El helper lleva uiAccess en su manifest; firmarlo evita que Windows lo rechace.
& $signtool sign /fd SHA256 /f $pfxPath /p 123456 (Join-Path $destDir "tphandler_helper.exe") | Out-Null

# 11. Registrar el protocolo lenovo-trackpointmenu a nivel Win32 (lanzamiento instantaneo)
Write-Output "Registrando el handler Win32 del protocolo..."
$proto = "HKLM:\SOFTWARE\Classes\lenovo-trackpointmenu"
New-Item -Path "$proto\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path $proto -Name "(default)" -Value "URL:lenovo-trackpointmenu Protocol"
Set-ItemProperty -Path $proto -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "$proto\shell\open\command" -Name "(default)" -Value "`"$destDir\TrackPointQuickMenu.exe`" `"%1`""

# 12. Helper como Scheduled Task ELEVADA (admin). Al correr como admin, su SendInput
# salta UIPI (no necesita uiAccess). Trigger al logon, sin limite de tiempo.
Write-Output "Registrando el helper (al logon, elevado)..."
$taskName = "PowerTrackpoint Helper"
$action    = New-ScheduledTaskAction -Execute (Join-Path $destDir "tphandler_helper.exe")
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
$null = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

# 12.5 (opt-in) Sacar el prompt de UAC del Secure Desktop para poder clickearlo.
# BAJA la seguridad de UAC. Solo con -AllowClickUAC.
if ($AllowClickUAC) {
    Write-Output "ADVERTENCIA: deshabilitando Secure Desktop de UAC (PromptOnSecureDesktop=0) - baja la seguridad de UAC."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name PromptOnSecureDesktop -Value 0
}

# 13. Limpieza
Remove-Item -Recurse -Force $stagingDir

Write-Output "=== INSTALACION COMPLETADA CON EXITO ==="
Write-Output "PowerTrackpoint listo (cliente Win32 instantaneo + helper elevado). Haz doble tap en tu TrackPoint."
