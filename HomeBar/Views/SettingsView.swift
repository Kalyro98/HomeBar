import SwiftUI

/// Einstellungen: frei eingebbare lokale URL und Remote-Domain der HA-Instanz.
/// Zeigt mit einem grünen Häkchen, welche Adresse gerade aktiv verbunden ist.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var web: WebController
    /// Wird beim Speichern aufgerufen (schließt die Einstellungen und lädt neu).
    var onApply: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Verbindung")
                    .font(.title3.weight(.semibold))

                field("Lokale URL/IP", text: $settings.localURL,
                      placeholder: "http://192.168.1.x:8123",
                      hint: "Wird zuhause bevorzugt verwendet.",
                      status: status(for: .local))
                field("Remote-Domain", text: $settings.remoteURL,
                      placeholder: "https://ha.deine-domain.tld",
                      hint: "Fallback, wenn die lokale Adresse nicht erreichbar ist.",
                      status: status(for: .remote))

                Text("Du loggst dich direkt auf der Home-Assistant-Seite ein – die Anmeldung bleibt gespeichert.")
                    .font(.caption).foregroundStyle(.secondary)

                Button("Speichern & Laden") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settings.isConfigured)
                    .padding(.top, 4)

                Divider().padding(.vertical, 4)

                Text("Allgemein")
                    .font(.title3.weight(.semibold))
                Toggle("Bei Anmeldung automatisch starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        // Realen Status zurücklesen (falls Registrierung fehlschlägt).
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Status pro Feld

    private enum FieldStatus { case none, connecting, connected }

    private func status(for which: WebController.Active) -> FieldStatus {
        guard web.active == which else { return .none }
        return web.connected ? .connected : .connecting
    }

    private func field(_ label: String, text: Binding<String>,
                       placeholder: String, hint: String, status: FieldStatus) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                statusBadge(status)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Text(hint).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: FieldStatus) -> some View {
        switch status {
        case .connected:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("verbunden").font(.caption).foregroundStyle(.green)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                Text("verbinde…").font(.caption).foregroundStyle(.secondary)
            }
        case .none:
            EmptyView()
        }
    }
}
