import CoreGraphics
import Foundation
import Core

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

// Flush stdout after each line so piped output appears immediately.
setlinebuf(stdout)

CFRunLoopRun()
