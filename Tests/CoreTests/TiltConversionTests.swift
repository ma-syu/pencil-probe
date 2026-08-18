import Foundation
import Testing
@testable import Core

@Suite struct TiltConversionTests {

    // Perpendicular pen (altitude = π/2) → no tilt.
    @Test func perpendicularGivesZeroTilt() {
        let (tiltX, tiltY) = TiltConversion.toTiltXY(
            altitude: .pi / 2, azimuth: 0
        )
        #expect(abs(tiltX) < 1e-6)
        #expect(abs(tiltY) < 1e-6)
    }

    // Perpendicular pen with any azimuth → still no tilt.
    @Test func perpendicularIgnoresAzimuth() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let azimuth = Float.random(in: 0...(.pi * 2), using: &rng)
            let (tiltX, tiltY) = TiltConversion.toTiltXY(
                altitude: .pi / 2, azimuth: azimuth
            )
            #expect(abs(tiltX) < 1e-6)
            #expect(abs(tiltY) < 1e-6)
        }
    }

    // Flat pen (altitude = 0) → tilt magnitude = 1.
    @Test func parallelGivesFullTilt() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let azimuth = Float.random(in: 0...(.pi * 2), using: &rng)
            let (tiltX, tiltY) = TiltConversion.toTiltXY(
                altitude: 0, azimuth: azimuth
            )
            let magnitude = (tiltX * tiltX + tiltY * tiltY).squareRoot()
            #expect(abs(magnitude - 1.0) < 1e-6)
        }
    }

    // Property: tilt magnitude = cos(altitude) for any input.
    @Test func magnitudeEqualsCosAltitude() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let altitude = Float.random(in: 0...(.pi / 2), using: &rng)
            let azimuth = Float.random(in: 0...(.pi * 2), using: &rng)
            let (tiltX, tiltY) = TiltConversion.toTiltXY(
                altitude: altitude, azimuth: azimuth
            )
            let magnitude = (tiltX * tiltX + tiltY * tiltY).squareRoot()
            let expected = Double(cos(altitude))
            #expect(abs(magnitude - expected) < 1e-5)
        }
    }

    // Azimuth 0 → tilt in +X direction.
    @Test func azimuthZeroPointsPositiveX() {
        let (tiltX, tiltY) = TiltConversion.toTiltXY(
            altitude: 0, azimuth: 0
        )
        #expect(abs(tiltX - 1.0) < 1e-6)
        #expect(abs(tiltY) < 1e-6)
    }

    // Azimuth π/2 → tilt in +Y direction.
    @Test func azimuthHalfPiPointsPositiveY() {
        let (tiltX, tiltY) = TiltConversion.toTiltXY(
            altitude: 0, azimuth: .pi / 2
        )
        #expect(abs(tiltX) < 1e-6)
        #expect(abs(tiltY - 1.0) < 1e-6)
    }

    // Azimuth π → tilt in -X direction.
    @Test func azimuthPiPointsNegativeX() {
        let (tiltX, tiltY) = TiltConversion.toTiltXY(
            altitude: 0, azimuth: .pi
        )
        #expect(abs(tiltX - (-1.0)) < 1e-6)
        #expect(abs(tiltY) < 1e-6)
    }

    // Property: tiltX and tiltY are always in [-1, 1].
    @Test func outputRange() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let altitude = Float.random(in: 0...(.pi / 2), using: &rng)
            let azimuth = Float.random(in: 0...(.pi * 2), using: &rng)
            let (tiltX, tiltY) = TiltConversion.toTiltXY(
                altitude: altitude, azimuth: azimuth
            )
            #expect(tiltX >= -1.0 && tiltX <= 1.0)
            #expect(tiltY >= -1.0 && tiltY <= 1.0)
        }
    }
}
