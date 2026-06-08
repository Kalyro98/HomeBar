import SwiftUI

/// Settings: connection (local/remote URL), launch at login, and native notifications
/// for selected Home Assistant entities.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var web: WebController
    @ObservedObject var notifier: HANotifier
    /// Called on save (closes settings, reloads the web view and reconnects the notifier).
    var onApply: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var entitySearch = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                connectionSection
                Divider()
                generalSection
                Divider()
                notificationsSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection").font(.title3.weight(.semibold))

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
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General").font(.title3.weight(.semibold))
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.set(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
        }
    }

    // MARK: - Notifications

    private var filteredEntities: [HAEntityInfo] {
        guard !entitySearch.isEmpty else { return notifier.entities }
        return notifier.entities.filter {
            $0.name.localizedCaseInsensitiveContains(entitySearch) ||
            $0.id.localizedCaseInsensitiveContains(entitySearch)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications").font(.title3.weight(.semibold))

            Text("Access token (for notifications)")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("eyJ…", text: $settings.token)
                .textFieldStyle(.roundedBorder)
                .onSubmit { notifier.restart() }

            Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { _, on in
                    if on { HANotifier.requestAuthorization() }
                }
                .disabled(settings.token.isEmpty)

            if settings.token.isEmpty {
                Text("Enter an access token to load entities.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if notifier.entities.isEmpty {
                Text("Loading entities…").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Notify me about these entities:")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Search…", text: $entitySearch)
                    .textFieldStyle(.roundedBorder)
                ForEach(filteredEntities) { entity in
                    Toggle(isOn: Binding(
                        get: { settings.watchedEntityIDs.contains(entity.id) },
                        set: { on in
                            if on { settings.watchedEntityIDs.insert(entity.id) }
                            else { settings.watchedEntityIDs.remove(entity.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: entity.name).lineLimit(1)
                            Text(verbatim: entity.id)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
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
