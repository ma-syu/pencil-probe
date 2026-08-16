import Testing
@testable import Core

@Suite struct TabletPointParamsTests {

    // Property: pressure is always clamped to 0.0–1.0.
    @Test func pressureClamp() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let raw = Double.random(in: -10...10, using: &rng)
            let p = TabletPointParams(
                pressure: raw, tiltX: 0, tiltY: 0, deviceID: 1
            )
            #expect(p.pressure >= 0.0 && p.pressure <= 1.0)
        }
    }

    // Property: in-range pressure is preserved exactly.
    @Test func pressurePreserved() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let raw = Double.random(in: 0.0...1.0, using: &rng)
            let p = TabletPointParams(
                pressure: raw, tiltX: 0, tiltY: 0, deviceID: 1
            )
            #expect(p.pressure == raw)
        }
    }

    // Property: tilt is always clamped to -1.0–1.0.
    @Test func tiltClamp() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let rawX = Double.random(in: -10...10, using: &rng)
            let rawY = Double.random(in: -10...10, using: &rng)
            let p = TabletPointParams(
                pressure: 0.5, tiltX: rawX, tiltY: rawY, deviceID: 1
            )
            #expect(p.tiltX >= -1.0 && p.tiltX <= 1.0)
            #expect(p.tiltY >= -1.0 && p.tiltY <= 1.0)
        }
    }

    // Property: in-range tilt is preserved exactly.
    @Test func tiltPreserved() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let rawX = Double.random(in: -1.0...1.0, using: &rng)
            let rawY = Double.random(in: -1.0...1.0, using: &rng)
            let p = TabletPointParams(
                pressure: 0.5, tiltX: rawX, tiltY: rawY, deviceID: 1
            )
            #expect(p.tiltX == rawX)
            #expect(p.tiltY == rawY)
        }
    }

    // Property: deviceID is preserved.
    @Test func deviceIDPreserved() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            let id = Int.random(in: 0...1000, using: &rng)
            let p = TabletPointParams(
                pressure: 0.5, tiltX: 0, tiltY: 0, deviceID: id
            )
            #expect(p.deviceID == id)
        }
    }

    // Property: boundary values clamp correctly.
    @Test func boundaryClamp() {
        let below = TabletPointParams(
            pressure: -0.001, tiltX: -1.001, tiltY: -1.001, deviceID: 1
        )
        #expect(below.pressure == 0.0)
        #expect(below.tiltX == -1.0)
        #expect(below.tiltY == -1.0)

        let above = TabletPointParams(
            pressure: 1.001, tiltX: 1.001, tiltY: 1.001, deviceID: 1
        )
        #expect(above.pressure == 1.0)
        #expect(above.tiltX == 1.0)
        #expect(above.tiltY == 1.0)
    }

    // Property: equality holds for identical values.
    @Test func equality() {
        let a = TabletPointParams(
            pressure: 0.5, tiltX: 0.3, tiltY: -0.2, deviceID: 7
        )
        let b = TabletPointParams(
            pressure: 0.5, tiltX: 0.3, tiltY: -0.2, deviceID: 7
        )
        #expect(a == b)
    }
}

@Suite struct TabletProximityParamsTests {

    // Property: all fields are preserved through init, constants are correct.
    @Test func fieldPreservation() {
        let p = TabletProximityParams(entering: true, deviceID: 42)
        #expect(p.entering == true)
        #expect(p.deviceID == 42)
        #expect(p.pointerType == 1)
        #expect(p.capabilityMask == 0x0587)
        #expect(p.vendorID == 1)
        #expect(p.tabletID == 1)
    }

    // Property: equality holds for identical values.
    @Test func equality() {
        let a = TabletProximityParams(entering: true, deviceID: 1)
        let b = TabletProximityParams(entering: true, deviceID: 1)
        #expect(a == b)
    }

    // Property: entering value is preserved exactly.
    @Test func enteringPreserved() {
        let enter = TabletProximityParams(entering: true, deviceID: 1)
        #expect(enter.entering == true)

        let leave = TabletProximityParams(entering: false, deviceID: 1)
        #expect(leave.entering == false)

        #expect(enter != leave)
    }
}
