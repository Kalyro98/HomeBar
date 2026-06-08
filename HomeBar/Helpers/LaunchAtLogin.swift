import Foundation
import ServiceManagement

/// Autostart bei Anmeldung über SMAppService (macOS 13+).
/// Registriert die App selbst als Login-Item – kein separates Helfer-Bundle nötig.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("LaunchAtLogin: \(error.localizedDescription)")
        }
    }
}
