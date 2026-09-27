import Foundation
import CoreGraphics

/// Master coordinator managing individual gesture detectors, priority arbitration, and output event streams.
public final class GestureRecognizerEngine: @unchecked Sendable {
    public let swipeDetector = SwipeGestureDetector()
    public let scrollDetector = ScrollGestureDetector()
    public let pinchDetector = PinchGestureDetector()
    public let discreteDetector = DiscretePoseDetector()

    public var isSwipeEnabled: Bool = true
    public var isScrollEnabled: Bool = true
    public var isPinchEnabled: Bool = false
    public var isDiscreteEnabled: Bool = true

    public init() {}

    public func reset() {
        swipeDetector.reset()
        scrollDetector.reset()
        pinchDetector.reset()
        discreteDetector.reset()
    }

    /// Evaluates a hand pose and returns any triggered gesture event.
    public func process(pose: HandPose) -> GestureEvent? {
        let now = pose.timestamp

        // 1. Evaluate Dynamic Swipes (Open Palm Spaces / 2-Finger Tabs / Mission Control)
        if isSwipeEnabled, let swipe = swipeDetector.process(pose: pose) {
            scrollDetector.reset()
            pinchDetector.reset()
            return GestureEvent(type: swipe, timestamp: now, confidence: pose.confidence)
        }

        // 2. Strict 1-Finger Continuous Scrolling (Index finger pointing only)
        if pose.extendedFingerCount == 1 && pose.index.isExtended(wrist: pose.wrist) {
            if isScrollEnabled, let scroll = scrollDetector.process(pose: pose) {
                return GestureEvent(type: scroll, timestamp: now, confidence: pose.confidence)
            }
        } else {
            scrollDetector.reset()
        }

        // 3. Pinch Gestures (if enabled)
        if isPinchEnabled, let pinch = pinchDetector.process(pose: pose) {
            return GestureEvent(type: pinch, timestamp: now, confidence: pose.confidence)
        }

        // 4. Discrete Poses (fist, peace, thumbs up)
        if isDiscreteEnabled, let discrete = discreteDetector.process(pose: pose) {
            return GestureEvent(type: discrete, timestamp: now, confidence: pose.confidence)
        }

        return nil
    }
}

