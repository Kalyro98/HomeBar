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

    init() {
        self.localURL = defaults.string(forKey: Keys.localURL) ?? ""
        self.remoteURL = defaults.string(forKey: Keys.remoteURL) ?? ""
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.watchedEntityIDs = Set(defaults.stringArray(forKey: Keys.watched) ?? [])
        self.token = KeychainStore.loadToken() ?? ""
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
    }
}
