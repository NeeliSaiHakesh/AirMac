import Foundation
import CoreGraphics

/// Detects pinch gestures (Index-Thumb pinch) for mouse click, drag, or precision controls.
public final class PinchGestureDetector: @unchecked Sendable {
    private var isPinched: Bool = false
    private var lastPinchTime: TimeInterval = 0

    /// Pinch threshold distance (normalized 0...1)
    public var pinchThreshold: CGFloat = 0.055
    /// Release threshold distance (with hysteresis to avoid oscillation)
    public var releaseThreshold: CGFloat = 0.080

    public init() {}

    public func reset() {
        isPinched = false
        lastPinchTime = 0
    }

    /// Evaluates hand pose for pinch state transitions
    public func process(pose: HandPose) -> GestureType? {
        let pinchDist = pose.pinchDistance
        let anchor = CGPoint(
            x: (pose.index.tip.x + pose.thumb.tip.x) / 2.0,
            y: (pose.index.tip.y + pose.thumb.tip.y) / 2.0
        )

        if !isPinched && pinchDist < pinchThreshold {
            isPinched = true
            lastPinchTime = pose.timestamp
            return .pinch(state: .start, point: anchor)
        } else if isPinched && pinchDist > releaseThreshold {
            isPinched = false
            return .pinch(state: .ended, point: anchor)
        } else if isPinched {
            return .pinch(state: .changed, point: anchor)
        }

        return nil
    }
}
