import Testing
@testable import Core

@Suite struct EventClassifierTests {

    // Property: classify is total — every UInt32 maps to a valid category.
    @Test func classifyIsTotalOverRandomInputs() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<1000 {
            let raw = UInt32.random(in: 0...UInt32.max, using: &rng)
            let cat = EventClassifier.classify(raw)
            #expect(EventCategory.allCases.contains(cat))
        }
    }

    // Property: classify is deterministic.
    @Test func classifyIsDeterministic() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let raw = UInt32.random(in: 0...255, using: &rng)
            #expect(
                EventClassifier.classify(raw)
                    == EventClassifier.classify(raw)
            )
        }
    }

    // Known mouse types always classify as .mouse.
    @Test func knownMouseTypes() {
        let mouseRawValues: [UInt32] = [1, 2, 3, 4, 5, 6, 7, 25, 26, 27]
        for raw in mouseRawValues {
            #expect(
                EventClassifier.classify(raw) == .mouse,
                "raw \(raw) should be .mouse"
            )
        }
    }

    // Known tablet types always classify as .tablet.
    @Test func knownTabletTypes() {
        let tabletRawValues: [UInt32] = [23, 24]
        for raw in tabletRawValues {
            #expect(
                EventClassifier.classify(raw) == .tablet,
                "raw \(raw) should be .tablet"
            )
        }
    }

    // Values outside mouse/tablet sets classify as .other.
    @Test func unknownTypesAreOther() {
        let unknowns: [UInt32] = [0, 8, 22, 28, 100, 255]
        for raw in unknowns {
            #expect(
                EventClassifier.classify(raw) == .other,
                "raw \(raw) should be .other"
            )
        }
    }

    // Property: eventName never returns an empty string.
    @Test func eventNameNeverEmpty() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let raw = UInt32.random(in: 0...UInt32.max, using: &rng)
            #expect(!EventClassifier.eventName(raw).isEmpty)
        }
    }

    // Known types return their expected names.
    @Test func knownEventNames() {
        #expect(EventClassifier.eventName(1) == "leftMouseDown")
        #expect(EventClassifier.eventName(5) == "mouseMoved")
        #expect(EventClassifier.eventName(23) == "tabletPointer")
        #expect(EventClassifier.eventName(24) == "tabletProximity")
    }

    // Unknown types include the raw value in the name.
    @Test func unknownEventNameContainsRawValue() {
        #expect(EventClassifier.eventName(99) == "unknown(99)")
    }

    // Property: subtypeName never returns an empty string.
    @Test func subtypeNameNeverEmpty() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let raw = Int64.random(in: -100...100, using: &rng)
            #expect(!EventClassifier.subtypeName(raw).isEmpty)
        }
    }

    @Test func knownSubtypeNames() {
        #expect(EventClassifier.subtypeName(0) == "mouse")
        #expect(EventClassifier.subtypeName(1) == "tabletPoint")
        #expect(EventClassifier.subtypeName(2) == "tabletProximity")
    }
}
