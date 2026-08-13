import ApplicationServices
import Foundation
import Core

// pencil-probe: relay tool for Apple Pencil pressure on macOS guest
// VMs running under VirtualMac on iPad.
//
// Receives Pencil data (pressure, tilt) from iPad over TCP and
// injects tablet events in real time via CGEventPost (P0012).

var port: UInt16 = 9923
var listenAddr = "127.0.0.1"
var allowedPeer: String?
let args = Array(CommandLine.arguments.dropFirst())
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
// AXIsProcessTrusted: check if we have accessibility permission,
// which is required for CGEventPost to deliver events to other apps.
// Rebuilding the binary resets this permission (macOS ties it to
// the binary's code signature / hash).
if !AXIsProcessTrusted() {
    FileHandle.standardError.write(Data(
        "WARNING: Accessibility not granted. CGEventPost will be silently dropped.\n".utf8
    ))
    FileHandle.standardError.write(Data(
        "Grant in: System Settings > Privacy & Security > Accessibility\n".utf8
    ))
    // When launched via SSH, macOS attributes the process to
    // sshd-keygen-wrapper (the launchd wrapper for sshd), not to
    // this binary. The Accessibility entry that must be enabled is
    // "sshd-keygen-wrapper", not "pencil-probe".
    FileHandle.standardError.write(Data(
        "If running via SSH, enable 'sshd-keygen-wrapper' (not this binary).\n".utf8
    ))
}

RelayServer.run(
    listenAddr: listenAddr, port: port, allowedPeer: allowedPeer
)
