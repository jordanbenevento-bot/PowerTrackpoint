$ErrorActionPreference = "SilentlyContinue"

# uninstall.ps1 — revierte PowerTrackpoint y restaura el estado original.
# Quita el helper + su Scheduled Task, el paquete modificado, y restaura el
# Secure Desktop de UAC. Despues hay que reinstalar "TrackPoint Quick Menu"
# desde la Microsoft Store para recuperar el menu original de Lenovo.

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
Remove-Item -Recurse -Force "C:\Program Files\PowerTrackpoint"

# 2. Paquete modificado (cliente)
Write-Output "Quitando el paquete modificado..."
Get-AppxPackage -Name E0469640.TrackPointQuickMenu -AllUsers | Remove-AppxPackage
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "E0469640.TrackPointQuickMenu" } | Remove-AppxProvisionedPackage -Online

# 3. Restaurar el Secure Desktop de UAC (por si se uso -AllowClickUAC)
Write-Output "Restaurando el Secure Desktop de UAC..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name PromptOnSecureDesktop -Value 1

Write-Output "=== Desinstalacion completada ==="
Write-Output "Reinstala 'TrackPoint Quick Menu' desde la Microsoft Store para volver al menu original de Lenovo."
