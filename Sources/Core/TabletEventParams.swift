/// Parameters for synthesizing a tablet point event via CGEventPost.
///
/// All values use CGEvent-level ranges (0.0–1.0 for pressure,
/// -1.0–1.0 for tilt). The IO layer maps these directly to
/// CGEventSetDoubleValueField calls.
public struct TabletPointParams: Sendable, Equatable {
    /// Pen pressure. 0.0 = no pressure, 1.0 = maximum.
    public let pressure: Double

    /// Horizontal tilt. -1.0 to 1.0.
    public let tiltX: Double

    /// Vertical tilt. -1.0 to 1.0.
    public let tiltY: Double

    /// System-assigned device ID. Must match the proximity event.
    public let deviceID: Int

    public init(pressure: Double, tiltX: Double, tiltY: Double, deviceID: Int) {
        self.pressure = TabletPointParams.clampPressure(pressure)
        self.tiltX = TabletPointParams.clampTilt(tiltX)
        self.tiltY = TabletPointParams.clampTilt(tiltY)
        self.deviceID = deviceID
    }

    static func clampPressure(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    static func clampTilt(_ value: Double) -> Double {
        min(max(value, -1.0), 1.0)
    }
}

/// Parameters for synthesizing a tablet proximity event.
///
/// Proximity events tell apps that a tablet pen has entered or left
/// the tablet's sensing range. Apps use capabilityMask to decide
/// which fields to read from subsequent point events.
public struct TabletProximityParams: Sendable, Equatable {
    /// Whether the pen is entering (vs leaving) proximity.
    public let entering: Bool

    /// System-assigned device ID. Must be consistent with point events.
    public let deviceID: Int

    /// Pointer type: 1 = pen, 3 = eraser (IOLLEvent.h).
    public let pointerType: Int

    /// Bitmask of device capabilities (IOLLEvent.h NX_TABLET_CAPABILITY_*).
    /// Phase 1 minimum: 0x0587 (deviceID, absX, absY, buttons, tiltX, tiltY, pressure).
    public let capabilityMask: UInt32

    /// Vendor ID (typically USB vendor ID). Arbitrary for synthetic events.
    public let vendorID: Int

    /// Tablet ID (typically USB product ID). Arbitrary for synthetic events.
    public let tabletID: Int

    public init(
        entering: Bool,
        deviceID: Int,
        pointerType: Int = 1,
        capabilityMask: UInt32 = 0x0587,
        vendorID: Int = 1,
        tabletID: Int = 1
    ) {
        self.entering = entering
        self.deviceID = deviceID
        self.pointerType = pointerType
        self.capabilityMask = capabilityMask
        self.vendorID = vendorID
        self.tabletID = tabletID
    }
}
