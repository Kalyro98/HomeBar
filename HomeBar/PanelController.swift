import AppKit
import SwiftUI

/// Verwaltet das randlose, in der Größe ziehbare NSPanel-Fenster.
/// Merkt sich Größe UND Position und stellt sie bei jedem Öffnen wieder her.
final class PanelController: NSObject, NSWindowDelegate {

    private let panel: Panel
    private let frameKey = "panelFrame"
    private let defaultSize = NSSize(width: 360, height: 480)

    /// Wird gesetzt, sobald der Nutzer das Fenster anklickt/zieht (Pin).
    var onUserInteraction: (() -> Void)?

    init(rootView: some View) {
        let hosting = NSHostingView(rootView: rootView)

        panel = Panel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 280, height: 320)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting

        panel.interactionHandler = { [weak self] in self?.onUserInteraction?() }
    }

    var isVisible: Bool { panel.isVisible }

    /// Zeigt das Fenster unter dem Status-Item. `activate` für gepinnten Modus (Tastatureingabe).
    func show(relativeTo statusButton: NSStatusBarButton, activate: Bool) {
        positionPanel(relativeTo: statusButton)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// App aktivieren und Fenster zum Key-Window machen (für Texteingabe/Login in der WebView).
    func activate() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Prüft, ob die Maus aktuell über dem Fenster liegt (für Hover-Schließlogik).
    func mouseIsOver() -> Bool {
        guard panel.isVisible else { return false }
        return panel.frame.contains(NSEvent.mouseLocation)
    }

    // MARK: - Positionierung & Frame-Persistenz

    private func positionPanel(relativeTo statusButton: NSStatusBarButton) {
        let size = savedSize() ?? defaultSize

        // Position des Status-Items in Bildschirmkoordinaten ermitteln.
        guard let buttonWindow = statusButton.window else {
            panel.setContentSize(size)
            panel.center()
            return
        }
        let buttonRectInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)

        // Gespeicherte Position bevorzugen, sonst unter dem Icon ausrichten.
        if let saved = savedFrame() {
            panel.setFrame(saved, display: false)
        } else {
            var origin = NSPoint(
                x: buttonRectOnScreen.midX - size.width / 2,
                y: buttonRectOnScreen.minY - size.height - 6
            )
            // Innerhalb des Bildschirms halten.
            if let screen = buttonWindow.screen ?? NSScreen.main {
                let vf = screen.visibleFrame
                origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
                origin.y = max(origin.y, vf.minY + 8)
            }
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
        }
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }

    private func savedFrame() -> NSRect? {
        guard let s = UserDefaults.standard.string(forKey: frameKey) else { return nil }
        let r = NSRectFromString(s)
        return r.width > 0 && r.height > 0 ? r : nil
    }

    private func savedSize() -> NSSize? {
        savedFrame()?.size
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) { saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
}

/// NSPanel-Subklasse, die Key werden darf (für Texteingabe in den Einstellungen)
/// und Interaktionen (Klick) meldet, damit der Hover-Modus zum Pin wechselt.
final class Panel: NSPanel {
    var interactionHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            interactionHandler?()
        }
        super.sendEvent(event)
    }
}
