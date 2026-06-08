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

    private var pinned = false
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var moveMonitor: Any?
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
            addTracking(to: button)
        }

        // Fenster mit der HA-Weboberfläche
        panelController = PanelController(rootView: PanelView(settings: settings, notifier: notifier))
        panelController.onUserInteraction = { [weak self] in
            // Klick ins Fenster -> pinnen UND App aktivieren, damit Login/Eingabe funktioniert.
            self?.pinned = true
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
            self?.toggleFromHotKey()
        }
    }

    private func toggleFromHotKey() {
        if panelController.isVisible {
            hidePanel()
        } else {
            pinned = true
            showPanel(activate: true)
        }
    }

    // MARK: - Tracking / Hover

    private func addTracking(to button: NSStatusBarButton) {
        let area = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(area)
    }

    @objc func mouseEntered(with event: NSEvent) {
        hideWork?.cancel()
        guard !panelController.isVisible else { return }
        let work = DispatchWorkItem { [weak self] in self?.showPanel(activate: false) }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    @objc func mouseExited(with event: NSEvent) {
        showWork?.cancel()
        scheduleHideIfNeeded()
    }

    private func scheduleHideIfNeeded() {
        guard !pinned else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pinned else { return }
            if !self.panelController.mouseIsOver() && !self.mouseOverButton() {
                self.hidePanel()
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - Anzeigen / Verstecken

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if isRightClick {
            showContextMenu()
        } else if panelController.isVisible && pinned {
            hidePanel()
        } else {
            pinned = true
            showPanel(activate: true)
        }
    }

    /// Rechtsklick-/Control-Klick-Menü auf dem Menüleisten-Symbol.
    private func showContextMenu() {
        if !pinned { hidePanel() }   // Hover-Fenster ausblenden, stört sonst das Menü
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

    @objc private func openFromMenu() {
        pinned = true
        showPanel(activate: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showPanel(activate: Bool) {
        guard let button = statusItem.button else { return }
        panelController.show(relativeTo: button, activate: activate)
        startMonitors()
    }

    private func hidePanel() {
        pinned = false
        panelController.hide()
        stopMonitors()
    }

    // MARK: - Globale Maus-Monitore

    private func startMonitors() {
        stopMonitors()
        // Hover-Schließen, solange nicht gepinnt.
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self else { return }
            if self.pinned { return }
            if self.panelController.mouseIsOver() || self.mouseOverButton() {
                self.hideWork?.cancel()
            } else {
                self.scheduleHideIfNeeded()
            }
        }
        // Klick außerhalb schließt (auch im gepinnten Modus).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if !self.panelController.mouseIsOver() && !self.mouseOverButton() {
                self.hidePanel()
            }
        }
    }

    private func stopMonitors() {
        if let m = moveMonitor { NSEvent.removeMonitor(m); moveMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func mouseOverButton() -> Bool {
        guard let button = statusItem.button, let win = button.window else { return false }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = win.convertToScreen(inWindow)
        return onScreen.contains(NSEvent.mouseLocation)
    }
}
