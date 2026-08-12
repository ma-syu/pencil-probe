import CoreGraphics
import Foundation
import Core

let mode = CommandLine.arguments.dropFirst().first ?? "observe"

switch mode {
case "observe":
    runObserve()
case "inject":
    runInject()
default:
    FileHandle.standardError.write(
        Data("Usage: pencil-probe [observe|inject]\n".utf8)
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

// MARK: - Inject mode (Phase 1, stage 0)

func runInject() {
    guard CGPreflightPostEventAccess() else {
        let msg = """
            No permission to post events.
            Grant Accessibility permission in:
              System Settings > Privacy & Security > Accessibility
            Then re-run this tool.
            """
        FileHandle.standardError.write(Data(msg.utf8))
        exit(1)
    }

    let pressure = 0.5
    let position = CGPoint(x: 400, y: 400)

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
