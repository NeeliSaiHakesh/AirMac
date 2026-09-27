import Foundation
import CoreGraphics
import Vision

/// Represents an individual 2D joint landmark with normalized coordinates (0...1) and detection confidence.
public struct HandJoint: Sendable, Equatable {
    public let name: VNHumanHandPoseObservation.JointName
    public let point: CGPoint
    public let confidence: Float

    public init(name: VNHumanHandPoseObservation.JointName, point: CGPoint, confidence: Float) {
        self.name = name
        self.point = point
        self.confidence = confidence
    }
}

/// Represents individual finger joint chains for easy geometric analysis.
public struct FingerJoints: Sendable, Equatable {
    public let tip: CGPoint
    public let dip: CGPoint
    public let pip: CGPoint
    public let mcp: CGPoint
    public let confidence: Float

    public init(tip: CGPoint, dip: CGPoint, pip: CGPoint, mcp: CGPoint, confidence: Float) {
        self.tip = tip
        self.dip = dip
        self.pip = pip
        self.mcp = mcp
        self.confidence = confidence
    }

    /// Checks if finger is extended outward relative to palm base / MCP joint
    public func isExtended(wrist: CGPoint) -> Bool {
        let distTipToMcp = tip.distance(to: mcp)
        let distPipToMcp = pip.distance(to: mcp)
        
        // Primary invariant check: fingertip is extended outward beyond PIP knuckle
        if distTipToMcp > 0.035 && distTipToMcp > distPipToMcp * 1.12 {
            return true
        }
        
        // Secondary check using wrist if wrist landmark is detected
        if wrist != .zero {
            let distTip = tip.distance(to: wrist)
            let distPip = pip.distance(to: wrist)
            if distTip > distPip * 1.05 {
                return true
            }
        }
        
        return false
    }
}

/// Aggregated Hand Pose representation containing all 21 keypoints and geometric helpers.
public struct HandPose: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let chirality: VNChirality
    public let confidence: Float
    
    // Key landmarks
    public let wrist: CGPoint
    public let thumb: FingerJoints
    public let index: FingerJoints
    public let middle: FingerJoints
    public let ring: FingerJoints
    public let little: FingerJoints
    
    // Palm Center estimated from wrist + MCPs
    public let palmCenter: CGPoint

    // All raw joints dictionary for rendering
    public let allJoints: [VNHumanHandPoseObservation.JointName: HandJoint]

    public init(
        timestamp: TimeInterval,
        chirality: VNChirality,
        confidence: Float,
        wrist: CGPoint,
        thumb: FingerJoints,
        index: FingerJoints,
        middle: FingerJoints,
        ring: FingerJoints,
        little: FingerJoints,
        palmCenter: CGPoint,
        allJoints: [VNHumanHandPoseObservation.JointName: HandJoint]
    ) {
        self.timestamp = timestamp
        self.chirality = chirality
        self.confidence = confidence
        self.wrist = wrist
        self.thumb = thumb
        self.index = index
        self.middle = middle
        self.ring = ring
        self.little = little
        self.palmCenter = palmCenter
        self.allJoints = allJoints
    }

    /// Number of extended fingers (excluding thumb for simpler counting or including)
    public var extendedFingerCount: Int {
        var count = 0
        if index.isExtended(wrist: wrist) { count += 1 }
        if middle.isExtended(wrist: wrist) { count += 1 }
        if ring.isExtended(wrist: wrist) { count += 1 }
        if little.isExtended(wrist: wrist) { count += 1 }
        return count
    }

    /// Distance between index fingertip and thumb tip (normalized 0...1)
    public var pinchDistance: CGFloat {
        return index.tip.distance(to: thumb.tip)
    }

    /// Distance between middle fingertip and thumb tip
    public var middlePinchDistance: CGFloat {
        return middle.tip.distance(to: thumb.tip)
    }

    /// Hand span width (distance from thumb tip to pinky tip)
    public var handSpan: CGFloat {
        return thumb.tip.distance(to: little.tip)
    }
}

// MARK: - Geometry & CGPoint Extensions
extension CGPoint {
    @inlinable
    public func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    @inlinable
    public func lerp(to target: CGPoint, alpha: CGFloat) -> CGPoint {
        return CGPoint(
            x: x + (target.x - x) * alpha,
            y: y + (target.y - y) * alpha
        )
    }

    @inlinable
    public static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}

extension CGVector {
    @inlinable
    public var magnitude: CGFloat {
        return sqrt(dx * dx + dy * dy)
    }

    @inlinable
    public var normalized: CGVector {
        let mag = magnitude
        return mag > 0.0001 ? CGVector(dx: dx / mag, dy: dy / mag) : .zero
    }
}
