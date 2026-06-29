#include <windows.h>

/*
 * Helper residente de PowerTrackpoint.
 *
 * Lo lanza una Scheduled Task al logon con RunLevel Highest (ADMINISTRADOR). Al
 * correr elevado, su SendInput salta UIPI e inyecta el click sobre ventanas de
 * apps de Administrador (integrity level alto). El manifest uiAccess del exe
 * (resource.rc) es un resabio inofensivo: con privilegios de admin el bypass de
 * UIPI no lo necesita.
 *
 * Duerme esperando el Named Event que senaliza el cliente Win32 y hace el click.
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

    /* Latencia minima: el helper duerme casi todo el tiempo (WaitForSingleObject)
       y solo despierta un instante para el click, asi que subir la prioridad es
       seguro (no acapara CPU) y recorta el retraso de wakeup tras el SetEvent del
       cliente -> el hop de IPC se siente casi como un click directo. */
    SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS);
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);

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
