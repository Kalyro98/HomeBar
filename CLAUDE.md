# HomeBar — macOS Menüleisten-App

## Ziel
Native macOS-Menüleisten-App (kein eigenständiger Browser), die die **echte Home-Assistant-
Weboberfläche** (Dashboards + Einstellungen) in einem eingebetteten `WKWebView` anzeigt — so, als
würde man sich im Browser auf die HA-Instanz einloggen. Der Login erfolgt direkt auf der HA-Seite,
die Session bleibt erhalten. **Keine** nachgebauten Geräte-Controls.

Icon oben in der Menüleiste; **Klick** öffnet/schließt das Fenster, Klick daneben schließt es. Das Fenster
ist ein echtes, **in der Größe ziehbares** Fenster, dessen Größe und Position über jedes Öffnen
hinweg gemerkt werden. Verteilung als **DMG** (unsigniert, privat).

## Tech-Stack
- Swift 5 / SwiftUI (Views) + AppKit (Menüleiste & Fenster) + **WebKit (`WKWebView`)**
- macOS 14.0+, arm64 · Xcode 26.5
- Keine externen Abhängigkeiten (nur Apple-Frameworks)
- HA-Anzeige: WKWebView lädt die HA-URL; **persistenter Datenspeicher** (`WKWebsiteDataStore.default()`)
  → Login/Cookies bleiben über Neustarts erhalten. Kein Token, keine eigene API-Anbindung.

## Pfad
`/Users/dino/Desktop/Claude/Homelab/HomeBar`
- Xcode-Projekt: `HomeBar.xcodeproj`
- Quellen: `HomeBar/`
- DMG-Build: `scripts/build-dmg.sh` → Ausgabe in `dist/HomeBar.dmg`
  (gestyltes Fenster mit Hintergrund `scripts/dmg-background.png`, Icon-Positionen, Applications-Symlink)

## Dateien (Quellen)
- `HomeBarApp.swift` — @main, reine Menüleisten-App (Settings-Scene leer)
- `AppDelegate.swift` — NSStatusItem (Klick öffnet/schließt), Rechtsklick-Menü, Klick-außerhalb-Monitor,
  globaler Shortcut, Notifier-Start
- `PanelController.swift` — resizable NSPanel, Positionierung, Frame-Persistenz, `activate()`
- `ViewModels/AppSettings.swift` — lokale URL + Remote-Domain (UserDefaults), primary/fallback
- `Views/WebView.swift` — `WebController` (WKWebView + Navigation/Fallback) + `WebViewRepresentable`
- `Views/PanelView.swift` — Toolbar (zurück/home/reload/einstellungen) + WebView
- `Views/SettingsView.swift` — URL-Eingabefelder, Verbindungs-Häkchen, Autostart-Schalter
- `Helpers/LaunchAtLogin.swift` — Autostart via SMAppService
- `Helpers/GlobalHotKey.swift` — globaler Shortcut via Carbon `RegisterEventHotKey` (⌘⇧H)
- `Services/HANotifier.swift` — HA-WebSocket nur für Benachrichtigungen (Token, get_states,
  subscribe state_changed → `UNUserNotificationCenter`)
- `Services/KeychainStore.swift` — Token-Speicher (Keychain, Service `ch.kalyro.HomeBar`)
- `Info.plist` (Projekt-Root, **nicht** im Sync-Ordner) — manuelle Info.plist mit `LSUIElement`,
  `NSAppTransportSecurity → NSAllowsArbitraryLoads`, `NSLocalNetworkUsageDescription`
- `Assets.xcassets/AppIcon.appiconset` — App-Icon (alle macOS-Größen, aus `~/Downloads/HomeAssistantBar.png (Originalname)`
  freigestellt; Quell-/Generierungsskripte lagen in `/tmp/icon_prep.py` + `/tmp/icon_gen.py`)

