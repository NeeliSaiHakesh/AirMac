import Foundation
import CoreGraphics

/// Detects static discrete hand shapes (Peace sign, Fist, Thumbs Up) with debounce timers.
public final class DiscretePoseDetector: @unchecked Sendable {
    private var lastPose: GestureType?
    private var poseStartTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0

    /// Time in seconds a pose must be steadily held before triggering
    public var holdDuration: TimeInterval = 0.35
    /// Cooldown between discrete triggers
    public var cooldown: TimeInterval = 0.80

    public init() {}

    public func reset() {
        lastPose = nil
        poseStartTime = 0
        lastTriggerTime = 0
    }

    public func process(pose: HandPose) -> GestureType? {
        let now = pose.timestamp
        guard now - lastTriggerTime >= cooldown else { return nil }

        let indexExt = pose.index.isExtended(wrist: pose.wrist)
        let middleExt = pose.middle.isExtended(wrist: pose.wrist)
        let ringExt = pose.ring.isExtended(wrist: pose.wrist)
        let littleExt = pose.little.isExtended(wrist: pose.wrist)
        let thumbDist = pose.thumb.tip.distance(to: pose.wrist)
        let wristMCPDist = pose.wrist.distance(to: pose.index.mcp)

        var detectedCandidate: GestureType? = nil

        // Peace Sign (Index & Middle extended, Ring & Little folded, fingers separated)
        if indexExt && middleExt && !ringExt && !littleExt {
            let fingerSpread = pose.index.tip.distance(to: pose.middle.tip)
            if fingerSpread > 0.08 {
                detectedCandidate = .peaceSign
            }
        }
        // Fist (All 4 fingers folded close to palm)
        else if !indexExt && !middleExt && !ringExt && !littleExt && thumbDist < wristMCPDist * 1.5 {
            detectedCandidate = .fist
        }
        // Thumbs Up (Thumb extended upward, all other fingers curled)
        else if !indexExt && !middleExt && !ringExt && !littleExt && pose.thumb.tip.y < pose.wrist.y - 0.10 {
            detectedCandidate = .thumbsUp
        }

        guard let candidate = detectedCandidate else {
            lastPose = nil
            poseStartTime = 0
            return nil
        }

        if lastPose == candidate {
            if now - poseStartTime >= holdDuration {
                lastTriggerTime = now
                lastPose = nil
                poseStartTime = 0
                return candidate
            }
        } else {
            lastPose = candidate
            poseStartTime = now
        }

        return nil
    }
}
