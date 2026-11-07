# N-able Take Control (N-central) on Linux — Wine + Hyprland

Make the N-central **Take Control viewer** usable on a Linux desktop running
**Hyprland** (tested on **Arch Linux / Omarchy 4.5**, Hyprland 0.56, Wine 11.20),
with:

- links from the N-central web console opening the viewer directly,
- **clipboard that just works both ways** (copy on Linux, paste on the remote, and back),
- a viewer that **fits its window** in tiling, scrolling and floating layouts, maximized
  or fullscreen, on any monitor size.

N-able ships a Windows viewer plus a small Linux bundle that installs it under Wine.
Out of the box on Hyprland that setup has broken menus and popups, no automatic
clipboard, and a remote screen that is cut off whenever the window is not exactly the
size Wine started with. This repo contains the fixes, and [a write-up for N-able](docs/VENDOR-NOTES.md)
of what the viewer could change so fewer workarounds are needed.

> This is an unofficial community project, not affiliated with or supported by N-able.
> It does not include the viewer: you download that from your own N-central server.

## Quick start

1. **Install the dependencies** (Arch / Omarchy):

   ```bash
   sudo pacman -S --needed wine socat jq wl-clipboard gcc libx11
   ```

2. **Download N-able's Linux viewer bundle for N-central** (`LinuxNCentral.zip`) from
   N-able's CDN. The version in the path should match your N-central's viewer version
   (tested with 7.44.08):

   ```bash
   curl -fLO https://swi-rc.cdn-sw.net/n-central/Linux_viewer/7.44.08/LinuxNCentral.zip
   unzip LinuxNCentral.zip
   ```

   It contains `MSPA4NCentralViewerInstall-Linux-<version>.exe` plus N-able's own
   install scripts. This repo's installer replaces those scripts.

3. **Install**:

   ```bash
   git clone https://github.com/Raynok/takecontrol-linux.git && cd takecontrol-linux
   ./install.sh ../LinuxNCentral/MSPA4NCentralViewerInstall-Linux-*.exe
   ```

   Already have the viewer in your Wine prefix? Run `./install.sh` without an argument.
   Use another prefix with `WINEPREFIX=/path ./install.sh ...`.

4. **Click Take Control** in N-central. The viewer opens fullscreen on the current
   monitor. `SUPER+F` toggles fullscreen; any layout or size works.

5. In the viewer's **⋮ menu > Preferences**, make sure
   **"Allow resize below the minimum threshold"** is ticked (the installer sets it when
   the settings file already exists). Without it the viewer will not shrink below about
   1216×750 and smaller windows cut it off.

Uninstall the fixes with `./uninstall.sh` (the Wine prefix and viewer are left alone).

## What gets installed

| Path | Purpose |
|---|---|
| `~/.local/bin/ncentral-viewer` | Link handler. Starts the viewer in a Wine virtual desktop, starts the two helpers, and stops Wine when you close the desktop window. |
| `~/.local/bin/ncentral-clipboard-bridge` | Two-way clipboard (see below). |
| `~/.local/bin/ncentral-resize-sync` | Keeps the Wine desktop and the viewer the size of the window. |
| `~/.local/share/ncentral-viewer/xclip-get` | Small X11 tool: reads the clipboard straight from Wine. Built from `src/xclip-get.c`. |
| `~/.local/share/ncentral-viewer/wineres.exe.so` | Small Wine tool: changes the virtual desktop size and refits the viewer. Built from `src/wineres.c` with `winegcc`. |
| `~/.local/share/applications/{mspancsxvp,tcancvp}.desktop` | Registers the `mspancsxvp://` and `tcancvp://` links N-central opens. |
| `~/.config/hypr/ncentral.lua` | Hyprland window rules (Lua config, Omarchy 4.5+). |
| Wine registry `HKCU\Software\Wine\Explorer` | Virtual desktop mode (`Desktop=Default`, `EnableShell=0`). |

## Problems and fixes

### 1. Menus, popups and the cursor misbehave
Running the viewer as normal Wine windows under Hyprland puts popups off-screen, makes
the cursor jump and leaves menus unclickable. **Fix:** run it in a **Wine virtual
desktop** (one X11 window, class `explorer.exe`, title `Wine Desktop`). Wine's native
Wayland driver was also tried (Wine 11.17) and still had unclickable popup menus.

### 2. Copying on Linux never reaches the remote
Hyprland only gives clipboard data to an XWayland app while an XWayland window has
keyboard focus (its log says `[xwm] Ignoring clipboard access: xwayland not in focus`).
The viewer reads the clipboard the moment it changes, which is while you are still in
the Linux app you copied from, so it gets nothing. Its log shows
`Clipboard data for this format not available`, then `Clipboard update ignored... Guard
interval not expired` for the retries. Pressing "send clipboard" by hand works, because
by then the viewer has focus.

