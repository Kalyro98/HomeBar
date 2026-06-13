import Foundation
import UserNotifications

/// Kurzinfo zu einer Entität (für die Auswahl in den Einstellungen).
struct HAEntityInfo: Identifiable, Equatable {
    let id: String        // entity_id
    let name: String      // friendly_name
}

/// Schlanker Home-Assistant-WebSocket-Client für **Benachrichtigungen**.
/// Verbindet (lokal → remote) mit Token, lädt die Entitätenliste und sendet bei
/// Zustandsänderungen überwachter Entitäten native macOS-Benachrichtigungen.
///
/// **Thread-Sicherheit:** Der gesamte veränderliche Zustand (`task`, `authed`,
/// `candidateIndex`, `lastStates` …) wird ausschließlich auf der seriellen `queue`
/// angefasst. Die `URLSession`-Completion-Handler und alle `asyncAfter`-Timer
/// werden ebenfalls auf diese Queue gehoben. Nur die `@Published`-Properties
/// (für SwiftUI) werden auf dem Main-Thread gesetzt. Damit ist der frühere
/// Data Race auf `task` (Over-Release → EXC_BAD_ACCESS) ausgeschlossen.
final class HANotifier: NSObject, ObservableObject {

    enum Status: Equatable {
        case idle, connecting, connected, failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var entities: [HAEntityInfo] = []

    private let settings: AppSettings
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?

    /// Serielle Queue, auf der **aller** veränderliche Zustand lebt.
    private let queue = DispatchQueue(label: "ch.kalyro.HomeBar.notifier")

    private var candidates: [String] = []
    private var candidateIndex = 0
    private var authed = false
    private var msgID = 1
    private var getStatesID = -1
    private var shouldRun = false
    private var lastStates: [String: String] = [:]   // Baseline, um echte Änderungen zu erkennen
    private var nameByID: [String: String] = [:]

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        session = URLSession(configuration: .default)
    }

    // MARK: - Steuerung (öffentlich, von beliebigem Thread aufrufbar)

    /// Verbindet, sobald ein Token vorhanden ist (unabhängig davon, ob Benachrichtigungen
    /// aktiv sind – so ist die Entitätenliste zur Auswahl verfügbar).
    func start() {
        queue.async { [weak self] in self?._start() }
    }

    func stop() {
        queue.async { [weak self] in self?._stop() }
    }

    /// Nach geänderten Einstellungen (URL/Token) neu verbinden.
    func restart() {
        queue.async { [weak self] in
            guard let self else { return }
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.authed = false
            self.lastStates.removeAll()
            self._start()
        }
    }

    // MARK: - Steuerung (intern, immer auf `queue`)

    private func _start() {
        let token = settings.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, settings.isConfigured else { _stop(); return }
        shouldRun = true
        candidates = [settings.primaryURLString, settings.fallbackURLString]
            .compactMap { $0 }.filter { !$0.isEmpty }
        candidateIndex = 0
        attempt()
    }

    private func _stop() {
        shouldRun = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        authed = false
        setStatus(.idle)
    }

    // MARK: - Verbindungsaufbau (immer auf `queue`)

