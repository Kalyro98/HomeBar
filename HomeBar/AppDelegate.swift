import AppKit
import SwiftUI
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private let settings = AppSettings()
    private lazy var notifier = HANotifier(settings: settings)
    private var hotKey: GlobalHotKey?
    private var cancellables = Set<AnyCancellable>()

    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Status-Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "Home Assistant")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Fenster mit der HA-Weboberfläche
        panelController = PanelController(rootView: PanelView(settings: settings, notifier: notifier))
        panelController.onUserInteraction = { [weak self] in
            // Klick ins Fenster -> App aktivieren, damit Login/Eingabe funktioniert.
            self?.panelController.activate()
        }

        // Konfigurierbarer globaler Shortcut – initial registrieren und bei Änderung neu setzen.
        registerHotKey()
        settings.$hotKeyKeyCode.combineLatest(settings.$hotKeyModifiers)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerHotKey() }
            .store(in: &cancellables)

        // Benachrichtigungen: Berechtigung anfragen (falls aktiviert) und Notifier starten.
        if settings.notificationsEnabled {
            HANotifier.requestAuthorization()
        }
        notifier.start()
    }

    private func registerHotKey() {
        hotKey = GlobalHotKey(keyCode: UInt32(settings.hotKeyKeyCode),
                              modifiers: UInt32(settings.hotKeyModifiers)) { [weak self] in
            self?.togglePanel()
        }
    }

    // MARK: - Klick aufs Status-Item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if isRightClick {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panelController.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    /// Rechtsklick-/Control-Klick-Menü auf dem Menüleisten-Symbol.
    private func showContextMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: String(localized: "Open HomeBar"),
                              action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "Quit HomeBar"),
                              action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        }
    }

    @objc private func openFromMenu() { showPanel() }

    @objc private func quitApp() { NSApp.terminate(nil) }

    // MARK: - Anzeigen / Verstecken

    private func showPanel() {
        guard let button = statusItem.button else { return }
        panelController.show(relativeTo: button, activate: true)
        startClickMonitor()
    }

    private func hidePanel() {
        panelController.hide()
        stopClickMonitor()
    }

    // Klick außerhalb des Fensters/Symbols schließt das Fenster.
    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if !self.panelController.mouseIsOver() && !self.mouseOverButton() {
                self.hidePanel()
            }
        }
    }

    private func stopClickMonitor() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func mouseOverButton() -> Bool {
        guard let button = statusItem.button, let win = button.window else { return false }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = win.convertToScreen(inWindow)
        return onScreen.contains(NSEvent.mouseLocation)
    }
}
