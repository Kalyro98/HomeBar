# dmgbuild-Konfiguration für das gestylte HomeBar-DMG.
# Schreibt Hintergrund, Fenstergröße und Icon-Positionen direkt in die .DS_Store
# (ohne Finder/AppleScript) – funktioniert daher auch ohne GUI-Berechtigung.
import os.path

app = defines.get("app", "HomeBar.app")
appname = os.path.basename(app)

# Format & Inhalt
format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}

# Optionales Volume-Icon (App-Icon)
volicon = defines.get("volicon")
if volicon:
    icon = volicon

# Fenster & Darstellung
background = defines.get("background", "dmg-background.png")
window_rect = ((200, 120), (640, 440))   # ((x, y), (Breite, Höhe))
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_offset = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 160
icon_locations = {
    appname: (165, 205),
    "Applications": (475, 205),
}
