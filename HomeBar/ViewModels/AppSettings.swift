import Foundation
import Combine

/// Benutzer-Einstellungen: lokale URL/Remote-Domain (für die WebView) sowie – optional –
/// ein Access Token und eine Auswahl von Entitäten für native Benachrichtigungen.
/// Die WebView-Anmeldung läuft über Cookies; das Token wird NUR für Benachrichtigungen
/// (HA-WebSocket) gebraucht und liegt in der Keychain.
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var localURL: String {
        didSet { defaults.set(localURL, forKey: Keys.localURL) }
    }
    @Published var remoteURL: String {
        didSet { defaults.set(remoteURL, forKey: Keys.remoteURL) }
    }

    /// Long-Lived Access Token (Keychain, nicht UserDefaults).
    @Published var token: String {
        didSet {
            if token.isEmpty { KeychainStore.deleteToken() }
            else { KeychainStore.saveToken(token) }
        }
    }
    /// Benachrichtigungen aktiv?
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    /// Entitäten, die für Benachrichtigungen überwacht werden.
    @Published var watchedEntityIDs: Set<String> {
        didSet { defaults.set(Array(watchedEntityIDs), forKey: Keys.watched) }
    }

    // Globaler Shortcut (Carbon keyCode + modifiers + Anzeige-Zeichen).
    @Published var hotKeyKeyCode: Int {
        didSet { defaults.set(hotKeyKeyCode, forKey: Keys.hkCode) }
    }
    @Published var hotKeyModifiers: Int {
        didSet { defaults.set(hotKeyModifiers, forKey: Keys.hkMods) }
    }
    @Published var hotKeyChar: String {
        didSet { defaults.set(hotKeyChar, forKey: Keys.hkChar) }
    }

    // Fenster im Vollbild öffnen?
    @Published var openInFullScreen: Bool {
        didSet { defaults.set(openInFullScreen, forKey: Keys.fullOnOpen) }
    }
    // Vollbild-Shortcut (Carbon keyCode + modifiers + Anzeige-Zeichen).
    @Published var fullKeyCode: Int {
        didSet { defaults.set(fullKeyCode, forKey: Keys.fullCode) }
    }
    @Published var fullModifiers: Int {
        didSet { defaults.set(fullModifiers, forKey: Keys.fullMods) }
    }
    @Published var fullChar: String {
        didSet { defaults.set(fullChar, forKey: Keys.fullChar) }
    }

    init() {
        self.localURL = defaults.string(forKey: Keys.localURL) ?? ""
        self.remoteURL = defaults.string(forKey: Keys.remoteURL) ?? ""
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.watchedEntityIDs = Set(defaults.stringArray(forKey: Keys.watched) ?? [])
        let hasHK = defaults.object(forKey: Keys.hkCode) != nil
        self.hotKeyKeyCode = hasHK ? defaults.integer(forKey: Keys.hkCode) : HotKeyUtils.defaultKeyCode
        self.hotKeyModifiers = hasHK ? defaults.integer(forKey: Keys.hkMods) : HotKeyUtils.defaultModifiers
        self.hotKeyChar = defaults.string(forKey: Keys.hkChar) ?? HotKeyUtils.defaultChar
        self.openInFullScreen = defaults.bool(forKey: Keys.fullOnOpen)
        let hasFull = defaults.object(forKey: Keys.fullCode) != nil
        self.fullKeyCode = hasFull ? defaults.integer(forKey: Keys.fullCode) : HotKeyUtils.fullDefaultKeyCode
        self.fullModifiers = hasFull ? defaults.integer(forKey: Keys.fullMods) : HotKeyUtils.fullDefaultModifiers
        self.fullChar = defaults.string(forKey: Keys.fullChar) ?? HotKeyUtils.fullDefaultChar
        self.token = KeychainStore.loadToken() ?? ""
    }

    var hotKeyDisplay: String {
        HotKeyUtils.display(char: hotKeyChar, carbonModifiers: hotKeyModifiers)
    }

    var fullHotKeyDisplay: String {
        HotKeyUtils.display(char: fullChar, carbonModifiers: fullModifiers)
    }

    var isConfigured: Bool {
        !localURL.isEmpty || !remoteURL.isEmpty
    }

    /// Bevorzugte Start-URL: lokal, falls gesetzt, sonst remote.
    var primaryURLString: String {
        localURL.isEmpty ? remoteURL : localURL
    }

    /// Fallback-URL (die jeweils andere), falls die primäre nicht erreichbar ist.
    var fallbackURLString: String? {
        let other = localURL.isEmpty ? "" : remoteURL
        return other.isEmpty ? nil : other
    }

    private enum Keys {
        static let localURL = "localURL"
        static let remoteURL = "remoteURL"
        static let notificationsEnabled = "notificationsEnabled"
        static let watched = "watchedEntityIDs"
        static let hkCode = "hotKeyKeyCode"
        static let hkMods = "hotKeyModifiers"
        static let hkChar = "hotKeyChar"
        static let fullOnOpen = "openInFullScreen"
        static let fullCode = "fullKeyCode"
        static let fullMods = "fullModifiers"
        static let fullChar = "fullChar"
    }
}
