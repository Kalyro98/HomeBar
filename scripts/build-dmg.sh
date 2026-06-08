#!/bin/bash
# Baut HomeBar (Release) und packt es als gestyltes DMG mit Hintergrundbild,
# Icon-Positionen und Applications-Symlink (Drag-to-Install).
# Unsigniert / ad-hoc – für den persönlichen Gebrauch. Benötigt nur Xcode + hdiutil + Finder.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="HomeBar"
SCHEME="HomeBar"
VOL_NAME="HomeBar"
BG_IMAGE="$PROJECT_DIR/scripts/dmg-background.png"
# Build außerhalb des Projektordners (unter $TMPDIR), sonst hängt macOS auf dem
# Desktop com.apple.provenance-xattrs an, an denen codesign scheitert.
BUILD_DIR="${TMPDIR:-/tmp}/HomeBar-build"
PRODUCTS_DIR="$BUILD_DIR/Build/Products/Release"
DMG_STAGE="$BUILD_DIR/dmg"
RW_DMG="$BUILD_DIR/${APP_NAME}-rw.dmg"
DIST_DIR="$PROJECT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

echo "==> Release-Build…"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  clean build | tail -3

APP_PATH="$PRODUCTS_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "FEHLER: $APP_PATH nicht gefunden"; exit 1
fi

echo "==> DMG-Inhalt vorbereiten…"
rm -rf "$DMG_STAGE"; mkdir -p "$DMG_STAGE/.background"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
[ -f "$BG_IMAGE" ] && cp "$BG_IMAGE" "$DMG_STAGE/.background/dmg-background.png"

echo "==> Beschreibbares DMG erstellen…"
rm -f "$RW_DMG"
SIZE_MB=$(( $(du -sm "$DMG_STAGE" | cut -f1) + 30 ))
hdiutil create -ov -srcfolder "$DMG_STAGE" -volname "$VOL_NAME" \
  -fs HFS+ -format UDRW -size "${SIZE_MB}m" "$RW_DMG" >/dev/null

echo "==> Mounten & Layout setzen…"
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | egrep '^/dev/' | head -1 | awk '{print $1}')
MOUNT="/Volumes/$VOL_NAME"
sleep 1

# Fenster-Layout per Finder/AppleScript (Best-Effort – braucht Automations-Berechtigung).
if [ -f "$DMG_STAGE/.background/dmg-background.png" ]; then
osascript <<OSA || echo "   (Hinweis: Finder-Styling übersprungen – DMG wird trotzdem erstellt)"
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 560}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 160
    set text size of vo to 13
    set background picture of vo to file ".background:dmg-background.png"
    set position of item "$APP_NAME.app" of container window to {165, 200}
    set position of item "Applications" of container window to {475, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
fi

sync; sleep 1
hdiutil detach "$DEV" >/dev/null || hdiutil detach "$DEV" -force >/dev/null

echo "==> Komprimieren…"
mkdir -p "$DIST_DIR"; rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"

echo "==> Fertig: $DMG_PATH"
echo "Hinweis: App ist unsigniert. Erststart per Rechtsklick auf die App -> 'Öffnen'."
