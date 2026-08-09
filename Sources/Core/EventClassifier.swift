/// Pure functions to classify CGEvent types by their raw UInt32 values.
///
/// Uses raw values instead of importing CoreGraphics, keeping Core
/// free of system framework dependencies.
public enum EventClassifier {

    // CGEventType raw values for mouse events
    private static let mouseTypes: Set<UInt32> = [
        1,  // leftMouseDown
        2,  // leftMouseUp
        3,  // rightMouseDown
        4,  // rightMouseUp
        5,  // mouseMoved
        6,  // leftMouseDragged
        7,  // rightMouseDragged
        25, // otherMouseDown
        26, // otherMouseUp
        27, // otherMouseDragged
    ]

    // CGEventType raw values for tablet events
    private static let tabletTypes: Set<UInt32> = [
        23, // tabletPointer
        24, // tabletProximity
    ]

    /// Classify a CGEventType raw value into a category.
    public static func classify(_ rawValue: UInt32) -> EventCategory {
        if tabletTypes.contains(rawValue) { return .tablet }
        if mouseTypes.contains(rawValue) { return .mouse }
        return .other
    }

    /// Human-readable name for a CGEventType raw value.
    public static func eventName(_ rawValue: UInt32) -> String {
        switch rawValue {
        case 1:  return "leftMouseDown"
        case 2:  return "leftMouseUp"
        case 3:  return "rightMouseDown"
        case 4:  return "rightMouseUp"
        case 5:  return "mouseMoved"
        case 6:  return "leftMouseDragged"
        case 7:  return "rightMouseDragged"
        case 23: return "tabletPointer"
        case 24: return "tabletProximity"
        case 25: return "otherMouseDown"
        case 26: return "otherMouseUp"
        case 27: return "otherMouseDragged"
        default: return "unknown(\(rawValue))"
        }
    }

    /// Human-readable name for a mouse-event subtype value.
    /// CGEventField 9 (kCGMouseEventSubtype).
    public static func subtypeName(_ rawValue: Int64) -> String {
        switch rawValue {
        case 0: return "mouse"
        case 1: return "tabletPoint"
        case 2: return "tabletProximity"
        default: return "unknown(\(rawValue))"
        }
    }
}
