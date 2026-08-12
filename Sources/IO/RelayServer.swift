import CoreGraphics
import Darwin
import Foundation
import Core

/// TCP relay server that receives PencilPacket data and injects
/// tablet events via CGEventPost.
enum RelayServer {

    static func run(
        listenAddr: String, port: UInt16, allowedPeer: String?
    ) -> Never {
        if listenAddr != "127.0.0.1" && allowedPeer == nil {
            FileHandle.standardError.write(Data(
                "Warning: listening on \(listenAddr) without --allow. Any host can connect.\n".utf8
            ))
        }
        let fd = createListenSocket(listenAddr: listenAddr, port: port)
        FileHandle.standardError.write(
            Data("Listening on \(listenAddr):\(port)\n".utf8)
        )

        while true {
            guard let clientFd = acceptClient(fd, allowedPeer: allowedPeer)
            else { continue }
            handleClient(clientFd)
            FileHandle.standardError.write(
                Data("Client disconnected\n".utf8)
            )
        }
    }

    // MARK: - Private

    private static func createListenSocket(
        listenAddr: String, port: UInt16
    ) -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            fatalExit("Failed to create socket")
        }

        var opt: Int32 = 1
        setsockopt(
            fd, SOL_SOCKET, SO_REUSEADDR, &opt,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(listenAddr)

        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let msg = String(cString: strerror(errno))
            Darwin.close(fd)
            fatalExit("bind \(listenAddr):\(port) failed: \(msg)")
        }

        guard listen(fd, 1) == 0 else {
            let msg = String(cString: strerror(errno))
            Darwin.close(fd)
            fatalExit("listen failed: \(msg)")
        }

        return fd
    }

    private static func acceptClient(
        _ listenFd: Int32, allowedPeer: String?
    ) -> Int32? {
        var peerAddr = sockaddr_in()
        var peerLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientFd = withUnsafeMutablePointer(to: &peerAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listenFd, $0, &peerLen)
            }
        }
        guard clientFd >= 0 else { return nil }

        let peerIP = String(cString: inet_ntoa(peerAddr.sin_addr))
        if let allowed = allowedPeer, peerIP != allowed {
            FileHandle.standardError.write(Data(
                "Rejected \(peerIP) (allowed: \(allowed))\n".utf8
            ))
            Darwin.close(clientFd)
            return nil
        }

        FileHandle.standardError.write(
            Data("Client connected from \(peerIP)\n".utf8)
        )
        return clientFd
    }

    private static func handleClient(_ fd: Int32) {
        var nodelay: Int32 = 1
        setsockopt(
            fd, IPPROTO_TCP, TCP_NODELAY, &nodelay,
            socklen_t(MemoryLayout<Int32>.size)
        )

        let source = CGEventSource(stateID: .privateState)
        let deviceID = 1
        let screen = CGDisplayBounds(CGMainDisplayID()).size

        var buf = [UInt8](repeating: 0, count: PencilPacket.size)
        while readExact(fd, into: &buf, count: PencilPacket.size) {
            guard let packet = PencilPacket.decode(from: buf) else {
                continue
            }
            let pos = CGPoint(
                x: CGFloat(packet.x) * screen.width,
                y: CGFloat(packet.y) * screen.height
            )
            injectEvent(packet, at: pos, source: source, deviceID: deviceID)
        }
        Darwin.close(fd)
    }

    private static func injectEvent(
        _ packet: PencilPacket,
        at pos: CGPoint,
        source: CGEventSource?,
        deviceID: Int
    ) {
        switch packet.type {
        case .proximityEnter:
            postProximityPair(
                entering: true, deviceID: deviceID,
                at: pos, source: source
            )
            postPointPair(
                pressure: Double(packet.pressure), deviceID: deviceID,
                mouseType: .leftMouseDown, at: pos, source: source
            )
        case .point:
            postPointPair(
                pressure: Double(packet.pressure), deviceID: deviceID,
                mouseType: .leftMouseDragged, at: pos, source: source
            )
        case .proximityLeave:
            postPointPair(
                pressure: 0, deviceID: deviceID,
                mouseType: .leftMouseUp, at: pos, source: source
            )
            postProximityPair(
                entering: false, deviceID: deviceID,
                at: pos, source: source
            )
        }
    }

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

    private static func postPointPair(
        pressure: Double, deviceID: Int,
        mouseType: CGEventType,
        at pos: CGPoint, source: CGEventSource?
    ) {
        let params = TabletPointParams(
            pressure: pressure, tiltX: 0, tiltY: 0, deviceID: deviceID
        )
        _ = TabletInjector.postTabletPoint(
            params, mouseType: mouseType, at: pos, source: source
        )
        _ = TabletInjector.postStandaloneTabletPoint(
            params, at: pos, source: source
        )
    }

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
