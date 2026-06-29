# PowerTrackpoint (Alpha)

**PowerTrackpoint** is an open-source utility that brings instant, lag-free tap-to-click functionality to ThinkPad TrackPoints (pointing sticks), completely bypassing and replacing the intrusive and slow Lenovo TrackPoint Quick Menu.

*Leer en [Español](#español).*

---

## How It Works

1. **Hardware Event:** A tap or double-tap on the TrackPoint is captured by the embedded controller and routed to Lenovo's hotkey service (`shtctky.exe`), which fires the `lenovo-trackpointmenu://` protocol.
2. **Mock MSIX:** PowerTrackpoint clones Lenovo's Quick Menu package and **strips the protocol extension from its manifest**, then reinstalls it signed. `shtctky` still sees the package installed (so it keeps firing the double-tap), but Windows no longer claims the protocol as a UWP app — which removes the ~100 ms UWP activation lag.
3. **Win32 Protocol Handler:** `lenovo-trackpointmenu` is registered in the registry (`HKLM\SOFTWARE\Classes\…`) pointing to a tiny native C client in `Program Files`. Windows launches it **instantly** (no UWP container); the client signals a Named Event (`Local\TrackPointClickEvent`).
4. **Elevated Helper:** A small background process (`tphandler_helper.exe`) runs as **Administrator** (Scheduled Task, `RunLevel Highest`), sleeping on the Named Event. When signaled it injects a Left Mouse Click via `SendInput` with admin privileges — **bypassing UIPI to click elevated (Administrator) app windows**. (Earlier designs tried a `uiAccess` helper, but MSIX protocol activation rejects a `uiAccess` exe with error `0x300D`; running the helper elevated is simpler and the latency fix came from the Win32 handler, not the helper.)

The result is a tap-to-click that is **instantaneous** and works over Administrator app windows.

---

## Known Issues (Alpha Stage)

*   **UAC Consent Prompt:** Clicking works on elevated **app** windows (the elevated helper bypasses UIPI). The remaining exception is the UAC consent prompt itself, which runs on the isolated **Secure Desktop** — unreachable by `SendInput` by design. Run the installer with `-AllowClickUAC` to move UAC off the Secure Desktop if you want the TrackPoint to click it (this lowers UAC security).
*   **Middle Button Scroll:** The middle scroll button of the Trackpoint stops working when using this customization (currently under investigation; the pointing device is Synaptics `SYNA802E` on generic Windows drivers — the press-to-scroll behavior is added by Lenovo software, not the driver).
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
*   It repackages that clone into a new `.msix` — **with the UWP protocol extension stripped out** — signs it locally with a self-signed certificate trusted by your computer, and provisions it machine-wide. Our own open-source Win32 client and helper install separately into `Program Files` (they are the only binaries this repo ships).

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
*   ✅ ~~Support for clicking inside high-integrity (Administrator) windows (bypassing UIPI).~~ — done via the elevated helper + Win32 protocol handler.
*   Restoring the middle scroll button and mouse settings panel integration.
*   A configuration UI to adjust tap sensitivity and double-tap delay intervals.
*   Support for Drag & Drop gestures using tap-and-hold logic.

---

# Español

**PowerTrackpoint** es una herramienta de código abierto que implementa la función de tap-to-click (toque para hacer click) instantánea y sin lag en los TrackPoints de laptops Lenovo ThinkPad, reemplazando el lento menú contextual original (Lenovo TrackPoint Quick Menu).

## Cómo Funciona

1. **Evento físico:** El doble-tap en el TrackPoint lo captura el firmware y lo enruta al servicio de hotkeys de Lenovo (`shtctky.exe`), que dispara el protocolo `lenovo-trackpointmenu://`.
2. **MSIX mock:** PowerTrackpoint clona el paquete del Quick Menu de Lenovo y le **quita la extensión de protocolo del manifest**, y lo reinstala firmado. `shtctky` sigue viendo el paquete instalado (así sigue disparando el doble-tap), pero Windows ya no reclama el protocolo como app UWP — eso elimina el lag de ~100 ms de la activación UWP.
3. **Handler Win32 del protocolo:** `lenovo-trackpointmenu` queda registrado en el registro (`HKLM\SOFTWARE\Classes\…`) apuntando a un cliente nativo en C en `Program Files`. Windows lo lanza **al instante** (sin contenedor UWP); el cliente señaliza un Named Event (`Local\TrackPointClickEvent`).
4. **Helper elevado:** Un proceso de fondo (`tphandler_helper.exe`) corre como **Administrador** (Scheduled Task, `RunLevel Highest`), durmiendo sobre el Named Event. Al recibir la señal inyecta un click izquierdo con `SendInput` y privilegios de admin — **saltando UIPI para clickear ventanas de apps de Administrador**. (Diseños previos probaron un helper `uiAccess`, pero la activación de protocolo MSIX rechaza un exe `uiAccess` con error `0x300D`; correr el helper elevado es más simple, y el fix de latencia vino del handler Win32, no del helper.)

El resultado: un tap-to-click **instantáneo** que funciona sobre ventanas de apps de Administrador.

---

## Problemas Conocidos (Estado Alpha)

*   **Prompt de UAC:** El click ya funciona sobre ventanas de **apps** de Administrador (el helper elevado salta UIPI). La excepción que queda es el propio prompt de UAC, que corre en el **Secure Desktop** aislado — inalcanzable por `SendInput` por diseño. Corré el instalador con `-AllowClickUAC` para sacar UAC del Secure Desktop si querés que el TrackPoint lo clickee (baja la seguridad de UAC).
*   **Botón del Medio (Scroll):** El botón central de scroll deja de funcionar tras aplicar la personalización (bajo investigación; el dispositivo es Synaptics `SYNA802E` con drivers genéricos de Windows — el press-to-scroll lo agrega el software de Lenovo, no el driver).
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
*   Reempaqueta ese clon en un nuevo `.msix` — **quitándole la extensión de protocolo UWP** —, lo firma localmente con un certificado auto-firmado de confianza para tu equipo, y lo aprovisiona a nivel de máquina. Nuestro cliente y helper Win32 de código abierto se instalan aparte en `Program Files` (son los únicos binarios que este repo distribuye).

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