## Aktueller Stand
v0.10 — eingebettete HA-Weboberfläche; aktive Adresse mit grünem Häkchen; Autostart; App-Icon;
Rechtsklick-Menü; Lokalisierung EN/DE. **0.7:** globaler Shortcut, self-signed-Zertifikate für
konfigurierte Hosts + ATS-Ausnahme (lokale HA über http/https), native Benachrichtigungen für
ausgewählte Entitäten (HA-WebSocket mit Token). **0.8:** Shortcut frei konfigurierbar. **0.9:** Hover entfernt (nur Klick). **Neu in 0.10:** Vollbildmodus (Schalter „Im Vollbild öffnen" + Shortcut ⌘⇧F).
Debug- und Release-Build grün, DMG baut.
Implementiert:
- Menüleisten-Icon: Klick öffnet/schließt das Fenster, Klick daneben schließt
- Resizable NSPanel mit Frame-Persistenz (Größe **und** Position in UserDefaults `panelFrame`)
- WKWebView lädt HA-Oberfläche, Lokal→Remote-Fallback bei Ladefehler, persistenter Login
- Toolbar: Zurück, Startseite, Neu laden, Einstellungen
- Einstellungen: frei eingebbare lokale URL/IP + Remote-Domain

Nächste mögliche Schritte: „Reachability"-Check vor dem Laden (statt erst bei Ladefehler
umzuschalten), optional Signierung/Notarisierung, GitHub-Release.

## Build & Run
- **In Xcode:** `HomeBar.xcodeproj` öffnen, Scheme „HomeBar", Run.
- **DMG bauen:** `./scripts/build-dmg.sh` → `dist/HomeBar.dmg`.
- **Installieren:** DMG mounten, App nach `/Applications` ziehen. Da **unsigniert**: Erststart per
  **Rechtsklick auf die App → „Öffnen"**.

## Einrichtung (Endnutzer)
1. App starten → Menüleisten-Icon → Zahnrad → lokale URL (z. B. `http://192.168.1.x:8123`) und/oder
   Remote-Domain eintragen → „Speichern & Laden".
2. Auf der geladenen HA-Seite normal einloggen — die Anmeldung bleibt gespeichert.

## Konventionen & Invarianten
- **Reine Menüleisten-App:** `LSUIElement = YES`, `setActivationPolicy(.accessory)` → kein Dock-Icon.
  Die UI hängt am `NSPanel` (AppDelegate/PanelController), **nicht** an einer SwiftUI-WindowGroup.
- **Öffnen/Aktivieren:** Klick aufs Icon (oder der Shortcut) öffnet das Fenster und aktiviert die App
  (`PanelController.show(activate: true)`); Klick ins Fenster ruft `activate()` → App wird key, damit
  Login/Texteingabe in der WebView funktionieren. `Panel.canBecomeKey` ist überschrieben.
  (Hover-zu-Öffnen wurde entfernt – auf macOS unzuverlässig und nicht HIG-konform.)
- **Schließen:** globaler `.mouseDown`-Monitor schließt bei Klick außerhalb von Fenster und Icon.
- **Frame-Persistenz:** `windowDidResize`/`windowDidMove` schreiben sofort `panelFrame`;
  `positionPanel` stellt ihn vor dem Anzeigen wieder her.
- **WebView-Login persistent:** `WKWebsiteDataStore.default()` (NICHT `.nonPersistent()`), sonst
  müsste man sich bei jedem Start neu einloggen.
- **URL-Fallback:** `WebController` lädt zuerst `primaryURLString` (lokal, sonst remote); bei
  `didFailProvisionalNavigation` einmalig auf `fallbackURLString` umschalten.
- **Signing:** ad-hoc (`CODE_SIGN_IDENTITY = "-"`), **Hardened Runtime AUS** — sonst lehnt `codesign`
  die `com.apple.provenance`-xattrs ab, die macOS auf dem Desktop-Pfad anhängt.
- **DMG-Build außerhalb des Projektordners:** `build-dmg.sh` baut nach `$TMPDIR` (provenance-frei),
  sonst schlägt der Release-CodeSign fehl. Nicht auf einen Pfad unter `~/Desktop` ändern.
- **Gestyltes DMG via `dmgbuild`:** `build-dmg.sh` nutzt **dmgbuild** (`scripts/dmg-settings.py`),
  das Hintergrund, Fenstergröße und Icon-Positionen **direkt in die `.DS_Store` schreibt** – ganz
  ohne Finder/AppleScript. Das ist zuverlässig und braucht keine Automations-Berechtigung (der frühere
  AppleScript-Weg griff in nicht-interaktiven Shells nicht). Installation: `python3 -m pip install
  --user dmgbuild`. Fehlt dmgbuild, baut das Skript ein einfaches, ungestyltes DMG via `hdiutil`.
  Layout-Werte (Icongröße 160, Fenster 640×440, Positionen) stehen in `scripts/dmg-settings.py`;
  das Hintergrundbild ist `scripts/dmg-background.png` (640×440).
