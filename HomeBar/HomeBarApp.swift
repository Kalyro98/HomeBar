import SwiftUI

/// Einstiegspunkt. Reine Menüleisten-App (LSUIElement) – kein Hauptfenster,
/// die gesamte UI läuft über das von AppDelegate verwaltete NSPanel.
@main
struct HomeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Leere Settings-Szene: App lebt ausschließlich in der Menüleiste.
        Settings {
            EmptyView()
        }
    }
}
