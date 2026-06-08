import Foundation
import Combine

/// Benutzer-Einstellungen: frei eingebbare lokale URL und Remote-Domain der HA-Instanz.
/// Es wird die echte HA-Weboberfläche geladen; der Login erfolgt dort (Session/Cookies
/// bleiben über den persistenten WKWebView-Datenspeicher erhalten) – daher kein Token nötig.
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var localURL: String {
        didSet { defaults.set(localURL, forKey: Keys.localURL) }
    }
    @Published var remoteURL: String {
        didSet { defaults.set(remoteURL, forKey: Keys.remoteURL) }
    }

    init() {
        self.localURL = defaults.string(forKey: Keys.localURL) ?? ""
        self.remoteURL = defaults.string(forKey: Keys.remoteURL) ?? ""
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
    }
}
