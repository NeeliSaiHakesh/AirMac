import XCTest
import CoreGraphics
import Vision
@testable import HandGestureAppCore

final class SwipeGestureDetectorTests: XCTestCase {
    private func makeOpenPalmPose(palmX: CGFloat, palmY: CGFloat, timestamp: TimeInterval) -> HandPose {
        let wrist = CGPoint(x: palmX, y: palmY + 0.15)
        let makeExtFinger = { (tipX: CGFloat) in
            FingerJoints(
                tip: CGPoint(x: tipX, y: palmY - 0.15),
                dip: CGPoint(x: tipX, y: palmY - 0.10),
                pip: CGPoint(x: tipX, y: palmY - 0.05),
                mcp: CGPoint(x: tipX, y: palmY),
                confidence: 0.95
            )
        }

        return HandPose(
            timestamp: timestamp,
            chirality: .right,
            confidence: 0.95,
            wrist: wrist,
            thumb: makeExtFinger(palmX - 0.12),
            index: makeExtFinger(palmX - 0.05),
            middle: makeExtFinger(palmX),
            ring: makeExtFinger(palmX + 0.05),
            little: makeExtFinger(palmX + 0.10),
            palmCenter: CGPoint(x: palmX, y: palmY),
            allJoints: [:]
        )
    }

    private func makeClosedFistPose(palmX: CGFloat, palmY: CGFloat, timestamp: TimeInterval) -> HandPose {
        let wrist = CGPoint(x: palmX, y: palmY + 0.05)
        let makeFoldedFinger = { (tipX: CGFloat) in
            FingerJoints(
                tip: CGPoint(x: tipX, y: palmY + 0.02),
                dip: CGPoint(x: tipX, y: palmY + 0.01),
                pip: CGPoint(x: tipX, y: palmY - 0.01),
                mcp: CGPoint(x: tipX, y: palmY),
                confidence: 0.95
            )
        }

        return HandPose(
            timestamp: timestamp,
            chirality: .right,
            confidence: 0.95,
            wrist: wrist,
            thumb: makeFoldedFinger(palmX - 0.04),
            index: makeFoldedFinger(palmX - 0.02),
            middle: makeFoldedFinger(palmX),
            ring: makeFoldedFinger(palmX + 0.02),
            little: makeFoldedFinger(palmX + 0.04),
            palmCenter: CGPoint(x: palmX, y: palmY),
            allJoints: [:]
        )
    }

    func testSwipeRightDetection() {
        let detector = SwipeGestureDetector()
        var detected: GestureType? = nil
        var t: TimeInterval = 1.0

        for i in 0...5 {
            t += 0.03
            let x = 0.2 + CGFloat(i) * 0.08
            let pose = makeOpenPalmPose(palmX: x, palmY: 0.5, timestamp: t)
            if let result = detector.process(pose: pose) {
                detected = result
            }
        }

        XCTAssertEqual(detected, .switchDesktopRight)
    }

    func testSwipeLeftDetection() {
        let detector = SwipeGestureDetector()
        var detected: GestureType? = nil
        var t: TimeInterval = 1.0

        for i in 0...5 {
            t += 0.03
            let x = 0.7 - CGFloat(i) * 0.08
            let pose = makeOpenPalmPose(palmX: x, palmY: 0.5, timestamp: t)
            if let result = detector.process(pose: pose) {
                detected = result
            }
        }

        XCTAssertEqual(detected, .switchDesktopLeft)
    }

    func testVerticalSwipeIgnored() {
        let detector = SwipeGestureDetector()
        var detected: GestureType? = nil
        var t: TimeInterval = 1.0

        for i in 0...5 {
            t += 0.03
            let y = 0.7 - CGFloat(i) * 0.08
            let pose = makeOpenPalmPose(palmX: 0.5, palmY: y, timestamp: t)
            if let result = detector.process(pose: pose) {
                detected = result
            }
        }

        XCTAssertNil(detected, "Vertical swipes must be ignored so Mission Control is not triggered")
    }

    func testFalsePositiveRejectionWithClosedFist() {
        let detector = SwipeGestureDetector()
        var detected: GestureType? = nil
        var t: TimeInterval = 1.0

        for i in 0...5 {
            t += 0.03
            let x = 0.2 + CGFloat(i) * 0.08
            let pose = makeClosedFistPose(palmX: x, palmY: 0.5, timestamp: t)
            if let result = detector.process(pose: pose) {
                detected = result
            }
        }

        XCTAssertNil(detected)
    }

    func testCooldownPeriodEnforced() {
        let detector = SwipeGestureDetector()
        var detectionsCount = 0
        var t: TimeInterval = 1.0

        // First swipe
        for i in 0...5 {
            t += 0.03
            let x = 0.2 + CGFloat(i) * 0.08
            let pose = makeOpenPalmPose(palmX: x, palmY: 0.5, timestamp: t)
            if detector.process(pose: pose) != nil {
                detectionsCount += 1
            }
        }

        // Immediate second swipe within 0.1s
        for i in 0...5 {
            t += 0.02
            let x = 0.2 + CGFloat(i) * 0.08
            let pose = makeOpenPalmPose(palmX: x, palmY: 0.5, timestamp: t)
            if detector.process(pose: pose) != nil {
                detectionsCount += 1
            }
        }

        XCTAssertEqual(detectionsCount, 1)
    }
}

