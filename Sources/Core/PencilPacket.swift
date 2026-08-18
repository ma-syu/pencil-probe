/// Event type in the pencil relay protocol.
///
/// Maps to UIKit touch lifecycle: the host (iPad) sends proximityEnter
/// when the Pencil first touches the screen, point events while dragging,
/// and proximityLeave when lifted. These map to macOS tablet proximity
/// and tablet-point events on the guest side (see TabletInjector).
public enum PencilEventType: UInt8, Sendable {
    /// Pen dragging on screen (touchesMoved).
    case point = 0
    /// Pen began stroke (touchesBegan).
    case proximityEnter = 1
    /// Pen ended stroke (touchesEnded).
    case proximityLeave = 2
}

/// A 21-byte binary packet for relaying Apple Pencil data over vsock.
///
/// Wire format (little-endian):
///   [0]      uint8   type (0=point, 1=enter, 2=leave)
///   [1..4]   float32 pressure (0.0–1.0)
///   [5..8]   float32 x (0.0–1.0, normalized)
///   [9..12]  float32 y (0.0–1.0, normalized)
///   [13..16] float32 altitude (0=parallel, π/2=perpendicular)
///   [17..20] float32 azimuth  (0–2π, tilt direction)
///
/// Why altitude+azimuth on the wire (not tiltX/tiltY): the host (iPad)
/// reads these from UITouch natively. The conversion to CGEvent's
/// tiltX/tiltY is a pure function in the Core layer, keeping the
/// protocol close to the sensor data and the conversion testable.
///
/// Why fixed-size: no framing, no length prefix, no delimiter.
/// At 240Hz this is ~5.0KB/s, well within vsock bandwidth.
///
/// Why little-endian: both iOS (ARM) and macOS on Apple Silicon use
/// little-endian natively. No byte-swapping needed on either side.
///
/// Why normalized 0–1 coordinates: the host and guest may have different
/// screen resolutions. Normalizing on the host and denormalizing on the
/// guest keeps the protocol resolution-independent.
public struct PencilPacket: Sendable, Equatable {
    public static let size = 21

    /// Minimum decodable size (v1 packet without tilt fields).
    public static let legacySize = 13

    /// Perpendicular to surface: no tilt. Used as default when tilt
    /// data is absent (legacy packets) or meaningless (pen lift-off).
    /// Perpendicular to surface: no tilt. Used as default when tilt
    /// data is absent (legacy packets) or meaningless (pen lift-off).
    public static let noTiltAltitude: Float = .pi / 2
    public static let noTiltAzimuth: Float = 0

    // Wire format byte offsets. Each field is a float32 (4 bytes)
    // except the 1-byte type prefix.
    static let offsetPressure = 1
    static let offsetX = 5
    static let offsetY = 9
    static let offsetAltitude = 13
    static let offsetAzimuth = 17

    public let type: PencilEventType
    public let pressure: Float
    public let x: Float
    public let y: Float
    /// Altitude angle: 0 = parallel to surface, π/2 = perpendicular.
    public let altitude: Float
    /// Azimuth angle: 0–2π, direction of tilt from positive X axis.
    public let azimuth: Float

    public init(
        type: PencilEventType, pressure: Float, x: Float, y: Float,
        altitude: Float = noTiltAltitude, azimuth: Float = noTiltAzimuth
    ) {
        self.type = type
        // Clamp at the boundary: the host may send slightly out-of-range
        // values due to float rounding, and the guest CGEvent fields
        // expect specific ranges. Clamping here prevents nonsensical
        // values from reaching the OS.
        self.pressure = PencilPacket.clamp01(pressure)
        self.x = PencilPacket.clamp01(x)
        self.y = PencilPacket.clamp01(y)
        self.altitude = PencilPacket.clampAltitude(altitude)
        self.azimuth = PencilPacket.clampAzimuth(azimuth)
    }

    /// Encode to 21 bytes, little-endian.
    public func encode() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: PencilPacket.size)
        buf[0] = type.rawValue
        PencilPacket.writeFloat32LE(pressure, to: &buf, at: Self.offsetPressure)
        PencilPacket.writeFloat32LE(x, to: &buf, at: Self.offsetX)
        PencilPacket.writeFloat32LE(y, to: &buf, at: Self.offsetY)
        PencilPacket.writeFloat32LE(altitude, to: &buf, at: Self.offsetAltitude)
        PencilPacket.writeFloat32LE(azimuth, to: &buf, at: Self.offsetAzimuth)
        return buf
    }

    /// Decode from 13+ bytes. Returns nil for short, invalid type,
    /// or non-finite float data. Legacy 13-byte packets decode with
    /// altitude=π/2 (perpendicular) and azimuth=0 (no tilt).
    public static func decode(from bytes: [UInt8]) -> PencilPacket? {
        guard bytes.count >= legacySize else { return nil }
        guard let eventType = PencilEventType(rawValue: bytes[0]) else {
            return nil
        }
        let p = readFloat32LE(from: bytes, at: offsetPressure)
        let xVal = readFloat32LE(from: bytes, at: offsetX)
        let yVal = readFloat32LE(from: bytes, at: offsetY)
        // Reject NaN/Inf: these are valid IEEE 754 bit patterns that
        // could arrive over vsock (malformed sender or corruption).
        // Passing them to CGEvent would produce undefined behavior.
        guard [p, xVal, yVal].allSatisfy(\.isFinite) else {
            return nil
        }
        // Tilt fields: default to perpendicular (no tilt) when
        // receiving legacy 13-byte packets.
        var alt: Float = noTiltAltitude
        var azi: Float = noTiltAzimuth
        if bytes.count >= size {
            alt = readFloat32LE(from: bytes, at: offsetAltitude)
            azi = readFloat32LE(from: bytes, at: offsetAzimuth)
            guard [alt, azi].allSatisfy(\.isFinite) else {
                return nil
            }
        }
        return PencilPacket(
            type: eventType, pressure: p, x: xVal, y: yVal,
            altitude: alt, azimuth: azi
        )
    }

    // MARK: - Internal (visible for tests)

    static func clamp01(_ v: Float) -> Float {
        min(max(v, 0.0), 1.0)
    }

    static func clampAltitude(_ v: Float) -> Float {
        min(max(v, 0.0), .pi / 2)
    }

    static func clampAzimuth(_ v: Float) -> Float {
        min(max(v, 0.0), .pi * 2)
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
