import XCTest
import CoreGraphics
import Vision
@testable import HandGestureAppCore

final class ScrollGestureDetectorTests: XCTestCase {
    private func makeOneFingerPose(anchorX: CGFloat, anchorY: CGFloat, timestamp: TimeInterval) -> HandPose {
        let wrist = CGPoint(x: anchorX, y: anchorY + 0.20)
        let makeExtFinger = { (tipX: CGFloat) in
            FingerJoints(
                tip: CGPoint(x: tipX, y: anchorY - 0.10),
                dip: CGPoint(x: tipX, y: anchorY - 0.05),
                pip: CGPoint(x: tipX, y: anchorY),
                mcp: CGPoint(x: tipX, y: anchorY + 0.05),
                confidence: 0.95
            )
        }
        let makeFoldedFinger = { (tipX: CGFloat) in
            FingerJoints(
                tip: CGPoint(x: tipX, y: anchorY + 0.08),
                dip: CGPoint(x: tipX, y: anchorY + 0.07),
                pip: CGPoint(x: tipX, y: anchorY + 0.06),
                mcp: CGPoint(x: tipX, y: anchorY + 0.05),
                confidence: 0.95
            )
        }

        return HandPose(
            timestamp: timestamp,
            chirality: .right,
            confidence: 0.95,
            wrist: wrist,
            thumb: makeFoldedFinger(anchorX - 0.06),
            index: makeExtFinger(anchorX - 0.02),
            middle: makeFoldedFinger(anchorX + 0.02),
            ring: makeFoldedFinger(anchorX + 0.05),
            little: makeFoldedFinger(anchorX + 0.08),
            palmCenter: CGPoint(x: anchorX, y: anchorY + 0.05),
            allJoints: [:]
        )
    }

    func testContinuousNaturalScrollDown() {
        let detector = ScrollGestureDetector()
        var totalScrollDy: CGFloat = 0
        var t: TimeInterval = 1.0

        _ = detector.process(pose: makeOneFingerPose(anchorX: 0.5, anchorY: 0.40, timestamp: t))

        for i in 1...5 {
            t += 0.033
            let y = 0.40 + CGFloat(i) * 0.02
            let pose = makeOneFingerPose(anchorX: 0.5, anchorY: y, timestamp: t)
            if let result = detector.process(pose: pose), case .scroll(_, let dy) = result {
                totalScrollDy += dy
            }
        }

        XCTAssertTrue(totalScrollDy < 0, "Moving finger downwards should scroll down (dy < 0)")
    }

    func testDeadzoneRejection() {
        let detector = ScrollGestureDetector()
        var t: TimeInterval = 1.0

        _ = detector.process(pose: makeOneFingerPose(anchorX: 0.5, anchorY: 0.50, timestamp: t))

        // Tiny movement below deadzone
        t += 0.033
        let result = detector.process(pose: makeOneFingerPose(anchorX: 0.5001, anchorY: 0.5001, timestamp: t))

        XCTAssertNil(result, "Sub-deadzone micro-movements should be filtered")
    }
}

