# Notes for N-able: Take Control viewer on Linux (Wine + Wayland/Hyprland)

These notes are from getting the N-central Take Control viewer (Integrated Viewer
**7.44.08**, Windows build, installed with N-able's `LinuxNCentral` bundle) working
day to day on Arch Linux / Omarchy 4.5 with Hyprland 0.56 and Wine 11.20. Each item
lists what happens, the evidence, the workaround in this repo, and what a change in the
viewer could do. MSP technicians increasingly work from Linux desktops, and most modern
ones run Wayland compositors, where Wine apps run through XWayland.

## Summary of requests

1. **Retry or defer the local clipboard read** after `WM_CLIPBOARDUPDATE` when no data is
   available, instead of dropping it behind the guard interval. *(Biggest usability win.)*
2. **Re-layout on `WM_DISPLAYCHANGE`**: re-maximize a maximized viewer to the new work area.
3. **Make "Allow resize below the minimum threshold" the default**, or lower the minimum.
4. **A native Linux viewer**, or official support for Wine's virtual desktop mode in the
   Linux bundle (its install script only installs Wine and runs the installer).

## 1. Local → remote clipboard is lost on Wayland compositors

**What happens.** Copy text in a Linux app, switch to the viewer, paste on the remote:
nothing arrives (or the previous clipboard does). Using the viewer's "send clipboard"
menu item a few seconds later works.

**Why.** Hyprland (like other compositors that restrict clipboard access to the focused
client) only serves clipboard data to XWayland clients while an XWayland window has
keyboard focus. The viewer gets `WM_CLIPBOARDUPDATE` the moment the user copies, which
is while focus is still in the Linux app, so the data read fails. Later notifications
are discarded by the viewer's guard interval. Viewer log:

```
[HandleSendLocalClipboard] - LockClipboardSend - 0 | ... | CurrentTabMode - 1
[ClipboardHelperThrd::RequestAllClipboardFormats] - Request all clipboard formats to helper...
[HandleSendLocalClipboard] - Clipboard update ignored... Guard interval not expired...
[TClipboardHelperThrd::HandleReadClipTypeResponse] - ReqSeqNum - 1 | ClipDataFlags - 0x11000001 | ClipDataSize - 0
[TClipboardHelperThrd::HandleReadClipTypeResponse] - Clipboard data for this format not available...
```

**Workaround here.** A helper offers the clipboard again when the viewer gains focus,
so the viewer receives a fresh notification while focused.

**Suggested change.** When the formats are announced but the data reads come back
empty, retry shortly after, or re-read the clipboard when the viewer window is
activated (`WM_ACTIVATE` / `WM_ACTIVATEAPP`) if the clipboard sequence number
(`GetClipboardSequenceNumber`) changed since the last successful send. This would also
help on Windows when another app delay-renders slowly.

## 2. Maximized viewer does not follow a resolution change

**What happens.** When the (virtual) display resolution changes, the maximized viewer
keeps its old maximized rectangle, so it is cut off or leaves empty space.

**Evidence.** After `ChangeDisplaySettingsEx` to a smaller size, `IsZoomed()` is still
true and `GetWindowRect` still returns the old size (for example 1928×1088 inside a
1300×760 desktop).

**Workaround here.** A small Wine tool resizes the maximized window in place to the new
work area after each change. Restore + maximize also works, but it briefly un-covers the
desktop, and Wine then drops the fullscreen state of its desktop window.

**Suggested change.** On `WM_DISPLAYCHANGE` / `WM_SETTINGCHANGE (SPI_SETWORKAREA)`,
re-maximize a maximized viewer to the monitor's current work area. The same issue shows
on Windows when docking or undocking a laptop.

## 3. Minimum window size (~1216×750)

**What happens.** By default the viewer will not go below about 1216×750 (outer size),
larger than a 1366×768 laptop's usable area once a panel or bar is shown, and larger than
a half-width tile on a 1920×1080 monitor. The extra part is simply cut off.

**Workaround.** The viewer already has *Allow resize below the minimum threshold*
(`AllowRemoteDesktopFullResize=1` in `NCentralRDViewer.ini`). With it, every layout
tested fits.

**Suggested change.** Enable it by default, or derive the minimum from the toolbar's
actual needs. With "Always fit to window" the remote image scales anyway.

## 4. Remote → local clipboard (compositor side, for awareness)

Remote copies reach Wine's clipboard correctly (`ReceiveRemoteClipboard` /
`SetClipboardGenericData` succeed). Pasting them into Linux apps then stalls inside
Hyprland's XWayland-to-Wayland transfer. Wine itself serves the selection to X11
clients instantly. Not a viewer bug; the workaround here copies the selection across
directly. Mentioned so support knows that "paste from remote hangs" on Hyprland is not
the viewer.

## 5. Linux bundle (`LinuxNCentral`)

- `installNCentral.sh` installs WineHQ for apt/dnf systems only; Arch's own `wine`
  package works (11.x tested).
- Running the viewer as plain Wine windows under Wayland/XWayland gives off-screen
  popups, a jumping cursor and unclickable menus. A **Wine virtual desktop** fixes all of
  these (`HKCU\Software\Wine\Explorer\Desktop=Default`). Consider setting this in the
  bundle.
- Wine's native Wayland driver (Wine 11.17) was not usable: popup menus could not be
  clicked.
- `protocolRegister.sh` registers the link handlers; a launcher that also stops Wine when
  the session ends avoids leftover `wineserver` processes.

## Environment

| Item | Version |
|---|---|
| Viewer | N-able Integrated Viewer 7.44.08 (`MSPA4NCentralViewerInstall-Linux-7.44.08`) |
| OS | Arch Linux, Omarchy 4.5 |
| Compositor | Hyprland 0.56.2 (XWayland) |
| Wine | 11.20 (Arch `wine` package), 64-bit prefix |
