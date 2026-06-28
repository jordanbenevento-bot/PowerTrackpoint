#include <windows.h>

/*
 * Helper residente de PowerTrackpoint.
 *
 * Lo lanza una Scheduled Task "al logon" (sesion interactiva, sin elevacion).
 * Su exe lleva el manifest uiAccess=true (resource.rc) y va firmado Authenticode
 * en C:\Program Files\PowerTrackpoint\ (secure location). Lanzado asi (NO por
 * activacion de protocolo MSIX), Windows SI honra uiAccess -> su SendInput salta
 * UIPI e inyecta el click sobre ventanas de Administrador (integrity level alto).
 *
 * Espera el Named Event que senaliza el cliente liviano y hace el click.
 */
int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    /* Singleton: si ya hay un helper, salir. El cliente usa este mutex para
       detectar que el helper esta vivo. Lo dejamos abierto toda la vida del proceso. */
    HANDLE once = CreateMutexW(NULL, TRUE, L"Local\\TrackPointHelperSingleton");
    if (once == NULL || GetLastError() == ERROR_ALREADY_EXISTS) {
        return 0;
    }

    /* Event auto-reset: cada SetEvent del cliente = un click. CreateEvent lo crea
       o abre el existente (sin depender de quien arranco primero). */
    HANDLE ev = CreateEventW(NULL, FALSE, FALSE, L"Local\\TrackPointClickEvent");
    if (ev == NULL) {
        return 1;
    }

    INPUT inputs[2];
    ZeroMemory(inputs, sizeof(inputs));
    inputs[0].type = INPUT_MOUSE;
    inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    inputs[1].type = INPUT_MOUSE;
    inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;

    for (;;) {
        if (WaitForSingleObject(ev, INFINITE) != WAIT_OBJECT_0) {
            break;
        }
        SendInput(2, inputs, sizeof(INPUT));
    }

    CloseHandle(ev);
    return 0;
}
