import CoreGraphics
import Darwin
import Foundation
import Core

/// Vsock relay server that receives PencilPacket data and injects
/// tablet events via CGEventPost.
///
/// Why vsock: the host (iPad) and guest (macOS VM) communicate
/// through Virtualization.framework's VZVirtioSocketDevice.
/// Vsock provides ordered, reliable, stream-oriented delivery
/// (like TCP) without requiring network configuration or IP
/// addresses. The guest binds to a vsock port; the host connects
/// via VZVirtioSocketDevice.connectToPort:.
///
/// Why single-threaded: only one Apple Pencil connects at a time,
/// and CGEventPost is not documented as thread-safe. A single
/// accept loop with blocking reads is the simplest correct design.
enum RelayServer {

    static func run(port: UInt32) -> Never {
        let fd = createListenSocket(port: port)
        FileHandle.standardError.write(
            Data("Listening on vsock port \(port)\n".utf8)
        )

        // Block on accept; when a client disconnects, loop back and
        // wait for the next one. Only one client is served at a time
        // because there is only one cursor to control.
        while true {
            guard let clientFd = acceptClient(fd)
            else { continue }
            handleClient(clientFd)
            FileHandle.standardError.write(
                Data("Client disconnected\n".utf8)
            )
        }
    }

    // MARK: - Private

