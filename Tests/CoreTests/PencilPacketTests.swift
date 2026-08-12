import Testing
@testable import Core

@Suite struct PencilPacketTests {

    // Property: encode→decode round-trip preserves all fields.
    @Test func roundTrip() {
        var rng = SystemRandomNumberGenerator()
        let types: [PencilEventType] = [
            .point, .proximityEnter, .proximityLeave,
        ]
        for _ in 0..<200 {
            let original = PencilPacket(
                type: types.randomElement(using: &rng)!,
                pressure: Float.random(in: 0...1, using: &rng),
                x: Float.random(in: 0...1, using: &rng),
                y: Float.random(in: 0...1, using: &rng)
            )
            let encoded = original.encode()
            #expect(encoded.count == PencilPacket.size)
            let decoded = PencilPacket.decode(from: encoded)
            #expect(decoded == original)
        }
    }

    // Property: values are clamped to 0.0–1.0.
    @Test func clamping() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let p = PencilPacket(
                type: .point,
                pressure: Float.random(in: -10...10, using: &rng),
                x: Float.random(in: -10...10, using: &rng),
                y: Float.random(in: -10...10, using: &rng)
            )
            #expect(p.pressure >= 0.0 && p.pressure <= 1.0)
            #expect(p.x >= 0.0 && p.x <= 1.0)
            #expect(p.y >= 0.0 && p.y <= 1.0)
        }
    }

    // Property: in-range values are preserved exactly.
    @Test func preservesInRange() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let pressure = Float.random(in: 0...1, using: &rng)
            let x = Float.random(in: 0...1, using: &rng)
            let y = Float.random(in: 0...1, using: &rng)
            let p = PencilPacket(
                type: .point, pressure: pressure, x: x, y: y
            )
            #expect(p.pressure == pressure)
            #expect(p.x == x)
            #expect(p.y == y)
        }
    }

    @Test func decodeTooShort() {
        for length in 0..<PencilPacket.size {
            let bytes = [UInt8](repeating: 0, count: length)
            #expect(PencilPacket.decode(from: bytes) == nil)
        }
    }

    @Test func decodeInvalidType() {
        var bytes = PencilPacket(
            type: .point, pressure: 0.5, x: 0.5, y: 0.5
        ).encode()
        for invalid: UInt8 in [3, 4, 128, 255] {
            bytes[0] = invalid
            #expect(PencilPacket.decode(from: bytes) == nil)
        }
    }

    @Test func decodeRejectsNaN() {
        var bytes = PencilPacket(
            type: .point, pressure: 0.5, x: 0.5, y: 0.5
        ).encode()
        writeRawFloat32LE(Float.nan, to: &bytes, at: 1)
        #expect(PencilPacket.decode(from: bytes) == nil)
    }

    @Test func decodeRejectsInf() {
        var bytes = PencilPacket(
            type: .point, pressure: 0.5, x: 0.5, y: 0.5
        ).encode()
        writeRawFloat32LE(.infinity, to: &bytes, at: 5)
        #expect(PencilPacket.decode(from: bytes) == nil)
    }

    @Test func decodeExtraTrailingBytes() {
        var bytes = PencilPacket(
            type: .proximityEnter, pressure: 0.75, x: 0.25, y: 0.5
        ).encode()
        bytes.append(contentsOf: [0xFF, 0xFF, 0xFF])
        let decoded = PencilPacket.decode(from: bytes)
        #expect(decoded?.type == .proximityEnter)
        #expect(decoded?.pressure == 0.75)
        #expect(decoded?.x == 0.25)
        #expect(decoded?.y == 0.5)
    }

    @Test func wireFormatTypeByte() {
        let point = PencilPacket(
            type: .point, pressure: 0, x: 0, y: 0
        )
        #expect(point.encode()[0] == 0)

        let enter = PencilPacket(
            type: .proximityEnter, pressure: 0, x: 0, y: 0
        )
        #expect(enter.encode()[0] == 1)

        let leave = PencilPacket(
            type: .proximityLeave, pressure: 0, x: 0, y: 0
        )
        #expect(leave.encode()[0] == 2)
    }

    @Test func encodedSizeConstant() {
        let types: [PencilEventType] = [
            .point, .proximityEnter, .proximityLeave,
        ]
        for t in types {
            let p = PencilPacket(type: t, pressure: 0.5, x: 0.5, y: 0.5)
            #expect(p.encode().count == 13)
        }
    }

    @Test func boundaryClamping() {
        let p = PencilPacket(
            type: .point, pressure: -0.001, x: 1.001, y: -100
        )
        #expect(p.pressure == 0.0)
        #expect(p.x == 1.0)
        #expect(p.y == 0.0)
    }

    // MARK: - Helpers

    private func writeRawFloat32LE(
        _ value: Float, to buf: inout [UInt8], at offset: Int
    ) {
        let raw = value.bitPattern
        buf[offset]     = UInt8(raw & 0xFF)
        buf[offset + 1] = UInt8((raw >> 8) & 0xFF)
        buf[offset + 2] = UInt8((raw >> 16) & 0xFF)
        buf[offset + 3] = UInt8((raw >> 24) & 0xFF)
    }
}
