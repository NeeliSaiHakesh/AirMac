import Foundation
import CoreGraphics

/// Detects dynamic directional swipes (Desktop space switching with 3/4 fingers, Tab switching with 2 fingers).
public final class SwipeGestureDetector: @unchecked Sendable {
    private struct PositionSample {
        let point: CGPoint
        let timestamp: TimeInterval
    }

    private var history: [PositionSample] = []
    private var lastTriggerTime: TimeInterval = 0

    /// Minimum horizontal travel distance (normalized 0...1) within the time window
    public var minDisplacement: CGFloat = 0.025
    /// Minimum velocity (normalized units / second)
    public var minVelocity: CGFloat = 0.06
    /// Time window to evaluate trajectory (seconds)
    public var timeWindow: TimeInterval = 0.45
    /// Minimum interval between triggered swipes to prevent accidental double triggering
    public var cooldown: TimeInterval = 0.30

    public init() {}

    public func reset() {
        history.removeAll()
        lastTriggerTime = 0
    }

    /// Evaluates hand pose stream for swipe gestures.
    public func process(pose: HandPose) -> GestureType? {
        let now = pose.timestamp
        guard now - lastTriggerTime >= cooldown else { return nil }

        let indexExt = pose.index.isExtended(wrist: pose.wrist)
        let middleExt = pose.middle.isExtended(wrist: pose.wrist)
        let ringExt = pose.ring.isExtended(wrist: pose.wrist)
        let littleExt = pose.little.isExtended(wrist: pose.wrist)
        let extCount = pose.extendedFingerCount

        // Prune older samples
        history.removeAll { now - $0.timestamp > timeWindow }

        // Require at least 2 fingers extended to qualify as a swipe
        guard extCount >= 2 || (indexExt && middleExt) || ringExt else {
            return nil
        }

        let sample = PositionSample(point: pose.palmCenter, timestamp: now)
        history.append(sample)

        guard history.count >= 2, let first = history.first else {
            return nil
        }

        let dt = now - first.timestamp
        guard dt >= 0.035 else { return nil }

        let dx = sample.point.x - first.point.x
        let dy = sample.point.y - first.point.y

        let absDx = abs(dx)
        let absDy = abs(dy)
        let velX = absDx / CGFloat(dt)

        // 3 or 4 fingers extended (or open hand)
        let is3Or4Fingers = extCount >= 3 || (indexExt && middleExt && ringExt) || ringExt || littleExt
        // 2 fingers extended (Peace Sign)
        let is2Fingers = extCount == 2 || (indexExt && middleExt && !ringExt && !littleExt)

        // Horizontal Swipes (Desktop Space Switch for 3/4 fingers, Tab Switch for 2 fingers)
        if absDx > minDisplacement && velX > minVelocity && absDx > absDy * 0.60 {
            lastTriggerTime = now
            history.removeAll()
            
            let isMovingRight = dx > 0
            
            if is3Or4Fingers {
                // 3 or 4 fingers trackpad-style swipe -> Desktop Space Switch
                return isMovingRight ? .switchDesktopRight : .switchDesktopLeft
            } else if is2Fingers {
                // 2 fingers -> Browser / App Tab Switch
                return isMovingRight ? .switchTabRight : .switchTabLeft
            }
        }

        return nil
    }
}


