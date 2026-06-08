#!/bin/bash
# Baut HomeBar (Release) und packt es als gestyltes DMG mit Hintergrundbild,
# großen Icons und Applications-Symlink (Drag-to-Install).
# Unsigniert / ad-hoc – für den persönlichen Gebrauch.
#
# Bevorzugt 'dmgbuild' (schreibt das Layout Finder-unabhängig direkt in die .DS_Store).
# Installation falls nötig:  python3 -m pip install --user dmgbuild
# Ohne dmgbuild entsteht ein funktionierendes, aber ungestyltes DMG.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="HomeBar"
SCHEME="HomeBar"
VOL_NAME="HomeBar"
BG_IMAGE="$PROJECT_DIR/scripts/dmg-background.png"
SETTINGS="$PROJECT_DIR/scripts/dmg-settings.py"
# Build außerhalb des Projektordners (unter $TMPDIR), sonst hängt macOS auf dem
# Desktop com.apple.provenance-xattrs an, an denen codesign scheitert.
BUILD_DIR="${TMPDIR:-/tmp}/HomeBar-build"
PRODUCTS_DIR="$BUILD_DIR/Build/Products/Release"
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

# Evtl. noch gemountetes altes Volume aushängen.
[ -d "/Volumes/$VOL_NAME" ] && hdiutil detach "/Volumes/$VOL_NAME" >/dev/null 2>&1 || true

mkdir -p "$DIST_DIR"; rm -f "$DMG_PATH"

if python3 -c "import dmgbuild" 2>/dev/null; then
  echo "==> Gestyltes DMG via dmgbuild…"
  VOLICON="$APP_PATH/Contents/Resources/AppIcon.icns"
  python3 -m dmgbuild \
    -s "$SETTINGS" \
    -D app="$APP_PATH" \
    -D background="$BG_IMAGE" \
    -D volicon="$VOLICON" \
    "$VOL_NAME" "$DMG_PATH"
else
  echo "==> dmgbuild nicht gefunden – einfaches DMG via hdiutil…"
  STAGE="$BUILD_DIR/dmg"; rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "$APP_PATH" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -ov -srcfolder "$STAGE" -volname "$VOL_NAME" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_PATH" >/dev/null
fi

echo "==> Fertig: $DMG_PATH"
echo "Hinweis: App ist unsigniert. Erststart per Rechtsklick auf die App -> 'Öffnen'."
