import Foundation

/// Formats EventRecord into tab-separated log lines for observation.
public enum EventFormatter {

    /// Column header line.
    public static func header() -> String {
        [
            "time",
            "category",
            "event",
            "subtype",
            "x",
            "y",
            "mPressure",
            "tPressure",
            "tiltX",
            "tiltY",
        ].joined(separator: "\t")
    }

    /// Format one record as a TSV line.
    public static func format(_ record: EventRecord) -> String {
        let time = String(format: "%.3f", record.timestamp)
        let x = String(format: "%.1f", record.x)
        let y = String(format: "%.1f", record.y)
        let mp = String(format: "%.4f", record.mousePressure)
        let tp = String(format: "%.4f", record.tabletPressure)
        let tx = String(format: "%.4f", record.tiltX)
        let ty = String(format: "%.4f", record.tiltY)
        let sub = EventClassifier.subtypeName(record.subtype)

        return [
            time,
            record.category.rawValue,
            record.eventName,
            sub,
            x,
            y,
            mp,
            tp,
            tx,
            ty,
        ].joined(separator: "\t")
    }
}
