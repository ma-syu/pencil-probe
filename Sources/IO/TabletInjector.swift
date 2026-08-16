import CoreGraphics
import Foundation
import Core

/// Injects synthetic tablet events via CGEventPost.
///
/// Why CGEventPost: Virtualization.framework's VZPointerDeviceConfiguration
/// only supports mouse events — there is no API for tablet pressure or
/// tilt. CGEventPost bypasses this limitation by injecting events directly
/// into the macOS event system from within the guest.
///
/// Synthesis procedure (derived from CGEvent.h and IOLLEvent.h):
/// 1. Proximity event (enter) — tells apps a tablet pen is present
/// 2. Mouse events with subtype tabletPoint — carries pressure/tilt
/// 3. Proximity event (leave) — signals pen departure
///
/// Two forms are posted for each event (see postProximity vs
/// postStandaloneProximity) because macOS delivers tablet events
/// through two separate paths. Different apps listen on different
/// paths, so posting both maximizes compatibility.
enum TabletInjector {

    /// Post a tablet proximity event (enter or leave).
    static func postProximity(
        _ params: TabletProximityParams,
        at position: CGPoint,
        source: CGEventSource?
    ) -> Bool {
        guard let event = createMouseEvent(
            at: position, source: source
        ) else { return false }

        // Subtype must be set before other fields (CGEvent.h).
        event.setIntegerValueField(
            .mouseEventSubtype,
            value: 2 // kCGEventMouseSubtypeTabletProximity
        )
        applyProximityFields(params, to: event)

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
        applyPointFields(params, to: event)

        event.post(tap: .cghidEventTap)
        return true
    }

    /// Post a standalone kCGEventTabletPointer event.
    ///
    /// Why a separate "standalone" form: macOS has two tablet delivery
    /// paths. Form (a) is a mouse event with subtype=tabletPoint, which
    /// flows through NSEvent.mouseDown/mouseDragged. Form (b) is a
    /// native kCGEventTabletPointer, which triggers NSView.tabletPoint(with:).
    /// Clip Studio Paint specifically requires form (b) to recognize
    /// pressure. We post both forms for maximum compatibility.
    static func postStandaloneTabletPoint(
        _ params: TabletPointParams,
        at position: CGPoint,
        source: CGEventSource?
    ) -> Bool {
        // Create as mouse event, then change type to tabletPointer.
        // CGEvent has no direct initializer for tablet events.
        guard let event = createMouseEvent(
            at: position, source: source
        ) else { return false }

        event.type = .tabletPointer
        applyPointFields(params, to: event)

        event.post(tap: .cghidEventTap)
        return true
    }

    /// Post a standalone kCGEventTabletProximity event.
    ///
    /// Same two-path reasoning as postStandaloneTabletPoint: some apps
    /// only listen for native kCGEventTabletProximity, not the mouse
    /// event with subtype tabletProximity.
    static func postStandaloneProximity(
        _ params: TabletProximityParams,
        at position: CGPoint,
        source: CGEventSource?
    ) -> Bool {
        guard let event = createMouseEvent(
            at: position, source: source
        ) else { return false }

        event.type = .tabletProximity
        applyProximityFields(params, to: event)

        event.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Private helpers

    private static func createMouseEvent(
        at position: CGPoint, source: CGEventSource?
    ) -> CGEvent? {
        CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: position,
            mouseButton: .left
        )
    }

    private static func applyProximityFields(
        _ params: TabletProximityParams, to event: CGEvent
    ) {
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
    }

    /// Set both pressure fields because apps may read either:
    /// - tabletEventPointPressure: the "official" tablet pressure field
    /// - mouseEventPressure: some apps read this instead, likely
    ///   because NSEvent.pressure maps to it.
    private static func applyPointFields(
        _ params: TabletPointParams, to event: CGEvent
    ) {
        event.setDoubleValueField(
            .tabletEventPointPressure, value: params.pressure
        )
        event.setDoubleValueField(
            .mouseEventPressure, value: params.pressure
        )
        event.setDoubleValueField(.tabletEventTiltX, value: params.tiltX)
        event.setDoubleValueField(.tabletEventTiltY, value: params.tiltY)
        event.setIntegerValueField(
            .tabletEventDeviceID, value: Int64(params.deviceID)
        )
    }

}
