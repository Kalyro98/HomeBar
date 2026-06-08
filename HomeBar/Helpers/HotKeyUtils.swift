import AppKit
import Carbon.HIToolbox

/// Hilfsfunktionen zum Aufnehmen und Anzeigen von Tastenkürzeln.
enum HotKeyUtils {

    /// Carbon-Standard: ⌘⇧H
    static let defaultKeyCode = Int(kVK_ANSI_H)
    static let defaultModifiers = Int(cmdKey | shiftKey)
    static let defaultChar = "H"

    static let escapeKeyCode = Int(kVK_Escape)

    /// Cocoa-Modifier → Carbon-Modifier (für RegisterEventHotKey).
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if flags.contains(.command) { c |= UInt32(cmdKey) }
        if flags.contains(.option)  { c |= UInt32(optionKey) }
        if flags.contains(.control) { c |= UInt32(controlKey) }
        if flags.contains(.shift)   { c |= UInt32(shiftKey) }
        return c
    }

    /// Mindestens ein „echter" Modifier (kein reines Shift) für einen sinnvollen globalen Shortcut.
    static func hasRequiredModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
    }

    /// Anzeige-Zeichen für einen Tastendruck (Sonderfälle gemappt, sonst Großbuchstabe).
    static func keyChar(for event: NSEvent) -> String {
        if let special = specialKeys[Int(event.keyCode)] { return special }
        let c = event.charactersIgnoringModifiers ?? ""
        return c.uppercased()
    }

    /// Volle Anzeige, z. B. „⌘⇧H".
    static func display(char: String, carbonModifiers: Int) -> String {
        var s = ""
        if carbonModifiers & Int(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & Int(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & Int(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & Int(cmdKey)     != 0 { s += "⌘" }
        return s + char
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "␣", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12"
    ]
}
