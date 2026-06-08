import SwiftUI

/// Settings: freely editable local URL and remote domain of the HA instance.
/// A green checkmark shows which address is currently connected.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var web: WebController
    /// Called on save (closes settings and reloads).
    var onApply: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connection")
                    .font(.title3.weight(.semibold))

                field("Local URL/IP", text: $settings.localURL,
                      placeholder: "http://192.168.1.x:8123",
                      hint: "Preferred when you're at home.",
                      status: status(for: .local))
                field("Remote domain", text: $settings.remoteURL,
                      placeholder: "https://ha.your-domain.tld",
                      hint: "Fallback when the local address isn't reachable.",
                      status: status(for: .remote))

                Text("You sign in directly on the Home Assistant page – your login is remembered.")
                    .font(.caption).foregroundStyle(.secondary)

                Button("Save & Load") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settings.isConfigured)
                    .padding(.top, 4)

                Divider().padding(.vertical, 4)

                Text("General")
                    .font(.title3.weight(.semibold))
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        // Read back the real status (in case registration failed).
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Status per field

    private enum FieldStatus { case none, connecting, connected }

    private func status(for which: WebController.Active) -> FieldStatus {
        guard web.active == which else { return .none }
        return web.connected ? .connected : .connecting
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>,
                       placeholder: LocalizedStringKey, hint: LocalizedStringKey,
                       status: FieldStatus) -> some View {
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
                Text("connected").font(.caption).foregroundStyle(.green)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                Text("connecting…").font(.caption).foregroundStyle(.secondary)
            }
        case .none:
            EmptyView()
        }
    }
}