**Fix:** `ncentral-clipboard-bridge` watches Hyprland's event socket. When the Wine
Desktop gains focus and the clipboard changed since it last had focus, it offers the
same text (or PNG) again. Now the viewer is focused, reads it and sends it on.

### 3. Copying on the remote never reaches Linux
Remote copies do land on Wine's clipboard, and Wine serves them to X11 clients
instantly, but Hyprland's XWayland-to-Wayland transfer from Wine stalls: `wl-paste`
hangs and Linux apps cannot paste.

**Fix:** when focus leaves the Wine Desktop and Wine owns the clipboard, the bridge reads
it directly over X11 (`xclip-get`) and puts it on the Wayland clipboard with `wl-copy`.
It remembers what it saw, so returning to the viewer does not echo it back.

### 4. The remote screen is cut off unless the window is exactly the starting size
A Wine virtual desktop has a fixed resolution. A smaller window clips it; Omarchy's
floating mode, for example, shrinks new windows to about 64% of the monitor. Wine never
resizes the desktop to its window, and `ChangeDisplaySettings` only accepts standard
modes plus the size in the registry's `Explorer\Desktops\Default`.

**Fix:** `ncentral-resize-sync` polls the window size. When it settles it writes that size
to the registry, then runs `wineres` to switch the desktop to it and resize the
maximized viewer in place. (The viewer is a Delphi app: its main form is an *owned*
window, and Wine leaves a maximized window at its old size after a resolution change.)

### 5. The viewer will not shrink below ~1216×750
**Fix:** the viewer's own option *Allow resize below the minimum threshold*
(`AllowRemoteDesktopFullResize=1` in `NCentralRDViewer.ini`).

### 6. Fullscreen drops when the desktop is resized
When Wine resizes its desktop to anything but the X primary screen size it asks the
window manager to leave fullscreen, so the window falls back to its smaller size.
**Fix:** a Hyprland rule ignores Wine's own fullscreen/maximize requests
(`suppress_event`), and `ncentral-resize-sync` puts back the fullscreen or maximized
state right after each resize as a backstop.

### 7. Omarchy floating mode and transparency
**Fix:** a float rule of its own keeps Omarchy's floating-workspace mode from claiming
the window, it opens fullscreen, and it is kept fully opaque.

## Tested

On Omarchy 4.5 / Hyprland 0.56.2 / Wine 11.20, viewer 7.44.08, laptop panel 1366×768
plus two 1920×1080 monitors. In each layout the Wine desktop matched the window and the
viewer filled it:

| Layout | Normal | Maximized | Fullscreen | Back to normal |
|---|---|---|---|---|
| Tiling | ✅ | ✅ | ✅ | ✅ |
| Scrolling | ✅ | – | ✅ | ✅ |
| Floating (default and manually resized) | ✅ | ✅ | ✅ | ✅ |

Clipboard: text both ways. Images are handled as PNG but were not tested.

## Other setups

- **Hyprland with a classic `hyprland.conf`:** the helpers work the same; add rules
  equivalent to [`hypr/ncentral.lua`](hypr/ncentral.lua) for class `^(explorer\.exe)$`,
  title `^(Wine Desktop)$`: float, fullscreen, opacity 1, and `suppressevent fullscreen
  maximize`. The exact syntax depends on your Hyprland version (untested).
- **Other compositors:** the helpers use `hyprctl` and Hyprland's event socket. The
  clipboard problems are specific to Hyprland's XWayland bridge; the resize approach
  (registry size + `wineres`) works anywhere Wine runs and could be driven by another
  compositor's IPC.

## Troubleshooting

- **Viewer logs:** `$WINEPREFIX/drive_c/users/$USER/AppData/Local/MSP Anywhere for N-central/Viewer/Logs/`
  (`NCentralRDViewer_*.log` shows clipboard activity).
- **Desktop size:** `WINEDEBUG=-all wine ~/.local/share/ncentral-viewer/wineres.exe.so`
  prints the current Wine desktop size and the viewer's windows.
- **Clipboard owner:** `~/.local/share/ncentral-viewer/xclip-get --foreign && echo "Wine owns it"`.
- **Lone Alt tap** puts the Windows window into menu mode (Space then opens the system
  menu); press Esc or Alt.
- **Ctrl+Alt+Delete** is taken by the desktop (Omarchy closes all windows). Use the
  viewer's *Send CTRL+ALT+DEL* (Shift+Ctrl+Del).
- Closing the **Wine Desktop** window ends all Wine processes in the prefix, including
  any running session.

## Credits

- N-able for the Windows viewer and its Linux/Wine bundle.
- [NAble-TuxControl](https://github.com/DW-CPC/NAble-TuxControl), an earlier community
  project (GUI/CLI around N-able's Linux bundles), where the `LinuxNCentral.zip`
  download location comes from.

## License

MIT (see [LICENSE](LICENSE)) for the scripts and tools in this repository. The Take
Control viewer is N-able's software and is not included.
