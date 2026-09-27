import XCTest
import CoreGraphics
import Vision
@testable import HandGestureAppCore

final class PinchGestureDetectorTests: XCTestCase {
    private func makePinchPose(indexTip: CGPoint, thumbTip: CGPoint, timestamp: TimeInterval) -> HandPose {
        let wrist = CGPoint(x: 0.5, y: 0.7)
        let makeFinger = { (tip: CGPoint) in
            FingerJoints(tip: tip, dip: tip, pip: tip, mcp: wrist, confidence: 0.95)
        }

        return HandPose(
            timestamp: timestamp,
            chirality: .right,
            confidence: 0.95,
            wrist: wrist,
            thumb: makeFinger(thumbTip),
            index: makeFinger(indexTip),
            middle: makeFinger(CGPoint(x: 0.6, y: 0.4)),
            ring: makeFinger(CGPoint(x: 0.7, y: 0.5)),
            little: makeFinger(CGPoint(x: 0.8, y: 0.6)),
            palmCenter: CGPoint(x: 0.5, y: 0.5),
            allJoints: [:]
        )
    }

    func testPinchLifecycleTransitions() {
        let detector = PinchGestureDetector()
        var t: TimeInterval = 1.0

        // 1. Far apart (No pinch)
        let farPose = makePinchPose(indexTip: CGPoint(x: 0.4, y: 0.4), thumbTip: CGPoint(x: 0.6, y: 0.4), timestamp: t)
        XCTAssertNil(detector.process(pose: farPose))

        // 2. Bring close (Pinch Start)
        t += 0.033
        let closePose = makePinchPose(indexTip: CGPoint(x: 0.50, y: 0.4), thumbTip: CGPoint(x: 0.52, y: 0.4), timestamp: t)
        let startEvent = detector.process(pose: closePose)
        if case .pinch(let state, _) = startEvent {
            XCTAssertEqual(state, .start)
        } else {
            XCTFail("Expected pinch start event")
        }

        // 3. Move while pinched (Pinch Changed)
        t += 0.033
        let movedPose = makePinchPose(indexTip: CGPoint(x: 0.55, y: 0.45), thumbTip: CGPoint(x: 0.57, y: 0.45), timestamp: t)
        let changeEvent = detector.process(pose: movedPose)
        if case .pinch(let state, _) = changeEvent {
            XCTAssertEqual(state, .changed)
        } else {
            XCTFail("Expected pinch changed event")
        }

        // 4. Release fingers (Pinch Ended)
        t += 0.033
        let releasePose = makePinchPose(indexTip: CGPoint(x: 0.4, y: 0.4), thumbTip: CGPoint(x: 0.6, y: 0.4), timestamp: t)
        let endEvent = detector.process(pose: releasePose)
        if case .pinch(let state, _) = endEvent {
            XCTAssertEqual(state, .ended)
        } else {
            XCTFail("Expected pinch ended event")
        }
    }
}

