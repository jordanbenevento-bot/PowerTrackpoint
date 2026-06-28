#include <windows.h>

int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    // 1. Ensure single instance
    HANDLE hMutex = CreateMutex(NULL, TRUE, "Local\\TrackPointHelperMutex");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        return 0;
    }
    
    // 2. Create the Named Event
    HANDLE hEvent = CreateEvent(NULL, FALSE, FALSE, "Local\\TrackPointClickEvent");
    if (!hEvent) {
        return 1;
    }
    
    // 3. Main Loop
    while (WaitForSingleObject(hEvent, INFINITE) == WAIT_OBJECT_0) {
        INPUT inputs[2];
        ZeroMemory(inputs, sizeof(inputs));
        
        inputs[0].type = INPUT_MOUSE;
        inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        
        inputs[1].type = INPUT_MOUSE;
        inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
        
        SendInput(2, inputs, sizeof(INPUT));
    }
    
    CloseHandle(hEvent);
    CloseHandle(hMutex);
    return 0;
}
