/* wineres: resize the Wine virtual desktop and refit the windows on it.
   usage: wineres            -> print current size and top-level windows
          wineres W H        -> switch the desktop to WxH (the size must already be the
                                registry's Explorer\Desktops\Default so Wine offers it),
                                then re-maximize windows that were maximized or filled
                                the old desktop. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static int oldw, oldh, list_only;

static BOOL CALLBACK refit(HWND hwnd, LPARAM lp) {
  char title[160] = "";
  RECT r;
  LONG style = GetWindowLongA(hwnd, GWL_STYLE);
  if (!IsWindowVisible(hwnd)) return TRUE;
  GetWindowTextA(hwnd, title, sizeof title);
  GetWindowRect(hwnd, &r);
  int zoomed = IsZoomed(hwnd);
  if (list_only) {
    printf("hwnd %p style=%08lx zoomed=%d rect=%ld,%ld %ldx%ld '%s'\n", hwnd, style, zoomed, r.left, r.top,
           r.right - r.left, r.bottom - r.top, title);
    return TRUE;
  }
  int filled = r.right - r.left >= oldw - 16 && r.bottom - r.top >= oldh - 80;
  if (zoomed) {
    /* Maximized windows keep their old maximized rect. Resize them in place to the new
       maximized rect (work area plus the hidden frame). Restoring and maximizing again
       would briefly un-cover the desktop, and Wine then drops the fullscreen state of its
       desktop window, so Hyprland leaves fullscreen. */
    RECT wa;
    SystemParametersInfoA(SPI_GETWORKAREA, 0, &wa, 0);
    int fx = GetSystemMetrics(SM_CXSIZEFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER);
    int fy = GetSystemMetrics(SM_CYSIZEFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER);
    SetWindowPos(hwnd, NULL, wa.left - fx, wa.top - fy, wa.right - wa.left + 2 * fx,
                 wa.bottom - wa.top + 2 * fy, SWP_NOZORDER | SWP_NOACTIVATE);
  } else if (filled) {
    RECT wa;
    SystemParametersInfoA(SPI_GETWORKAREA, 0, &wa, 0);
    SetWindowPos(hwnd, NULL, wa.left, wa.top, wa.right - wa.left, wa.bottom - wa.top,
                 SWP_NOZORDER | SWP_NOACTIVATE);
  }
  return TRUE;
}

int main(int argc, char **argv) {
  DEVMODEA dm = { .dmSize = sizeof(dm) };
  EnumDisplaySettingsA(NULL, ENUM_CURRENT_SETTINGS, &dm);
  oldw = dm.dmPelsWidth; oldh = dm.dmPelsHeight;
  printf("current %dx%d\n", oldw, oldh);
  if (argc < 3) { list_only = 1; EnumWindows(refit, 0); return 0; }

  DEVMODEA nm = { .dmSize = sizeof(nm) };
  nm.dmPelsWidth = atoi(argv[1]); nm.dmPelsHeight = atoi(argv[2]);
  nm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
  if ((int)nm.dmPelsWidth != oldw || (int)nm.dmPelsHeight != oldh) {
    LONG r = ChangeDisplaySettingsExA(NULL, &nm, NULL, 0, NULL);
    printf("change %ld\n", r);
    if (r != DISP_CHANGE_SUCCESSFUL) return 1;
    /* Let apps handle WM_DISPLAYCHANGE first; some re-place their windows on it. */
    Sleep(600);
  }
  EnumWindows(refit, 0);
  return 0;
}
