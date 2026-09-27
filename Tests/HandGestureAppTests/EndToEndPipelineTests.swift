import XCTest
import CoreGraphics
import Foundation
import Vision
@testable import HandGestureAppCore

final class EndToEndPipelineTests: XCTestCase {

    private func makeHandPose(
        indexUp: Bool,
        middleUp: Bool,
        ringUp: Bool,
        palmX: CGFloat,
        palmY: CGFloat,
        timestamp: TimeInterval
    ) -> HandPose {
        let wrist = CGPoint(x: palmX, y: palmY + 0.15)
        
        func fingerTip(isUp: Bool, xOffset: CGFloat) -> FingerJoints {
            let tipY = isUp ? (palmY - 0.12) : (palmY + 0.05)
            let mcpY = palmY
            return FingerJoints(
                tip: CGPoint(x: palmX + xOffset, y: tipY),
                dip: CGPoint(x: palmX + xOffset, y: (tipY + mcpY) / 2),
                pip: CGPoint(x: palmX + xOffset, y: (tipY + mcpY) / 2 + 0.02),
                mcp: CGPoint(x: palmX + xOffset, y: mcpY),
                confidence: 0.95
            )
        }

        let thumb = fingerTip(isUp: false, xOffset: -0.08)
        let index = fingerTip(isUp: indexUp, xOffset: -0.03)
        let middle = fingerTip(isUp: middleUp, xOffset: 0.0)
        let ring = fingerTip(isUp: ringUp, xOffset: 0.03)
        let little = fingerTip(isUp: false, xOffset: 0.06)

        return HandPose(
            timestamp: timestamp,
            chirality: .right,
            confidence: 0.95,
            wrist: wrist,
            thumb: thumb,
            index: index,
            middle: middle,
            ring: ring,
            little: little,
            palmCenter: CGPoint(x: palmX, y: palmY),
            allJoints: [:]
        )
    }

    func testOneFingerScroll() {
        let engine = GestureRecognizerEngine()
        var scrollEvents: [GestureType] = []
        var t: TimeInterval = 1.0

        // Move single index finger downwards on screen
        for i in 0...6 {
            t += 0.033
            let y = 0.40 + CGFloat(i) * 0.015
            let pose = makeHandPose(indexUp: true, middleUp: false, ringUp: false, palmX: 0.5, palmY: y, timestamp: t)
            if let event = engine.process(pose: pose) {
                scrollEvents.append(event.type)
            }
        }

        let hasScroll = scrollEvents.contains {
            if case .scroll = $0 { return true }
            return false
        }
        XCTAssertTrue(hasScroll, "Expected 1-finger vertical movement to generate scroll events")
    }

    func testOpenPalmSpaceSwitch() {
        let engine = GestureRecognizerEngine()
        var triggered: GestureType? = nil
        var t: TimeInterval = 1.0

        // Move open palm (all fingers up) to the right
        for i in 0...5 {
            t += 0.033
            let x = 0.20 + CGFloat(i) * 0.06
            let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, palmX: x, palmY: 0.5, timestamp: t)
            if let event = engine.process(pose: pose) {
                triggered = event.type
            }
        }

        XCTAssertEqual(triggered, .switchDesktopRight, "Expected open palm horizontal swipe to trigger desktop space switch")
    }

    func testTwoFingerTabSwitch() {
        let engine = GestureRecognizerEngine()
        var triggered: GestureType? = nil
        var t: TimeInterval = 1.0

        // Move 2 fingers (Index + Middle up, Ring down) to the right
        for i in 0...5 {
            t += 0.033
            let x = 0.20 + CGFloat(i) * 0.06
            let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: false, palmX: x, palmY: 0.5, timestamp: t)
            if let event = engine.process(pose: pose) {
                triggered = event.type
            }
        }

        XCTAssertEqual(triggered, .switchTabRight, "Expected 2-finger horizontal swipe to trigger tab switch")
    }

    func testVerticalMotionIgnored() {
        let engine = GestureRecognizerEngine()
        var triggered: GestureType? = nil
        var t: TimeInterval = 1.0

        // Move open hand upwards
        for i in 0...5 {
            t += 0.033
            let y = 0.70 - CGFloat(i) * 0.06
            let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, palmX: 0.5, palmY: y, timestamp: t)
            if let event = engine.process(pose: pose) {
                triggered = event.type
            }
        }

        XCTAssertNil(triggered, "Expected upward swipe to be ignored (Mission Control disabled)")
    }

    func testEventSynthesizerDispatch() {
        let synth = EventSynthesizer.shared

        // Execute scroll
        synth.execute(gesture: .scroll(dx: 0, dy: 5))

        // Execute Tab Switch
        synth.execute(gesture: .switchTabRight)

        // Execute Space Switch
        synth.execute(gesture: .switchDesktopRight)

        XCTAssertTrue(true, "Event synthesizer executed without crashing")
    }
}

