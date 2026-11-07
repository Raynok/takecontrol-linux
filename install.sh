#!/bin/bash
# Install the N-central Take Control viewer fixes for Linux (Wine + Hyprland).
#
#   ./install.sh [path/to/MSPA4NCentralViewerInstall*.exe]
#
# With an installer path, the N-able viewer is installed into the Wine prefix first
# (silently). Without one, an existing viewer install is expected. Safe to re-run.
#
# Environment: WINEPREFIX (default ~/.wine).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
export WINEDEBUG=-all
bin="$HOME/.local/bin"
share="$HOME/.local/share/ncentral-viewer"
apps="$HOME/.local/share/applications"
viewer_dir="$WINEPREFIX/drive_c/users/$USER/AppData/Local/MSP Anywhere for N-central/Viewer"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Requirements -----------------------------------------------------------------
missing=()
for cmd in wine wineserver winegcc gcc socat jq wl-copy wl-paste hyprctl flock xdg-mime; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
[[ -f /usr/include/X11/Xlib.h ]] || missing+=("X11 headers (libx11)")
if (( ${#missing[@]} )); then
  die "missing: ${missing[*]}
  Arch/Omarchy: sudo pacman -S --needed wine socat jq wl-clipboard gcc libx11"
fi
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] ||
  say "Not inside a Hyprland session: installing anyway, but the helpers need Hyprland."

# --- Viewer -------------------------------------------------------------------------
if [[ $# -ge 1 ]]; then
  [[ -f $1 ]] || die "installer not found: $1"
  say "Installing the N-able viewer into $WINEPREFIX (silent)"
  (cd "$HOME" && wine "$(realpath "$1")" /S) || die "viewer installer failed"
  wineserver -w
fi
[[ -f $viewer_dir/NCentralRDLdr.exe ]] ||
  die "viewer not installed in $WINEPREFIX. Re-run with the MSPA4NCentralViewerInstall*.exe path."

# --- Wine settings ------------------------------------------------------------------
# Virtual desktop mode is required: without it popups open off-screen, the cursor
# bounces and menus cannot be clicked under Hyprland.
say "Configuring the Wine virtual desktop"
wine reg add 'HKCU\Software\Wine\Explorer' /v Desktop /d Default /f >/dev/null
wine reg add 'HKCU\Software\Wine\Explorer\Desktops' /v Default /d 1920x1080 /f >/dev/null
wine reg add 'HKCU\Software\Wine\Explorer\Desktops\Default' /v EnableShell /t REG_DWORD /d 0 /f >/dev/null
wineserver -w

# --- Viewer setting: allow resizing below its ~1216x750 minimum ----------------------
ini="$viewer_dir/NCentralRDViewer.ini"
if [[ -f $ini ]] && ! grep -q '^AllowRemoteDesktopFullResize=1' "$ini"; then
  say "Enabling 'Allow resize below the minimum threshold' in the viewer"
  if grep -q '^AllowRemoteDesktopFullResize=' "$ini"; then
    sed -i 's/^AllowRemoteDesktopFullResize=.*/AllowRemoteDesktopFullResize=1\r/' "$ini"
  elif grep -q '^\[Settings\]' "$ini"; then
    sed -i 's/^\[Settings\]\r\?$/&\nAllowRemoteDesktopFullResize=1\r/' "$ini"
  else
    printf '[Settings]\r\nAllowRemoteDesktopFullResize=1\r\n' >>"$ini"
  fi
elif [[ ! -f $ini ]]; then
  say "Viewer settings file not created yet: after the first session, enable"
  say "  Preferences (⋮ menu) > 'Allow resize below the minimum threshold'"
fi

# --- Helpers --------------------------------------------------------------------------
say "Building helper tools into $share"
mkdir -p "$share" "$bin" "$apps"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gcc -O2 -Wall -o "$tmp/xclip-get" "$here/src/xclip-get.c" -lX11
(cd "$tmp" && winegcc -m64 -mconsole -o wineres.exe "$here/src/wineres.c" >/dev/null)
# Replace by rename, so running copies keep working.
for f in xclip-get wineres.exe wineres.exe.so; do
  install -m 755 "$tmp/$f" "$share/.$f.new" && mv -f "$share/.$f.new" "$share/$f"
done
cp "$here/src/xclip-get.c" "$here/src/wineres.c" "$share/"

say "Installing scripts into $bin"
for f in ncentral-viewer ncentral-clipboard-bridge ncentral-resize-sync; do
  install -m 755 "$here/bin/$f" "$bin/.$f.new" && mv -f "$bin/.$f.new" "$bin/$f"
done

# --- Link handlers --------------------------------------------------------------------
say "Registering mspancsxvp:// and tcancvp:// links"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
for scheme in mspancsxvp tcancvp; do
  sed "s|@BIN@|$bin|; s|@SCHEME@|$scheme|g" "$here/applications/ncentral-viewer.desktop.in" >"$apps/$scheme.desktop"
  xdg-mime default "$scheme.desktop" "x-scheme-handler/$scheme"
done
update-desktop-database "$apps" 2>/dev/null || true

# --- Hyprland window rules ----------------------------------------------------------
hypr="$HOME/.config/hypr"
if [[ -f $hypr/hyprland.lua ]]; then
  say "Adding Hyprland window rules (hypr/ncentral.lua)"
  cp "$here/hypr/ncentral.lua" "$hypr/ncentral.lua"
  grep -q 'require("hypr.ncentral")' "$hypr/hyprland.lua" ||
    printf '\n-- N-central Take Control viewer (Wine Desktop)\nrequire("hypr.ncentral")\n' >>"$hypr/hyprland.lua"
  hyprctl reload >/dev/null 2>&1 || true
else
  say "No ~/.config/hypr/hyprland.lua (Lua config) found. Add the window rules from"
  say "  README.md (Hyprland rules) to your config by hand."
fi

say "Done. Click Take Control in N-central to start a session."
