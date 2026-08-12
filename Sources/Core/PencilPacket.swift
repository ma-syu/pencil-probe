/// Event type in the pencil relay protocol.
public enum PencilEventType: UInt8, Sendable {
    /// Pen dragging on screen (touchesMoved).
    case point = 0
    /// Pen began stroke (touchesBegan).
    case proximityEnter = 1
    /// Pen ended stroke (touchesEnded).
    case proximityLeave = 2
}

/// A 13-byte binary packet for relaying Apple Pencil data over TCP.
///
/// Wire format (little-endian):
///   [0]      uint8   type (0=point, 1=enter, 2=leave)
///   [1..4]   float32 pressure (0.0–1.0)
///   [5..8]   float32 x (0.0–1.0, normalized)
///   [9..12]  float32 y (0.0–1.0, normalized)
public struct PencilPacket: Sendable, Equatable {
    public static let size = 13

    public let type: PencilEventType
    public let pressure: Float
    public let x: Float
    public let y: Float

    public init(type: PencilEventType, pressure: Float, x: Float, y: Float) {
        self.type = type
        self.pressure = PencilPacket.clamp01(pressure)
        self.x = PencilPacket.clamp01(x)
        self.y = PencilPacket.clamp01(y)
    }

    /// Encode to 13 bytes, little-endian.
    public func encode() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: PencilPacket.size)
        buf[0] = type.rawValue
        PencilPacket.writeFloat32LE(pressure, to: &buf, at: 1)
        PencilPacket.writeFloat32LE(x, to: &buf, at: 5)
        PencilPacket.writeFloat32LE(y, to: &buf, at: 9)
        return buf
    }

    /// Decode from 13+ bytes. Returns nil for short, invalid type,
    /// or non-finite float data.
    public static func decode(from bytes: [UInt8]) -> PencilPacket? {
        guard bytes.count >= size else { return nil }
        guard let eventType = PencilEventType(rawValue: bytes[0]) else {
            return nil
        }
        let p = readFloat32LE(from: bytes, at: 1)
        let xVal = readFloat32LE(from: bytes, at: 5)
        let yVal = readFloat32LE(from: bytes, at: 9)
        guard p.isFinite && xVal.isFinite && yVal.isFinite else {
            return nil
        }
        return PencilPacket(
            type: eventType, pressure: p, x: xVal, y: yVal
        )
    }

    // MARK: - Internal (visible for tests)

    static func clamp01(_ v: Float) -> Float {
        min(max(v, 0.0), 1.0)
    }

    // MARK: - Private

    private static func writeFloat32LE(
        _ value: Float, to buf: inout [UInt8], at offset: Int
    ) {
        let raw = value.bitPattern
        buf[offset]     = UInt8(raw & 0xFF)
        buf[offset + 1] = UInt8((raw >> 8) & 0xFF)
        buf[offset + 2] = UInt8((raw >> 16) & 0xFF)
        buf[offset + 3] = UInt8((raw >> 24) & 0xFF)
    }

    private static func readFloat32LE(
        from bytes: [UInt8], at offset: Int
    ) -> Float {
        var raw: UInt32 = 0
        raw |= UInt32(bytes[offset])
        raw |= UInt32(bytes[offset + 1]) << 8
        raw |= UInt32(bytes[offset + 2]) << 16
        raw |= UInt32(bytes[offset + 3]) << 24
        return Float(bitPattern: raw)
    }
}
