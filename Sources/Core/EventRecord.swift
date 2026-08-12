/// A snapshot of one input event's fields, extracted from CGEvent.
///
/// All fields use raw numeric values so Core has no dependency
/// on CoreGraphics or any other system framework.
public struct EventRecord: Sendable, Equatable {
    /// Mach absolute time converted to seconds since boot.
    public let timestamp: Double

    /// CGEventType raw value.
    public let eventType: UInt32

    /// Mouse-event subtype raw value (CGEventField 9).
    /// 0 = mouse, 1 = tablet point, 2 = tablet proximity.
    public let subtype: Int64

    /// High-level classification derived from eventType.
    public let category: EventCategory

    /// Human-readable name for the event type.
    public let eventName: String

    /// Cursor location in screen coordinates.
    public let x: Double
    public let y: Double

    /// Pressure from kCGMouseEventPressure (field 2). Range 0.0–1.0.
    public let mousePressure: Double

    /// Pressure from kCGTabletEventPointPressure (field 19). Range 0.0–1.0.
    public let tabletPressure: Double

    /// Tilt from kCGTabletEventTiltX / TiltY (fields 20, 21). Range -1.0–1.0.
    public let tiltX: Double
    public let tiltY: Double

    public init(
        timestamp: Double,
        eventType: UInt32,
        subtype: Int64,
        category: EventCategory,
        eventName: String,
        x: Double,
        y: Double,
        mousePressure: Double,
        tabletPressure: Double,
        tiltX: Double,
        tiltY: Double
    ) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.subtype = subtype
        self.category = category
        self.eventName = eventName
        self.x = x
        self.y = y
        self.mousePressure = mousePressure
        self.tabletPressure = tabletPressure
        self.tiltX = tiltX
        self.tiltY = tiltY
    }
}
