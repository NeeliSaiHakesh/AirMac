import XCTest
import CoreGraphics
import Vision
@testable import HandGestureAppCore

final class LandmarkSmootherTests: XCTestCase {
    func testJitterSuppressionWhenStationary() {
        let smoother = LandmarkSmoother(minCutoff: 1.0, beta: 0.05)
        let basePoint = CGPoint(x: 0.5, y: 0.5)
        var t: TimeInterval = 1.0

        _ = smoother.smooth(point: basePoint, joint: .indexTip, timestamp: t)

        var maxJitterDisplacement: CGFloat = 0
        for i in 1...10 {
            t += 0.033
            let jitteredX = basePoint.x + (i % 2 == 0 ? 0.02 : -0.02)
            let rawPoint = CGPoint(x: jitteredX, y: basePoint.y)
            let smoothed = smoother.smooth(point: rawPoint, joint: .indexTip, timestamp: t)
            let displacement = abs(smoothed.x - basePoint.x)
            maxJitterDisplacement = max(maxJitterDisplacement, displacement)
        }

        XCTAssertTrue(maxJitterDisplacement < 0.01)
    }

    func testFastMovementResponsiveness() {
        let smoother = LandmarkSmoother()
        var t: TimeInterval = 1.0

        _ = smoother.smooth(point: CGPoint(x: 0.1, y: 0.5), joint: .wrist, timestamp: t)

        var lastSmoothed = CGPoint.zero
        for i in 1...6 {
            t += 0.033
            let rawX = 0.1 + CGFloat(i) * 0.13
            lastSmoothed = smoother.smooth(point: CGPoint(x: rawX, y: 0.5), joint: .wrist, timestamp: t)
        }

        XCTAssertTrue(lastSmoothed.x > 0.65)
    }
}

