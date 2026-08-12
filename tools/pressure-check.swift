// Minimal AppKit app to check NSEvent.pressure from synthetic tablet events.
// Run from GUI terminal, then inject from another terminal.
//
// Usage:
//   swiftc tools/pressure-check.swift -o /tmp/pressure-check
//   /tmp/pressure-check
//
// Cleanup:
//   rm /tmp/pressure-check

import AppKit

class PressureView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        logEvent("mouseDown", event)
    }
    override func mouseDragged(with event: NSEvent) {
        logEvent("mouseDragged", event)
    }
    override func mouseUp(with event: NSEvent) {
        logEvent("mouseUp", event)
    }
    override func tabletPoint(with event: NSEvent) {
        logEvent("tabletPoint", event)
    }
    override func tabletProximity(with event: NSEvent) {
        let entering = event.isEnteringProximity
        let deviceID = event.deviceID
        NSLog("tabletProximity entering=\(entering) deviceID=\(deviceID)")
    }

    private func logEvent(_ name: String, _ e: NSEvent) {
        let sub = e.subtype.rawValue
        let p = e.pressure
        let loc = e.locationInWindow
        NSLog("\(name) subtype=\(sub) pressure=\(p) at (\(Int(loc.x)),\(Int(loc.y)))")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pressure Check — click here, then inject"
        window.contentView = PressureView()
        window.makeKeyAndOrderFront(nil)
        window.center()
        NSLog("Ready. Click this window, then run: pencil-probe inject")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
