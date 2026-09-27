import Foundation
import CoreGraphics

/// Detects continuous 1-finger pointing scrolling with smooth sub-pixel tracking.
public final class ScrollGestureDetector: @unchecked Sendable {
    private var lastPosition: CGPoint?
    private var lastTimestamp: TimeInterval = 0

    /// Deadzone movement threshold before initiating scroll (normalized coords)
    public var deadzone: CGFloat = 0.002
    /// Sensitivity multiplier
    public var scrollMultiplier: CGFloat = 120.0

    public init() {}

    public func reset() {
        lastPosition = nil
        lastTimestamp = 0
    }

    /// Evaluates hand pose for continuous 1-finger scrolling deltas.
    public func process(pose: HandPose) -> GestureType? {
        // Strict 1-finger check: only Index finger extended, middle/ring/little folded
        let indexExt = pose.index.isExtended(wrist: pose.wrist)
        let middleExt = pose.middle.isExtended(wrist: pose.wrist)
        let ringExt = pose.ring.isExtended(wrist: pose.wrist)
        let littleExt = pose.little.isExtended(wrist: pose.wrist)

        // If more than 1 finger is extended (e.g. peace sign or open palm), DO NOT scroll!
        guard indexExt, !middleExt, !ringExt, !littleExt else {
            reset()
            return nil
        }

        let anchor = pose.index.tip

        guard let prev = lastPosition else {
            lastPosition = anchor
            lastTimestamp = pose.timestamp
            return nil
        }

        let dt = max(pose.timestamp - lastTimestamp, 0.001)
        lastPosition = anchor
        lastTimestamp = pose.timestamp

        let rawDx = anchor.x - prev.x
        let rawDy = anchor.y - prev.y

        let distance = sqrt(rawDx * rawDx + rawDy * rawDy)
        let velocity = distance / CGFloat(dt)

        // Ignore stationary jitter or excessively fast wild arm movements
        guard distance > deadzone, velocity < 2.5 else {
            return nil
        }

        // Camera coordinate system:
        // Moving hand UP (dy < 0 in Vision coords) -> Scroll UP (dy > 0 in macOS content scroll)
        // Moving hand DOWN (dy > 0 in Vision coords) -> Scroll DOWN (dy < 0 in macOS content scroll)
        let scrollDx = -rawDx * scrollMultiplier
        let scrollDy = -rawDy * scrollMultiplier

        return .scroll(dx: scrollDx, dy: scrollDy)
    }
}

