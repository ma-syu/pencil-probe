import CoreGraphics
import Core

/// Sets up a CGEventTap to observe mouse and tablet input events.
enum EventTap {

    /// Event types to observe.
    private static let observedTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .mouseMoved,
        .leftMouseDragged, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .tabletPointer, .tabletProximity,
    ]

    /// Build a bitmask from the observed event types.
    private static var eventMask: CGEventMask {
        var mask: CGEventMask = 0
        for t in observedTypes {
            mask |= 1 << CGEventMask(t.rawValue)
        }
        return mask
    }

    /// Extract an EventRecord from a CGEvent.
    static func extractRecord(
        type: CGEventType, event: CGEvent
    ) -> EventRecord {
        let rawType = type.rawValue
        return EventRecord(
            timestamp: Double(event.timestamp),
            eventType: rawType,
            subtype: event.getIntegerValueField(.mouseEventSubtype),
            category: EventClassifier.classify(rawType),
            eventName: EventClassifier.eventName(rawType),
            x: event.location.x,
            y: event.location.y,
            mousePressure: event.getDoubleValueField(.mouseEventPressure),
            tabletPressure: event.getDoubleValueField(.tabletEventPointPressure),
            tiltX: event.getDoubleValueField(.tabletEventTiltX),
            tiltY: event.getDoubleValueField(.tabletEventTiltY)
        )
    }

    /// Create and install the event tap. Returns nil if permission is denied.
    static func create() -> (machPort: CFMachPort, source: CFRunLoopSource)? {
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: tapCallback,
            userInfo: nil
        ) else {
            return nil
        }

        guard let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, tap, 0
        ) else {
            return nil
        }

        return (tap, source)
    }
}

/// C-convention callback for CGEvent.tapCreate.
private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Re-enable the tap if it was disabled due to timeout.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            let tap = Unmanaged<CFMachPort>.fromOpaque(refcon)
                .takeUnretainedValue()
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let record = EventTap.extractRecord(type: type, event: event)
    print(EventFormatter.format(record))

    return Unmanaged.passUnretained(event)
}
