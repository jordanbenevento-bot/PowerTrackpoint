# PowerTrackpoint (Alpha)

**PowerTrackpoint** is an open-source utility that brings instant, lag-free tap-to-click functionality to ThinkPad TrackPoints (pointing sticks), completely bypassing and replacing the intrusive and slow Lenovo TrackPoint Quick Menu.

*Leer en [Español](#español).*

---

## How It Works

1. **Hardware Event:** A physical tap or double-tap on the TrackPoint is captured by the embedded controller (EC) and routed to Lenovo's hotkey service (`shtctky.exe`).
2. **Protocol Trigger:** The Lenovo service checks if the quick menu package is installed and triggers the custom UWP protocol `lenovo-trackpointmenu://`.
3. **PowerTrackpoint Interceptor:** PowerTrackpoint overrides this protocol handler with a lightweight native C client (`TrackPointQuickMenu.exe`) that instantly signals a session-local Named Event (`Local\TrackPointClickEvent`) and exits in less than a millisecond.
4. **Silent Clicker Helper:** A tiny, silent background process (`tphandler_helper.exe`) running in the user session listens for the Named Event and immediately injects a physical Left Mouse Click using the Win32 `SendInput` API.

By bypassing the heavy WPF/.NET Framework UI container of the original Lenovo Quick Menu, the tap-to-click response is **instantaneous** (practically zero latency).

---

## Known Issues (Alpha Stage)

*   **Administrator Windows (UIPI):** Clicking does not work when hovering over applications running with administrative privileges (e.g., Task Manager, Administrator PowerShell/CMD) due to Windows User Interface Privilege Isolation (UIPI) security restrictions.
*   **Middle Button Scroll:** On some models, the middle scroll button of the Trackpoint might temporarily stop scrolling (under investigation). *Try restarting the ELAN UWP helper if this happens.*
*   **Helper Process Interruption:** The background helper (`tphandler_helper.exe`) may occasionally stop. You can manually restart it using a keyboard shortcut or the Task Scheduler.
*   **Pre-Logon Session:** Tap-to-click is not active on the Windows lock screen/before logging in, as the helper runs inside the active user's session context.
*   **Non-Admin Users:** Untested on standard (non-administrator) user accounts.

---

## Compatibility

This utility is designed for **modern Lenovo ThinkPads** equipped with ELAN or Synaptics PointStick pointing device drivers that support the double-tap Quick Menu shortcut.

*   **Tested Device:** ThinkPad X1 2-in-1 Aura Edition (using ELAN PointStick driver).
*   **Requirements:** Windows 10 or 11, with the original "TrackPoint Quick Menu" app installed from the Microsoft Store (used as a base for cloning resources).

---

## Legality & Clean Room Packaging

To respect copyrights and licenses:
*   **No proprietary binaries or assets are distributed** in this repository.
*   The installation script (`install.ps1`) dynamically clones the licensed resources (images, translations, configuration manifest metadata) already present in your local system's `WindowsApps` folder.
*   It then inserts our open-source native click injector, packages it into a new `.msix` container, signs it locally with a self-signed certificate trusted by your computer, and provisions it machine-wide.

---

## Installation

1.  Clone this repository or download the latest release files.
2.  Open **PowerShell as Administrator** in Windows.
3.  Navigate to the project directory and run the installer script:
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\scripts\install.ps1
    ```
4.  The script will check for the Windows SDK tools (automatically installing them via `winget` if missing), extract your local resources, build the signed MSIX package, provision it, and start the background helper task.
5.  Double-tap your TrackPoint to test!

---

## Contributing

This project is in its **Alpha** stage. Contributions are very welcome! Areas we want to improve:
*   Support for clicking inside high-integrity (Administrator) windows (bypassing UIPI).
*   A configuration UI to adjust tap sensitivity and double-tap delay intervals.
*   Support for Drag & Drop gestures using tap-and-hold logic.

---

# Español

**PowerTrackpoint** es una herramienta de código abierto que implementa la función de tap-to-click (toque para hacer click) instantánea y sin lag en los TrackPoints de laptops Lenovo ThinkPad, reemplazando el lento menú contextual original (Lenovo TrackPoint Quick Menu).

## Cómo Funciona

1. **Evento físico:** El doble toque físico en el TrackPoint es capturado por el firmware y enviado al sistema de hotkeys de Lenovo (`shtctky.exe`).
2. **Activación de Protocolo:** El servicio de Lenovo invoca el protocolo UWP `lenovo-trackpointmenu://`.
3. **Interceptor PowerTrackpoint:** Reemplazamos este launcher con un cliente nativo en C ultra-rápido (`TrackPointQuickMenu.exe`) que emite una señal (`Local\TrackPointClickEvent`) y se cierra en menos de un milisegundo.
4. **Helper en Background:** Un pequeño proceso en segundo plano (`tphandler_helper.exe`) escucha la señal e inyecta un click izquierdo del mouse físico usando la API de Windows `SendInput`.

---

## Problemas Conocidos (Estado Alpha)

*   **Ventanas de Administrador (UIPI):** El click no funciona si el cursor está sobre aplicaciones que se ejecutan como Administrador debido a las restricciones de seguridad de Windows (UIPI).
*   **Botón del Medio (Scroll):** En algunos modelos, el botón central de scroll podría dejar de funcionar temporalmente (bajo investigación). *Intenta reiniciar el proceso de fondo de ELAN si esto ocurre.*
*   **Interrupción del Helper:** El proceso de fondo `tphandler_helper.exe` podría detenerse ocasionalmente. Puede reiniciarse manualmente mediante un atajo o desde el programador de tareas.
*   **Sesión de Pre-Inicio:** Tap-to-click no funciona en la pantalla de bloqueo de Windows, ya que el helper requiere iniciar sesión de usuario.
*   **Usuarios No Administradores:** Sin probar en cuentas de usuario estándar.

---

## Compatibilidad

Diseñado para **ThinkPads modernos** con drivers ELAN/Synaptics PointStick que soporten el acceso rápido de doble tap.
*   **Dispositivo Probado:** ThinkPad X1 2-in-1 Aura Edition.
*   **Requisitos:** Windows 10/11 y tener instalada la app original "TrackPoint Quick Menu" desde la Microsoft Store (se utiliza para clonar sus assets).

---

## Instalación

1.  Clona el repositorio o descarga los archivos de la versión.
2.  Abre **PowerShell como Administrador**.
3.  Ejecuta el script de instalación:
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\scripts\install.ps1
    ```
4.  ¡Listo! Disfruta de un click instantáneo en tu TrackPoint.

---

## Licencia

Distribuido bajo la licencia [MIT](LICENSE).
