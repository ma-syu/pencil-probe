import Testing
@testable import Core

@Suite struct EventCategoryTests {

    @Test func allCasesHaveNonEmptyRawValue() {
        for c in EventCategory.allCases {
            #expect(!c.rawValue.isEmpty)
        }
    }

    @Test func rawValuesAreUnique() {
        let raw = EventCategory.allCases.map(\.rawValue)
        #expect(raw.count == Set(raw).count)
    }

    // Property: every random UInt32 classifies to a member of allCases.
    @Test func classifyAlwaysReturnsMember() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let raw = UInt32.random(in: 0...UInt32.max, using: &rng)
            let cat = EventClassifier.classify(raw)
            #expect(EventCategory.allCases.contains(cat))
        }
    }
}