    private static func createListenSocket(port: UInt32) -> Int32 {
        let fd = socket(AF_VSOCK, SOCK_STREAM, 0)
        guard fd >= 0 else { fatalExit("Failed to create vsock socket") }

        var addr = sockaddr_vm()
        addr.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
        addr.svm_family = sa_family_t(AF_VSOCK)
        addr.svm_port = port
        // VMADDR_CID_ANY: accept connections from any CID (the host).
        addr.svm_cid = UInt32(VMADDR_CID_ANY)

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_vm>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(fd)
            fatalExit("bind vsock port \(port) failed: \(String(cString: strerror(errno)))")
        }
        guard listen(fd, 1) == 0 else {
            Darwin.close(fd)
            fatalExit("listen failed: \(String(cString: strerror(errno)))")
        }
        return fd
    }

    /// Accept a client connection on the vsock listener.
    ///
    /// Vsock connections can only originate from the host
    /// (Virtualization.framework), so no IP-based filtering is needed.
    /// The transport is VM-internal and not exposed to the network.
    private static func acceptClient(_ listenFd: Int32) -> Int32? {
        var peerAddr = sockaddr_vm()
        var peerLen = socklen_t(MemoryLayout<sockaddr_vm>.size)
        let clientFd = withUnsafeMutablePointer(to: &peerAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listenFd, $0, &peerLen)
            }
        }
        guard clientFd >= 0 else { return nil }

        FileHandle.standardError.write(
            Data("Client connected (CID \(peerAddr.svm_cid))\n".utf8)
        )
        return clientFd
    }

    /// Pen relay state machine.
    ///
    /// Tracks whether the pen is idle, hovering, or touching to
    /// correctly map iPad events to macOS tablet proximity and
    /// mouse events. See PencilEventType for the full lifecycle.
    private enum PenState {
        case idle
        case hovering
        case touching
    }

    private static func handleClient(_ fd: Int32) {
        // privateState: our synthetic events don't affect the global
        // event state machine. This prevents our injected mouse-down
        // from interfering with the user's real mouse state.
        let source = CGEventSource(stateID: .privateState)
        let deviceID = 1
        // Screen size is read once per connection. If the display
        // resolution changes mid-session, the client must reconnect.
        let screen = CGDisplayBounds(CGMainDisplayID()).size
        var state = PenState.idle

        var buf = [UInt8](repeating: 0, count: PencilPacket.size)
        while readExact(fd, into: &buf, count: PencilPacket.size) {
            guard let packet = PencilPacket.decode(from: buf) else {
                continue
            }
            let pos = CGPoint(
                x: CGFloat(packet.x) * screen.width,
                y: CGFloat(packet.y) * screen.height
            )
            state = injectEvent(
                packet, at: pos, source: source,
                deviceID: deviceID, state: state
            )
        }
        // Connection closed: clean up proximity if still active.
        if state != .idle {
            let pos = CGPoint.zero
            if state == .touching {
                let release = TabletPointParams(
                    pressure: 0, tiltX: 0, tiltY: 0, deviceID: deviceID
                )
                postPointPair(
                    release, mouseType: .leftMouseUp,
                    at: pos, source: source
                )
            }
            postProximityPair(
                entering: false, deviceID: deviceID,
                at: pos, source: source
            )
        }
        Darwin.close(fd)
    }

    private static func injectEvent(
        _ packet: PencilPacket,
        at pos: CGPoint,
        source: CGEventSource?,
        deviceID: Int,
        state: PenState
    ) -> PenState {
        let (tiltX, tiltY) = TiltConversion.toTiltXY(
            altitude: packet.altitude, azimuth: packet.azimuth
        )
        let pointParams = TabletPointParams(
            pressure: Double(packet.pressure),
            tiltX: tiltX, tiltY: tiltY, deviceID: deviceID
        )
        switch packet.type {
        case .hover:
            if state == .idle {
                postProximityPair(
                    entering: true, deviceID: deviceID,
                    at: pos, source: source
                )
            }
            postPointPair(
                pointParams, mouseType: .mouseMoved,
                at: pos, source: source
            )
            return .hovering
        case .hoverEnd:
            if state == .hovering {
                postProximityPair(
                    entering: false, deviceID: deviceID,
                    at: pos, source: source
                )
                return .idle
            }
            // touching or idle: ignore (pen touched screen or already gone)
            return state
        case .proximityEnter:
            if state == .idle {
                postProximityPair(
                    entering: true, deviceID: deviceID,
                    at: pos, source: source
                )
            }
            postPointPair(
                pointParams, mouseType: .leftMouseDown,
                at: pos, source: source
            )
            return .touching
        case .point:
            postPointPair(
                pointParams, mouseType: .leftMouseDragged,
                at: pos, source: source
            )
            return .touching
        case .proximityLeave:
            let release = TabletPointParams(
                pressure: 0, tiltX: tiltX, tiltY: tiltY, deviceID: deviceID
            )
            postPointPair(
                release, mouseType: .leftMouseUp,
                at: pos, source: source
            )
            postProximityPair(
                entering: false, deviceID: deviceID,
                at: pos, source: source
            )
            return .idle
        }
    }

    /// Post both forms of tablet proximity event.
    ///
    /// Why two forms: macOS apps receive tablet events in two ways:
    /// (a) mouse events with subtype tabletProximity — delivered via
    ///     NSEvent.mouseDown etc., used by most Carbon-era apps
    /// (b) standalone kCGEventTabletProximity — triggers NSView's
    ///     tabletProximity(with:) method, used by some Cocoa apps
    /// Clip Studio Paint requires form (b). Posting both ensures
    /// compatibility with the widest range of drawing apps.
    private static func postProximityPair(
        entering: Bool, deviceID: Int,
        at pos: CGPoint, source: CGEventSource?
    ) {
        let prox = TabletProximityParams(
            entering: entering, deviceID: deviceID
        )
        _ = TabletInjector.postStandaloneProximity(
            prox, at: pos, source: source
        )
        _ = TabletInjector.postProximity(
            prox, at: pos, source: source
        )
    }

    /// Post both forms of tablet point event (with pressure data).
    ///
    /// Same reasoning as postProximityPair: two delivery paths exist
    /// in macOS, and different apps listen on different ones.
    private static func postPointPair(
        _ params: TabletPointParams,
        mouseType: CGEventType,
        at pos: CGPoint, source: CGEventSource?
    ) {
        _ = TabletInjector.postTabletPoint(
            params, mouseType: mouseType, at: pos, source: source
        )
        _ = TabletInjector.postStandaloneTabletPoint(
            params, at: pos, source: source
        )
    }

    /// Read exactly `count` bytes, looping on partial reads.
    ///
    /// Why loop: vsock (like TCP) is a stream protocol. A single
    /// read() may return fewer bytes than requested. Without looping,
    /// the packet boundary shifts and all subsequent decodes produce
    /// garbage.
    private static func readExact(
        _ fd: Int32, into buf: inout [UInt8], count: Int
    ) -> Bool {
        var offset = 0
        while offset < count {
            let n = buf.withUnsafeMutableBufferPointer { ptr in
                Darwin.read(fd, ptr.baseAddress! + offset, count - offset)
            }
            if n <= 0 { return false }
            offset += n
        }
        return true
    }

    private static func fatalExit(_ msg: String) -> Never {
        FileHandle.standardError.write(Data("\(msg)\n".utf8))
        exit(1)
    }
}
