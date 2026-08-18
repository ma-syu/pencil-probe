import Foundation

/// Convert Apple Pencil tilt angles to macOS CGEvent tilt values.
///
/// UITouch provides altitude (angle from surface) and azimuth
/// (direction of tilt). CGEvent expects tiltX/tiltY in [-1, 1],
/// representing the tilt vector projected onto the X and Y axes.
///
/// Why this lives in Core: the conversion is a pure geometric
/// function with no side effects. Keeping it here makes it
/// testable with property tests, independent of CGEvent or UIKit.
public enum TiltConversion {

    /// Convert altitude and azimuth angles to tiltX/tiltY.
    ///
    /// - Parameters:
    ///   - altitude: Angle from the surface plane. 0 = parallel
    ///     (maximum tilt), π/2 = perpendicular (no tilt).
    ///   - azimuth: Direction of tilt from the positive X axis,
    ///     measured in radians (0–2π).
    /// - Returns: (tiltX, tiltY) each in [-1, 1].
    ///
    /// When the pen is perpendicular (altitude = π/2), cos(π/2) ≈ 0,
    /// so tilt is (0, 0) regardless of azimuth. As the pen tilts
    /// toward the surface (altitude → 0), the tilt magnitude grows
    /// and the direction follows azimuth.
    public static func toTiltXY(
        altitude: Float, azimuth: Float
    ) -> (tiltX: Double, tiltY: Double) {
        let magnitude = cos(altitude)
        let tiltX = Double(magnitude * cos(azimuth))
        let tiltY = Double(magnitude * sin(azimuth))
        return (tiltX, tiltY)
    }
}