- **Bekanntes Thema – DMG-Hintergrund:** Icongröße/Positionen/Fenster greifen zuverlässig, aber das
  **Hintergrundbild wird auf macOS 26 aktuell nicht gerendert** (Fenster bleibt dunkel) – sowohl über
  dmgbuild-Alias als auch über Finder/AppleScript. Vermutlich Alias-/Bookmark-Auflösung. Offen;
  mögliche Ansätze: TIFF-Hintergrund, pyobjc/Quartz, oder `backgroundColor` statt Bild. Layout selbst
  ist davon unberührt.
- **Versionsregel:** Bei jeder neuen Testversion `MARKETING_VERSION` **und** `CURRENT_PROJECT_VERSION`
  erhöhen. (Aktuell 0.10 / 10.)
- **Info.plist ist manuell** (`GENERATE_INFOPLIST_FILE = NO`, `INFOPLIST_FILE = Info.plist`). Liegt
  im **Projekt-Root**, damit die file-system-synchronized Group sie nicht doppelt als Ressource
  einbindet. ATS-Ausnahme nötig, sonst lädt die WebView keine lokalen http/self-signed-HA-Server.
- **Self-signed-Zerts:** `WebController` akzeptiert Server-Trust **nur** für Hosts aus
  `localURL`/`remoteURL` (siehe `isConfiguredHost`) – kein blindes Vertrauen für beliebige Seiten.
- **Benachrichtigungen:** `HANotifier` verbindet sobald ein Token gesetzt ist (auch um die
  Entitätenliste zu laden); Benachrichtigungen werden nur bei `notificationsEnabled` **und** für
  Entitäten in `watchedEntityIDs` gesendet, und nur bei echtem Zustandswechsel (Snapshot = Baseline,
  `unavailable`/`unknown` werden ignoriert). Token in der Keychain, nicht in UserDefaults.
- **Shortcuts:** `GlobalHotKey` (Carbon) braucht keine Bedienungshilfen-Berechtigung. **Zwei
  konfigurierbare** Shortcuts: Öffnen/Schließen (Standard ⌘⇧H) und Vollbild umschalten (Standard ⌘⇧F).
  keyCode/modifiers/Zeichen je in `AppSettings`, Aufnahme in `SettingsView` via
  `NSEvent.addLocalMonitorForEvents` (RecordTarget open/full), `HotKeyUtils` formatiert. `AppDelegate`
  registriert beide per `registerHotKeys()` neu bei Änderung (Combine-Observation über alle 4 Werte).
- **Vollbild:** `PanelController.setFullScreen` füllt `screen.frame` (über der Menüleiste,
  `level = .mainMenu+1`), merkt den vorherigen Frame und stellt ihn beim Verlassen wieder her.
  **Esc** verlässt Vollbild (`Panel.escapeHandler`). Im Vollbild wird der Frame NICHT persistiert.
  `openInFullScreen` öffnet direkt im Vollbild; Menüeintrag „Vollbild umschalten".
- **App-Icon:** Asset-Katalog `Assets.xcassets`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. Das
  Menüleisten-Icon bleibt bewusst das SF-Symbol `house.fill` (Template, klein) — das App-Icon
  erscheint in Finder/DMG/Anmeldeobjekten, nicht in der Menüleiste (Accessory-App ohne Dock-Icon).
- **Autostart:** `LaunchAtLogin` nutzt `SMAppService.mainApp` (kein Helfer-Bundle). Zuverlässig nur
  für die in `/Applications` installierte Kopie an stabilem Pfad; aus DerivedData/Desktop heraus kann
  die Registrierung den falschen Pfad eintragen.
- **Lokalisierung:** Basissprache **Englisch** (Quell-Strings im Code sind Englisch),
  Übersetzungen in `HomeBar/Localizable.xcstrings` (+ `InfoPlist.xcstrings` für die
  Netzwerk-Berechtigung). macOS wählt automatisch nach Systemsprache. **Neue user-facing Strings:
  englisches Literal im Code + deutschen Eintrag in den `.xcstrings` ergänzen.** SwiftUI-`Text`/
  `Button`/`TextField` lokalisieren String-**Literale** automatisch (LocalizedStringKey); für
  String-**Variablen** den `LocalizedStringKey`-Typ verwenden, sonst wird nicht übersetzt. AppKit
  (NSMenu) nutzt `String(localized:)`. Code-Kommentare können Deutsch bleiben.
- **Rechtsklick-Menü:** Rechts-/Control-Klick auf das Status-Item öffnet ein NSMenu
  (Öffnen/Beenden) via `menu.popUp(...)`; Linksklick öffnet/schließt das Fenster. Unterscheidung über
  `NSApp.currentEvent?.type`.
