/* ********************************************************************************************** *
 * OCaml Labs, University of Cambridge                                                            *
 * ********************************************************************************************** *
 * OCaml Windows Test Harness Wrapper Scripts                                                     *
 * ********************************************************************************************** *
 * Copyright (c) 2017 MetaStack Solutions Ltd.                                                    *
 * ********************************************************************************************** *
 * Author: David Allsopp                                                                          *
 * 19-Mar-2017                                                                                    *
 * ********************************************************************************************** *
 * Redistribution and use in source and binary forms, with or without modification, are permitted *
 * provided that the following two conditions are met:                                            *
 *     1. Redistributions of source code must retain the above copyright notice, this list of     *
 *        conditions and the following disclaimer.                                                *
 *     2. Neither the name of MetaStack Solutions Ltd. nor the names of its contributors may be   *
 *        used to endorse or promote products derived from this software without specific prior   *
 *        written permission.                                                                     *
 *                                                                                                *
 * This software is provided by the Copyright Holder 'as is' and any express or implied           *
 * warranties including, but not limited to, the implied warranties of merchantability and        *
 * fitness for a particular purpose are disclaimed. In no event shall the Copyright Holder be     *
 * liable for any direct, indirect, incidental, special, exemplary, or consequential damages      *
 * (including, but not limited to, procurement of substitute goods or services; loss of use,      *
 * data, or profits; or business interruption) however caused and on any theory of liability,     *
 * whether in contract, strict liability, or tort (including negligence or otherwise) arising in  *
 * any way out of the use of this software, even if advised of the possibility of such damage.    *
 * ********************************************************************************************** */

#include <windows.h>
#include <stdio.h>

BOOL CALLBACK enumerator(HWND hWnd, LPARAM lParam) {
  STARTUPINFO* si = (STARTUPINFO*)lParam;
  DWORD pID;
  GetWindowThreadProcessId(hWnd, &pID);
  if (pID == si->dwFlags) {
    //printf("Found and adjusting!\n");
    SetWindowPos(hWnd, NULL, si->dwX, si->dwY, si->dwXSize, si->dwYSize, SWP_NOOWNERZORDER | SWP_NOZORDER);
    return FALSE;
  } else {
    return TRUE;
  }
}

int main (int argc, char* argv[]) {
  int l;
  if (argc < 3 || (l = strlen(argv[2])) == 1 && argv[2][0] != 'E' && argv[2][0] != 'W' || !l || l > 2 || (l == 2 && argv[2][0] != 'N' && argv[2][0] != 'S') || (l == 2 && argv[2][1] != 'E' && argv[2][1] != 'W')) {
    printf("Usage: snap {exe} {region} [params]\nregion = NW|NE|SW|SE|E|W\n");
    return 1;
  }

  int cmd_len = 0;
  LPTSTR lpCommandLine = NULL;
  if (argc > 3) {
    int i;
    /* @@DRA No effort to escape here - is there an API for going from argv to str? */
    for (i = 3; i < argc; cmd_len += strlen(argv[i++]) + 1);
    LPTSTR buf = lpCommandLine = (LPTSTR)malloc(cmd_len);
    for (i = 3; i < argc; i++) {
      strcpy(buf, argv[i]);
      buf += strlen(argv[i]);
      *buf++ = ' ';
    }
    *--buf = '\0';
  }

  HWND hWnd = GetActiveWindow();
  HMONITOR hMonitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi;
  mi.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(hMonitor, &mi)) {
    printf("Failed to determine screen resolution!\n");
    return 1;
  }

  //printf("Resolution: %dx%d\n", mi.rcWork.right - mi.rcWork.left, GetSystemMetrics(SM_CYMAXIMIZED));

  DWORD sx = (mi.rcWork.right - mi.rcWork.left) / 2;
  DWORD sy = (mi.rcWork.bottom - mi.rcWork.top) / 3;
  DWORD x = argv[2][0] == 'E' || argv[2][1] == 'E' ? sx : 0;
  DWORD y = argv[2][0] == 'S' ? 2 * sy : l == 1 ? sy : 0;

  //printf("Computed (x, y) = (%d, %d) and (sx, sy) = (%d, %d)\n", x, y, sx, sy);

  STARTUPINFO si = {sizeof(STARTUPINFO), 0, NULL, NULL, x, y, sx, sy, 0, 0, 0, STARTF_USEPOSITION | STARTF_USESIZE, 0, 0, NULL, NULL, NULL, NULL};
  PROCESS_INFORMATION pi;
  if (!CreateProcess(argv[1], lpCommandLine, NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
    printf("Failed to create the process\n");
    return 1;
  }
  WaitForInputIdle(pi.hProcess, INFINITE);
  Sleep(100);
  //printf("pi.dwProcessId = %d\n", pi.dwProcessId);
  si.dwFlags = pi.dwProcessId;
  EnumWindows(&enumerator, (LPARAM)&si);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);

  return 0;
}