    private func attempt() {
        guard shouldRun else { return }
        guard candidateIndex < candidates.count else {
            setStatus(.failed("Keine Verbindung"))
            scheduleReconnect()
            return
        }
        guard let url = Self.websocketURL(from: candidates[candidateIndex]) else {
            candidateIndex += 1; attempt(); return
        }
        setStatus(.connecting)
        authed = false
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        receive()
        // Timeout: nur greifen, wenn genau dieser Task noch aktuell und nicht authentifiziert ist.
        queue.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.task === t, !self.authed else { return }
            t.cancel(with: .goingAway, reason: nil)
            self.candidateIndex += 1
            self.attempt()
        }
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        queue.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.shouldRun, !self.authed else { return }
            self.candidateIndex = 0
            self.attempt()
        }
    }

    // MARK: - Empfang (Completion-Handler wird auf `queue` gehoben)

    private func receive() {
        guard let current = task else { return }
        current.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                // Callback eines bereits ersetzten/abgelösten Tasks ignorieren.
                guard current === self.task else { return }
                switch result {
                case .failure:
                    self.authed = false
                    self.task = nil
                    if self.shouldRun { self.scheduleReconnect() }
                case .success(let message):
                    if case .string(let text) = message { self.handle(text) }
                    else if case .data(let d) = message, let text = String(data: d, encoding: .utf8) { self.handle(text) }
                    if self.task != nil { self.receive() }
                }
            }
        }
    }

    /// Verarbeitet eine eingehende WebSocket-Nachricht. Läuft auf `queue`.
    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        switch type {
        case "auth_required":
            send(["type": "auth", "access_token": settings.token])
        case "auth_ok":
            authed = true
            setStatus(.connected)
            getStatesID = nextID()
            send(["id": getStatesID, "type": "get_states"])
            send(["id": nextID(), "type": "subscribe_events", "event_type": "state_changed"])
        case "auth_invalid":
            shouldRun = false
            setStatus(.failed("Token ungültig"))
            task?.cancel(with: .goingAway, reason: nil); task = nil
        case "result":
            if let id = obj["id"] as? Int, id == getStatesID,
               let arr = obj["result"] as? [[String: Any]] {
                ingestSnapshot(arr)
            }
        case "event":
            if let ev = obj["event"] as? [String: Any],
               ev["event_type"] as? String == "state_changed",
               let d = ev["data"] as? [String: Any] {
                handleStateChange(d)
            }
        default: break
        }
    }

    /// Snapshot der Entitäten als Baseline übernehmen. Läuft auf `queue`.
    private func ingestSnapshot(_ arr: [[String: Any]]) {
        var names: [String: String] = [:]
        var states: [String: String] = [:]
        var list: [HAEntityInfo] = []
        for s in arr {
            guard let eid = s["entity_id"] as? String else { continue }
            let attrs = s["attributes"] as? [String: Any]
            let name = attrs?["friendly_name"] as? String ?? eid
            names[eid] = name
            states[eid] = s["state"] as? String ?? ""
            list.append(HAEntityInfo(id: eid, name: name))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        nameByID = names
        lastStates = states          // Baseline – kein Notify für den Snapshot
        DispatchQueue.main.async { self.entities = list }
    }

    /// Zustandsänderung einer Entität verarbeiten. Läuft auf `queue`.
    private func handleStateChange(_ data: [String: Any]) {
        guard let eid = data["entity_id"] as? String,
              let newState = data["new_state"] as? [String: Any] else { return }
        let newValue = newState["state"] as? String ?? ""
        let previous = lastStates[eid]
        lastStates[eid] = newValue
        guard settings.notificationsEnabled,
              settings.watchedEntityIDs.contains(eid),
              newValue != previous,
              newValue != "unavailable", newValue != "unknown" else { return }
        let attrs = newState["attributes"] as? [String: Any]
        let name = attrs?["friendly_name"] as? String ?? nameByID[eid] ?? eid
        let unit = attrs?["unit_of_measurement"] as? String
        let body = unit != nil ? "\(newValue) \(unit!)" : newValue
        Self.postNotification(title: name, body: body)
    }

    // MARK: - Senden (immer auf `queue`)

    private func send(_ dict: [String: Any]) {
        guard let task,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func nextID() -> Int { msgID += 1; return msgID }

    private func setStatus(_ s: Status) {
        DispatchQueue.main.async { self.status = s }
    }

    // MARK: - Benachrichtigungen

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - URL-Helfer

    static func websocketURL(from base: String) -> URL? {
        var s = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }
        guard var comps = URLComponents(string: s) else { return nil }
        comps.scheme = (comps.scheme == "https" || comps.scheme == "wss") ? "wss" : "ws"
        var path = comps.path
        if path.hasSuffix("/") { path.removeLast() }
        comps.path = path + "/api/websocket"
        return comps.url
    }
}
