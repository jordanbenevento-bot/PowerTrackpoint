$ErrorActionPreference = "SilentlyContinue"

# uninstall.ps1 - revierte PowerTrackpoint y restaura el estado original.
# Quita el helper + su tarea, el handler Win32 del protocolo, los binarios sueltos,
# el paquete mock, y restaura el Secure Desktop de UAC. Despues reinstala
# "TrackPoint Quick Menu" desde la Microsoft Store para volver al menu de Lenovo.

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Error "Este script debe ejecutarse como Administrador."
    exit 1
}

Write-Output "=== Desinstalando PowerTrackpoint ==="

# 1. Helper + tarea
Write-Output "Quitando helper y su tarea..."
Unregister-ScheduledTask -TaskName "PowerTrackpoint Helper" -Confirm:$false
Get-Process tphandler_helper | Stop-Process -Force

# 2. Handler Win32 del protocolo
Write-Output "Quitando el handler Win32 del protocolo..."
Remove-Item -Path "HKLM:\SOFTWARE\Classes\lenovo-trackpointmenu" -Recurse -Force

# 3. Binarios sueltos en Program Files
Remove-Item -Recurse -Force "C:\Program Files\PowerTrackpoint"

# 4. Paquete mock
Write-Output "Quitando el paquete mock..."
Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers | Remove-AppxPackage
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "E0469640.TrackPointQuickMenu" } | Remove-AppxProvisionedPackage -Online

# 5. Restaurar el Secure Desktop de UAC (por si se uso -AllowClickUAC)
Write-Output "Restaurando el Secure Desktop de UAC..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name PromptOnSecureDesktop -Value 1

Write-Output "=== Desinstalacion completada ==="
Write-Output "Reinstala 'TrackPoint Quick Menu' desde la Microsoft Store para volver al menu original de Lenovo."
