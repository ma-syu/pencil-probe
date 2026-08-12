import Testing
@testable import Core

@Suite struct EventRecordTests {

    // Property: all fields round-trip through init unchanged.
    @Test func fieldPreservation() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            let ts = Double.random(in: 0...1e9, using: &rng)
            let et = UInt32.random(in: 0...255, using: &rng)
            let sub = Int64.random(in: -1...10, using: &rng)
            let cat = EventClassifier.classify(et)
            let name = EventClassifier.eventName(et)
            let x = Double.random(in: -1e4...1e4, using: &rng)
            let y = Double.random(in: -1e4...1e4, using: &rng)
            let mp = Double.random(in: 0...1, using: &rng)
            let tp = Double.random(in: 0...1, using: &rng)
            let tx = Double.random(in: -1...1, using: &rng)
            let ty = Double.random(in: -1...1, using: &rng)

            let r = EventRecord(
                timestamp: ts, eventType: et, subtype: sub,
                category: cat, eventName: name,
                x: x, y: y,
                mousePressure: mp, tabletPressure: tp,
                tiltX: tx, tiltY: ty
            )

            #expect(r.timestamp == ts)
            #expect(r.eventType == et)
            #expect(r.subtype == sub)
            #expect(r.category == cat)
            #expect(r.eventName == name)
            #expect(r.x == x)
            #expect(r.y == y)
            #expect(r.mousePressure == mp)
            #expect(r.tabletPressure == tp)
            #expect(r.tiltX == tx)
            #expect(r.tiltY == ty)
        }
    }

    // Property: two records with identical fields are equal.
    @Test func equality() {
        let a = EventRecord(
            timestamp: 1.0, eventType: 5, subtype: 0,
            category: .mouse, eventName: "mouseMoved",
            x: 100, y: 200,
            mousePressure: 0.5, tabletPressure: 0,
            tiltX: 0, tiltY: 0
        )
        let b = EventRecord(
            timestamp: 1.0, eventType: 5, subtype: 0,
            category: .mouse, eventName: "mouseMoved",
            x: 100, y: 200,
            mousePressure: 0.5, tabletPressure: 0,
            tiltX: 0, tiltY: 0
        )
        #expect(a == b)
    }
}
