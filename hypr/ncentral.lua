-- N-central Take Control viewer under Wine (Hyprland Lua config, as used by Omarchy 4.5+).
-- Load it from ~/.config/hypr/hyprland.lua with:  require("hypr.ncentral")
--
-- The Wine virtual desktop is one X11 window, class "explorer.exe", title "Wine Desktop".

local wine_desktop = { class = "^explorer\\.exe$", title = "^Wine Desktop$" }

-- Float rule of its own: keeps Omarchy's floating-workspace mode from shrinking it, and
-- opens it fullscreen on the monitor it starts on (SUPER+F toggles). ncentral-resize-sync
-- then keeps the Wine desktop the size of the window in any layout.
o.window(wine_desktop, { float = true })
o.window(wine_desktop, { fullscreen = true })

-- Remote screens should not be see-through.
o.window(wine_desktop, { tag = "-default-opacity", opacity = "1 1" })

-- Wine asks to leave fullscreen whenever it resizes its desktop to anything but the X
-- primary screen size. Ignore its own fullscreen/maximize requests.
o.window(wine_desktop, { suppress_event = "fullscreen maximize" })
