#!/bin/bash
# Remove the Take Control Linux fixes. Leaves the Wine prefix and the N-able viewer
# itself in place (remove those with N-able's uninstaller or by deleting the prefix).

set -u
bin="$HOME/.local/bin"
apps="$HOME/.local/share/applications"

rm -f "$bin"/ncentral-{viewer,clipboard-bridge,resize-sync}
rm -rf "$HOME/.local/share/ncentral-viewer"
rm -f "$apps"/{mspancsxvp,tcancvp}.desktop
update-desktop-database "$apps" 2>/dev/null || true

hypr="$HOME/.config/hypr"
if [[ -f $hypr/ncentral.lua ]]; then
  rm -f "$hypr/ncentral.lua"
  sed -i '/^-- N-central Take Control viewer (Wine Desktop)$/d; /^require("hypr.ncentral")$/d' "$hypr/hyprland.lua"
  hyprctl reload >/dev/null 2>&1 || true
fi
echo "Removed. The Wine prefix and viewer were left in place."
