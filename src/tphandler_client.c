#include <windows.h>

/*
 * Cliente PowerTrackpoint — lo lanza la activacion del protocolo
 * lenovo-trackpointmenu:// (v="shtctky.exe") al hacer doble-tap en el TrackPoint.
 *
 * IMPORTANTE: este exe NO debe declarar uiAccess. La activacion de protocolo de
 * un paquete MSIX RECHAZA lanzar un exe con uiAccess=true (error 0x300D
 * "Solicitud no compatible"), rompiendo el click por completo. Por eso el bypass
 * de UIPI lo hace el helper (tphandler_helper.exe), que NO se lanza por
 * activacion sino por Task Scheduler, donde uiAccess si se honra.
 *
 * Flujo: si el helper esta vivo, lo senalizamos (el helper hace el SendInput con
 * uiAccess -> funciona sobre ventanas de Administrador). Si el helper no esta,
 * hacemos el click directo nosotros (degradacion: anda en ventanas normales, no
 * sobre admin) para no perder NUNCA el click basico.
 */
int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    /* El helper mantiene abierto este mutex mientras vive: lo usamos para saber
       si esta corriendo sin depender de timing del Named Event. */
    HANDLE helper = OpenMutexW(SYNCHRONIZE, FALSE, L"Local\\TrackPointHelperSingleton");
    if (helper) {
        CloseHandle(helper);
        HANDLE ev = OpenEventW(EVENT_MODIFY_STATE, FALSE, L"Local\\TrackPointClickEvent");
        if (ev) {
            SetEvent(ev);          /* el helper despierta y hace el click */
            CloseHandle(ev);
            return 0;
        }
    }

    /* Fallback: helper no disponible -> click directo (sin bypass UIPI). */
    INPUT inputs[2];
    ZeroMemory(inputs, sizeof(inputs));
    inputs[0].type = INPUT_MOUSE;
    inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    inputs[1].type = INPUT_MOUSE;
    inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(2, inputs, sizeof(INPUT));
    return 0;
}
