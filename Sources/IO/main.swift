import CoreGraphics
import Foundation
import Core

let mode = CommandLine.arguments.dropFirst().first ?? "observe"

switch mode {
case "observe":
    runObserve()
case "inject":
    runInject()
case "relay":
    runRelay()
default:
    FileHandle.standardError.write(
        Data("Usage: pencil-probe [observe|inject|relay]\n".utf8)
    )
    exit(1)
}

// MARK: - Observe mode (Phase 0)

func runObserve() -> Never {
    guard let tap = EventTap.create() else {
        let msg = """
            Failed to create event tap.
            Grant Accessibility permission in:
              System Settings > Privacy & Security > Accessibility
            Then re-run this tool.
            """
        FileHandle.standardError.write(Data(msg.utf8))
        exit(1)
    }

    CFRunLoopAddSource(
        CFRunLoopGetCurrent(),
        tap.source,
        .commonModes
    )

    print(EventFormatter.header())
    setlinebuf(stdout)
    CFRunLoopRun()
    exit(0)
}

// MARK: - Relay mode (Phase 2)

func runRelay() -> Never {
    var port: UInt16 = 9923
    var listenAddr = "127.0.0.1"
    var allowedPeer: String?
    let args = Array(CommandLine.arguments.dropFirst(2))
    if let idx = args.firstIndex(of: "--port"),
       idx + 1 < args.count,
       let p = UInt16(args[idx + 1]) {
        port = p
    }
    if let idx = args.firstIndex(of: "--listen"),
       idx + 1 < args.count {
        listenAddr = args[idx + 1]
    }
    if let idx = args.firstIndex(of: "--allow"),
       idx + 1 < args.count {
        allowedPeer = args[idx + 1]
    }
    RelayServer.run(
        listenAddr: listenAddr, port: port, allowedPeer: allowedPeer
    )
}

// MARK: - Inject mode (Phase 1, stage 0)

func runInject() {
    if !CGPreflightPostEventAccess() {
        let msg = """
            Warning: CGPreflightPostEventAccess() returned false.
            Events may not be delivered. If injection fails, grant
            Accessibility permission in:
              System Settings > Privacy & Security > Accessibility
            Attempting injection anyway...

            """
        FileHandle.standardError.write(Data(msg.utf8))
    }

    let pressure = 0.5

    // Give the user time to switch to the target app and place the cursor.
    for i in (1...5).reversed() {
        let cursor = CGEvent(source: nil)?.location ?? .zero
        FileHandle.standardError.write(
            Data("Injecting in \(i)... cursor at (\(Int(cursor.x)), \(Int(cursor.y))) — move to target canvas\n".utf8)
        )
        Thread.sleep(forTimeInterval: 1.0)
    }

    let position = CGEvent(source: nil)?.location ?? CGPoint(x: 400, y: 400)

    FileHandle.standardError.write(
        Data("Injecting test stroke: pressure=\(pressure) at \(position)\n".utf8)
    )

    let ok = TabletInjector.injectTestStroke(
        pressure: pressure, at: position
    )

    if ok {
        FileHandle.standardError.write(Data("Injection complete.\n".utf8))
    } else {
        FileHandle.standardError.write(Data("Injection failed.\n".utf8))
        exit(1)
    }
}
