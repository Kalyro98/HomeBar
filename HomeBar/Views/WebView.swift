import SwiftUI
import WebKit

/// Hält den WKWebView und steuert das Laden der HA-Oberfläche.
/// Lädt zuerst die primäre URL (lokal), fällt bei Fehler auf die Remote-URL zurück.
/// Login/Session bleiben durch den persistenten Standard-Datenspeicher erhalten.
@MainActor
final class WebController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    private let settings: AppSettings

    /// Welche der beiden konfigurierten Adressen gerade verwendet wird.
    enum Active { case none, local, remote }

    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var errorText: String?
    /// Aktuell verwendete Adresse (lokal/remote) – für die Anzeige in den Einstellungen.
    @Published var active: Active = .none
    /// true, sobald eine Seite erfolgreich geladen wurde.
    @Published var connected = false

    private var activeBase: String = ""
    private var triedFallback = false

    init(settings: AppSettings) {
        self.settings = settings

        let config = WKWebViewConfiguration()
        // Persistenter Datenspeicher -> Cookies/Login bleiben über Neustarts erhalten.
        config.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")  // nahtloser Hintergrund

        loadPrimary()
    }

    // MARK: - Laden

    func loadPrimary() {
        triedFallback = false
        errorText = nil
        connected = false
        guard settings.isConfigured else { active = .none; return }
        activeBase = settings.primaryURLString
        // Primäre Adresse ist lokal, falls eine lokale URL gesetzt ist, sonst remote.
        active = settings.localURL.isEmpty ? .remote : .local
        if let url = Self.normalizedURL(from: activeBase) {
            webView.load(URLRequest(url: url))
        }
    }

    func reload() {
        if webView.url != nil {
            webView.reload()
        } else {
            loadPrimary()
        }
    }

    /// Zurück zur Startseite der aktuellen Instanz.
    func goHome() {
        if let url = Self.normalizedURL(from: activeBase, path: "/") {
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    private func loadFallback() {
        guard !triedFallback, let fb = settings.fallbackURLString,
              let url = Self.normalizedURL(from: fb) else { return }
        triedFallback = true
        activeBase = fb
        active = .remote   // Fallback ist immer die Remote-Domain.
        connected = false
        errorText = nil
        webView.load(URLRequest(url: url))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorText = nil
        connected = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        connected = true
        canGoBack = webView.canGoBack
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        // Erst lokale, dann Remote-URL versuchen.
        if !triedFallback && settings.fallbackURLString != nil {
            loadFallback()
        } else {
            errorText = error.localizedDescription
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        errorText = error.localizedDescription
    }

    /// Akzeptiert self-signed-Zertifikate – aber NUR für die in den Einstellungen
    /// konfigurierten Hosts (lokale HA-Instanzen mit eigenem Zertifikat).
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              isConfiguredHost(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func isConfiguredHost(_ host: String) -> Bool {
        for s in [settings.localURL, settings.remoteURL] where !s.isEmpty {
            if let h = Self.normalizedURL(from: s)?.host,
               h.caseInsensitiveCompare(host) == .orderedSame {
                return true
            }
        }
        return false
    }

    // MARK: - Helfer

    static func normalizedURL(from base: String, path: String? = nil) -> URL? {
        var str = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        if !str.contains("://") { str = "http://" + str }
        guard var comps = URLComponents(string: str) else { return nil }
        if let path { comps.path = path }
        return comps.url
    }
}

/// Bettet den WKWebView in SwiftUI ein.
struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
