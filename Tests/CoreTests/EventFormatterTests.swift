import Testing
@testable import Core

@Suite struct EventFormatterTests {

    private func randomRecord(
        using rng: inout SystemRandomNumberGenerator
    ) -> EventRecord {
        let et = UInt32.random(in: 0...255, using: &rng)
        return EventRecord(
            timestamp: Double.random(in: 0...1e9, using: &rng),
            eventType: et,
            subtype: Int64.random(in: -1...10, using: &rng),
            category: EventClassifier.classify(et),
            eventName: EventClassifier.eventName(et),
            x: Double.random(in: -1e4...1e4, using: &rng),
            y: Double.random(in: -1e4...1e4, using: &rng),
            mousePressure: Double.random(in: 0...1, using: &rng),
            tabletPressure: Double.random(in: 0...65535, using: &rng),
            tiltX: Double.random(in: -1...1, using: &rng),
            tiltY: Double.random(in: -1...1, using: &rng)
        )
    }

    // Property: format never returns an empty string.
    @Test func formatNeverEmpty() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let line = EventFormatter.format(randomRecord(using: &rng))
            #expect(!line.isEmpty)
        }
    }

    // Property: output is always a single line (no embedded newlines).
    @Test func formatIsSingleLine() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let line = EventFormatter.format(randomRecord(using: &rng))
            #expect(!line.contains("\n"))
            #expect(!line.contains("\r"))
        }
    }

    // Property: output contains the category name.
    @Test func formatContainsCategory() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let record = randomRecord(using: &rng)
            let line = EventFormatter.format(record)
            #expect(
                line.contains(record.category.rawValue),
                "'\(line)' should contain '\(record.category.rawValue)'"
            )
        }
    }

    // Property: header and format produce the same number of columns.
    @Test func columnCountMatchesHeader() {
        let headerCols = EventFormatter.header()
            .split(separator: "\t", omittingEmptySubsequences: false).count
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let line = EventFormatter.format(randomRecord(using: &rng))
            let cols = line
                .split(separator: "\t", omittingEmptySubsequences: false).count
            #expect(
                cols == headerCols,
                "expected \(headerCols) columns, got \(cols): \(line)"
            )
        }
    }

    @Test func headerIsNonEmpty() {
        #expect(!EventFormatter.header().isEmpty)
    }
}
