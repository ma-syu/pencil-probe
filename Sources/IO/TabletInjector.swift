import CoreGraphics
import Foundation
import Core

/// Injects synthetic tablet events via CGEventPost.
///
/// Follows the synthesis procedure from P0004:
/// 1. Proximity event (enter) — tells apps a tablet pen is present
/// 2. Mouse events with subtype tabletPoint — carries pressure/tilt
/// 3. Proximity event (leave) — signals pen departure
enum TabletInjector {

    /// Post a tablet proximity event (enter or leave).
    static func postProximity(
        _ params: TabletProximityParams,
        at position: CGPoint,
        source: CGEventSource?
    ) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else { return false }

        // Subtype must be set before other fields (CGEvent.h).
        event.setIntegerValueField(
            .mouseEventSubtype,
            value: 2 // kCGEventMouseSubtypeTabletProximity
        )
        event.setIntegerValueField(
            .tabletProximityEventEnterProximity,
            value: params.entering ? 1 : 0
        )
        event.setIntegerValueField(
            .tabletProximityEventPointerType,
            value: Int64(params.pointerType)
        )
        event.setIntegerValueField(
            .tabletProximityEventDeviceID,
            value: Int64(params.deviceID)
        )
        event.setIntegerValueField(
            .tabletProximityEventCapabilityMask,
            value: Int64(params.capabilityMask)
        )
        event.setIntegerValueField(
            .tabletProximityEventVendorID,
            value: Int64(params.vendorID)
        )
        event.setIntegerValueField(
            .tabletProximityEventTabletID,
            value: Int64(params.tabletID)
        )
        event.setIntegerValueField(
            .tabletProximityEventVendorPointerType,
            value: Int64(params.pointerType)
        )
        event.setIntegerValueField(
            .tabletProximityEventPointerID,
            value: Int64(params.deviceID)
        )

        event.post(tap: .cghidEventTap)
        return true
    }

    /// Post a mouse event carrying tablet point data (pressure/tilt).
    static func postTabletPoint(
        _ params: TabletPointParams,
        mouseType: CGEventType,
        at position: CGPoint,
        source: CGEventSource?
    ) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: mouseType,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else { return false }

        // Subtype must be set before other fields (CGEvent.h).
        event.setIntegerValueField(
            .mouseEventSubtype,
            value: 1 // kCGEventMouseSubtypeTabletPoint
        )

        // Set both pressure fields — apps may read either (P0004 §1).
        event.setDoubleValueField(
            .tabletEventPointPressure,
            value: params.pressure
        )
        event.setDoubleValueField(
            .mouseEventPressure,
            value: params.pressure
        )

        event.setDoubleValueField(.tabletEventTiltX, value: params.tiltX)
        event.setDoubleValueField(.tabletEventTiltY, value: params.tiltY)

        event.setIntegerValueField(
            .tabletEventDeviceID,
            value: Int64(params.deviceID)
        )

        event.post(tap: .cghidEventTap)
        return true
    }

    /// Inject a single fixed-pressure stroke: proximity enter,
    /// mouseDown, a few drags, mouseUp, proximity leave.
    ///
    /// Returns true if all events were posted successfully.
    static func injectTestStroke(
        pressure: Double,
        at position: CGPoint
    ) -> Bool {
        let source = CGEventSource(stateID: .privateState)
        let deviceID = 1
        let proximity = TabletProximityParams(
            entering: true, deviceID: deviceID
        )
        let point = TabletPointParams(
            pressure: pressure, tiltX: 0, tiltY: 0, deviceID: deviceID
        )

        // 1. Proximity enter
        guard postProximity(proximity, at: position, source: source)
        else { return false }
        Thread.sleep(forTimeInterval: 0.05)

        // 2. Mouse down with tablet pressure
        guard postTabletPoint(
            point, mouseType: .leftMouseDown,
            at: position, source: source
        ) else { return false }
        Thread.sleep(forTimeInterval: 0.02)

        // 3. Slow drags with visible displacement
        let dragCount = 20
        for i in 1...dragCount {
            let offset = CGFloat(i) * 5.0
            let dragPos = CGPoint(
                x: position.x + offset, y: position.y + offset
            )
            guard postTabletPoint(
                point, mouseType: .leftMouseDragged,
                at: dragPos, source: source
            ) else { return false }
            Thread.sleep(forTimeInterval: 0.02)
        }

        // 4. Mouse up
        let endPos = CGPoint(
            x: position.x + CGFloat(dragCount) * 5.0,
            y: position.y + CGFloat(dragCount) * 5.0
        )
        guard postTabletPoint(
            point, mouseType: .leftMouseUp,
            at: endPos, source: source
        ) else { return false }
        Thread.sleep(forTimeInterval: 0.05)

        // 5. Proximity leave
        let leave = TabletProximityParams(
            entering: false, deviceID: deviceID
        )
        guard postProximity(leave, at: position, source: source)
        else { return false }

        return true
    }
}
