# PowerTrackpoint (Alpha)

**PowerTrackpoint** is an open-source utility that brings instant, lag-free tap-to-click functionality to ThinkPad TrackPoints (pointing sticks), completely bypassing and replacing the intrusive and slow Lenovo TrackPoint Quick Menu.

*Leer en [Español](#español).*

---

## How It Works

1. **Hardware Event:** A physical tap or double-tap on the TrackPoint is captured by the embedded controller (EC) and routed to Lenovo's hotkey service (`shtctky.exe`).
2. **Protocol Trigger:** The Lenovo service checks if the quick menu package is installed and triggers the custom UWP protocol `lenovo-trackpointmenu://`.
3. **PowerTrackpoint Interceptor:** PowerTrackpoint overrides this protocol handler with a lightweight native C client (`TrackPointQuickMenu.exe`). It signals a session-local Named Event (`Local\TrackPointClickEvent`) for the helper to act on and exits in under a millisecond. If the helper isn't running, it falls back to injecting the click itself.
4. **uiAccess Clicker Helper:** A tiny background process (`tphandler_helper.exe`) — installed signed in `Program Files` and launched at logon by a Scheduled Task with the `uiAccess=true` privilege — listens for the Named Event and injects a Left Mouse Click via `SendInput`. uiAccess lets the click **bypass UIPI and reach windows of elevated (Administrator) apps**. The client itself must NOT carry uiAccess: MSIX protocol activation refuses to launch a uiAccess exe (error `0x300D`), so the privileged work lives in the Task-Scheduler-launched helper (which *can* get uiAccess).

By bypassing the heavy WPF/.NET Framework UI container of the original Lenovo Quick Menu, the tap-to-click response is **instantaneous** (practically zero latency).

---

## Known Issues (Alpha Stage)

*   **UAC Consent Prompt:** Clicking now works on elevated **app** windows (the uiAccess helper bypasses UIPI). The remaining exception is the UAC consent prompt itself, which runs on the isolated **Secure Desktop** — unreachable by `SendInput` by design. Run the installer with `-AllowClickUAC` to move UAC off the Secure Desktop if you want the TrackPoint to click it (this lowers UAC security).
*   **Middle Button Scroll:** The middle scroll button of the Trackpoint stops working when using this customization (currently under investigation; the pointing device is Synaptics `SYNA802E` with `SynHsaService`).
*   **Trackpoint Settings Panel:** The Trackpoint options tab inside the Windows Mouse Properties dialog (Control Panel) stops working correctly.
*   **Lenovo Driver Updates:** Standard Lenovo Vantage or driver updates might overwrite or revert this customization.
*   **Helper Process Interruption:** If the helper (`tphandler_helper.exe`) stops, the Scheduled Task restarts it automatically (3 retries) and again at next logon. You can also re-trigger it with the Lenovo **Fn + G** hotkey — it toggles the Quick Menu and restarts the service if it stopped (note it also fires a click at the current pointer position). Meanwhile the client falls back to a normal (non-UIPI) click, so basic tap-to-click never breaks.
*   **Pre-Logon Session:** Tap-to-click is not active on the Windows lock screen/before logging in, as the helper runs inside the active user's session context.
*   **Non-Admin Users:** Untested on standard (non-administrator) user accounts.

---

## Compatibility

This utility is designed for **modern Lenovo ThinkPads** equipped with ELAN or Synaptics PointStick pointing device drivers that support the double-tap Quick Menu shortcut.

*   **Tested Device:** ThinkPad X1 2-in-1 Aura Edition. The pointing stick enumerates as Synaptics `HID\SYNA802E` (the bundled *TrackPoint* settings app is ELAN-branded, but the HID device reports as Synaptics).
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
    # optional: also let the TrackPoint click the UAC prompt (this lowers UAC security)
    # .\scripts\install.ps1 -AllowClickUAC
    ```
4.  The script locates the Windows SDK tools (auto-installs via `winget` if missing), clones your local Quick Menu resources, injects + Authenticode-signs our client, builds and signs the MSIX, provisions it, and installs the uiAccess helper as a logon Scheduled Task.
5.  Double-tap your TrackPoint to test!

> **Building from source (devs):** the prebuilt `bin/*.exe` are committed. To rebuild the C client + helper, run `bash scripts/build.sh` (cross-compiles with mingw-w64; embeds the `uiAccess` manifest into the helper only).

---

## Uninstall

Run `scripts/uninstall.ps1` as Administrator — it removes the helper, its Scheduled Task and the modified package, and restores the UAC Secure Desktop. Then reinstall **TrackPoint Quick Menu** from the Microsoft Store to get Lenovo's original menu back.

## Troubleshooting

*   **No click at all:** confirm the helper is running with `Get-Process tphandler_helper`; if not, `Start-ScheduledTask -TaskName "PowerTrackpoint Helper"`. The client falls back to a direct click when the helper is down, so a fully dead click usually means the protocol activation itself failed — re-run the installer.
*   **Clicks work on normal windows but not Administrator ones:** the helper isn't getting uiAccess. Check that `tphandler_helper.exe` is signed and located under `C:\Program Files\` (a secure location) and that UAC (`EnableLUA`) is enabled.

---

## Contributing

This project is in its **Alpha** stage. Contributions are very welcome! Areas we want to improve:
*   ✅ ~~Support for clicking inside high-integrity (Administrator) windows (bypassing UIPI).~~ — done via the uiAccess helper.
*   Restoring the middle scroll button and mouse settings panel integration.
*   A configuration UI to adjust tap sensitivity and double-tap delay intervals.
*   Support for Drag & Drop gestures using tap-and-hold logic.

---

# Español

**PowerTrackpoint** es una herramienta de código abierto que implementa la función de tap-to-click (toque para hacer click) instantánea y sin lag en los TrackPoints de laptops Lenovo ThinkPad, reemplazando el lento menú contextual original (Lenovo TrackPoint Quick Menu).

## Cómo Funciona

1. **Evento físico:** El doble toque físico en el TrackPoint es capturado por el firmware y enviado al sistema de hotkeys de Lenovo (`shtctky.exe`).
2. **Activación de Protocolo:** El servicio de Lenovo invoca el protocolo UWP `lenovo-trackpointmenu://`.
3. **Interceptor PowerTrackpoint:** Reemplazamos este launcher con un cliente nativo en C ultra-rápido (`TrackPointQuickMenu.exe`) que emite una señal (`Local\TrackPointClickEvent`) para que el helper actúe, y se cierra en menos de un milisegundo. Si el helper no está corriendo, hace el click él mismo como fallback.
4. **Helper con uiAccess:** Un pequeño proceso en segundo plano (`tphandler_helper.exe`) — instalado firmado en `Program Files` y lanzado al logon por una Scheduled Task con el privilegio `uiAccess=true` — escucha la señal e inyecta el click con `SendInput`. uiAccess permite **saltar UIPI y clickear sobre ventanas de apps de Administrador**. El cliente NO puede llevar uiAccess: la activación de protocolo MSIX se niega a lanzar un exe con uiAccess (error `0x300D`), por eso el trabajo privilegiado vive en el helper lanzado por Task Scheduler (que sí puede obtener uiAccess).

---

## Problemas Conocidos (Estado Alpha)

*   **Prompt de UAC:** El click ya funciona sobre ventanas de **apps** de Administrador (el helper uiAccess salta UIPI). La excepción que queda es el propio prompt de UAC, que corre en el **Secure Desktop** aislado — inalcanzable por `SendInput` por diseño. Corré el instalador con `-AllowClickUAC` para sacar UAC del Secure Desktop si querés que el TrackPoint lo clickee (baja la seguridad de UAC).
*   **Botón del Medio (Scroll):** El botón central de scroll deja de funcionar tras aplicar la personalización (bajo investigación; el dispositivo es Synaptics `SYNA802E` con `SynHsaService`).
*   **Panel de Configuración de Trackpoint:** La pestaña de opciones del Trackpoint en la "Configuración de Mouse" de Windows (Panel de Control) deja de responder correctamente.
*   **Actualizaciones de Drivers de Lenovo:** Las actualizaciones automáticas de Lenovo Vantage o de Windows podrían sobrescribir y revertir esta personalización.
*   **Interrupción del Helper:** Si el helper (`tphandler_helper.exe`) se detiene, la Scheduled Task lo reinicia sola (3 reintentos) y de nuevo al próximo logon. También podés reactivarlo con el hotkey de Lenovo **Fn + G** — habilita/deshabilita el Quick Menu y reinicia el servicio si se cayó (ojo que además dispara un click donde esté el puntero). Mientras tanto el cliente cae a un click normal (sin UIPI), así que el tap-to-click básico nunca se rompe.
*   **Sesión de Pre-Inicio:** Tap-to-click no funciona en la pantalla de bloqueo de Windows, ya que el helper requiere iniciar sesión de usuario.
*   **Usuarios No Administradores:** Sin probar en cuentas de usuario estándar.

---

## Compatibilidad

Diseñado para **ThinkPads modernos** con drivers ELAN/Synaptics PointStick que soporten el acceso rápido de doble tap.
*   **Dispositivo Probado:** ThinkPad X1 2-in-1 Aura Edition. El pointing stick aparece como Synaptics `HID\SYNA802E` (la app de *TrackPoint* incluida es de marca ELAN, pero el dispositivo HID reporta como Synaptics).
*   **Requisitos:** Windows 10/11 y tener instalada la app original "TrackPoint Quick Menu" desde la Microsoft Store (se utiliza para clonar sus assets).

---

## Legalidad y Empaquetado Clean Room

Para respetar los derechos de autor y las licencias:
*   **No se distribuye ningún binario ni recurso propietario** en este repositorio.
*   El script de instalación (`install.ps1`) clona dinámicamente los recursos con licencia (imágenes, traducciones, metadata del manifiesto) que ya están presentes en la carpeta `WindowsApps` de tu propio sistema.
*   Luego inserta nuestro inyector de clicks nativo y de código abierto, lo empaqueta en un nuevo contenedor `.msix`, lo firma localmente con un certificado auto-firmado de confianza para tu equipo, y lo aprovisiona a nivel de máquina.

---

## Instalación

1.  Clona el repositorio o descarga los archivos de la versión.
2.  Abre **PowerShell como Administrador**.
3.  Ejecuta el script de instalación:
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\scripts\install.ps1
    # opcional: permite que el TrackPoint clickee el prompt de UAC (baja la seguridad de UAC)
    # .\scripts\install.ps1 -AllowClickUAC
    ```
4.  El script ubica las herramientas del Windows SDK (las instala con `winget` si faltan), clona tus recursos locales del Quick Menu, inyecta y firma (Authenticode) nuestro cliente, arma y firma el MSIX, lo aprovisiona, e instala el helper uiAccess como Scheduled Task al logon.
5.  ¡Haz doble tap en tu TrackPoint para probar!

> **Compilar desde fuente (devs):** los `bin/*.exe` ya vienen compilados. Para recompilar el cliente + helper, corre `bash scripts/build.sh` (cross-compile con mingw-w64).

---

## Desinstalación

Corre `scripts/uninstall.ps1` como Administrador — quita el helper, su Scheduled Task y el paquete modificado, y restaura el Secure Desktop de UAC. Después reinstala **TrackPoint Quick Menu** desde la Microsoft Store para recuperar el menú original de Lenovo.

## Solución de Problemas

*   **No hace click:** confirma que el helper corra con `Get-Process tphandler_helper`; si no, `Start-ScheduledTask -TaskName "PowerTrackpoint Helper"`. El cliente cae a un click directo cuando el helper está caído, así que un click totalmente muerto suele significar que falló la activación del protocolo — vuelve a correr el instalador.
*   **Clickea en ventanas normales pero no en las de Administrador:** el helper no está obteniendo uiAccess. Verifica que `tphandler_helper.exe` esté firmado y ubicado en `C:\Program Files\` (secure location) y que UAC (`EnableLUA`) esté activo.

---

## Licencia

Distribuido bajo la licencia [MIT](LICENSE).
