import SwiftUI

/// Hauptinhalt des Menüleisten-Fensters: zeigt die echte Home-Assistant-Weboberfläche
/// (Dashboards, Einstellungen) in einem WKWebView. Schmale Toolbar für Navigation.
struct PanelView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var web: WebController
    @State private var showSettings = false

    init(settings: AppSettings) {
        self.settings = settings
        _web = StateObject(wrappedValue: WebController(settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 320, minHeight: 360)
    }

    @ViewBuilder
    private var content: some View {
        if showSettings {
            SettingsView(settings: settings, web: web) {
                showSettings = false
                web.loadPrimary()
            }
        } else if !settings.isConfigured {
            notConfiguredHint
        } else {
            ZStack(alignment: .top) {
                WebViewRepresentable(webView: web.webView)
                if web.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(6)
                }
                if let error = web.errorText {
                    errorHint(error)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { web.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!web.canGoBack)
            Button { web.goHome() } label: { Image(systemName: "house") }
            Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }

            Spacer()

            Text("Home Assistant").font(.headline)

            Spacer()

            Button { showSettings.toggle() } label: {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .help("Settings")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var notConfiguredHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "gearshape.fill").font(.largeTitle).foregroundStyle(.tint)
            Text("Not set up yet").font(.headline)
            Text("Enter your Home Assistant URL in the settings.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorHint(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(.title).foregroundStyle(.orange)
            Text("Connection failed").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Try Again") { web.loadPrimary() }
                Button("Settings") { showSettings = true }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
