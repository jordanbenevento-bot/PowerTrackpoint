#include <windows.h>

int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    // Open the Named Event created by the helper process in the current session
    HANDLE hEvent = OpenEvent(EVENT_MODIFY_STATE, FALSE, "Local\\TrackPointClickEvent");
    if (hEvent) {
        SetEvent(hEvent);
        CloseHandle(hEvent);
    }
    return 0;
}
