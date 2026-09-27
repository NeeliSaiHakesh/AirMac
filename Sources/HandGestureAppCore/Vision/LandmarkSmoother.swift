import Foundation
import CoreGraphics
import Vision

/// High-performance adaptive low-pass filter (1€ Filter) to eliminate camera jitter while preserving snappy responsiveness.
public final class LandmarkSmoother: @unchecked Sendable {
    private var smoothedJoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    private var smoothedVelocities: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    private var lastTimestamps: [VNHumanHandPoseObservation.JointName: TimeInterval] = [:]

    /// Minimum cutoff frequency (lower = smoother when stationary)
    public var minCutoff: CGFloat = 1.0
    /// Speed coefficient (higher = less lag during fast hand movements)
    public var beta: CGFloat = 1.2
    /// Derivative cutoff frequency
    public var dCutoff: CGFloat = 1.0

    public init(minCutoff: CGFloat = 1.0, beta: CGFloat = 1.2, dCutoff: CGFloat = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    /// Resets all historical filter states when tracking is lost.
    public func reset() {
        smoothedJoints.removeAll()
        smoothedVelocities.removeAll()
        lastTimestamps.removeAll()
    }

    /// Smooths a single CGPoint based on delta time and velocity.
    public func smooth(point: CGPoint, joint: VNHumanHandPoseObservation.JointName, timestamp: TimeInterval) -> CGPoint {
        guard let prevPoint = smoothedJoints[joint], let prevTimestamp = lastTimestamps[joint] else {
            smoothedJoints[joint] = point
            smoothedVelocities[joint] = .zero
            lastTimestamps[joint] = timestamp
            return point
        }

        let dt = max(timestamp - prevTimestamp, 0.001)
        lastTimestamps[joint] = timestamp

        // 1. Calculate raw velocity
        let prevVelocity = smoothedVelocities[joint] ?? .zero
        let rawVelocity = CGPoint(x: (point.x - prevPoint.x) / CGFloat(dt),
                                  y: (point.y - prevPoint.y) / CGFloat(dt))

        // 2. Filter velocity
        let alphaD = alpha(rate: CGFloat(1.0 / dt), cutoff: dCutoff)
        let filteredVelocity = prevVelocity.lerp(to: rawVelocity, alpha: alphaD)
        smoothedVelocities[joint] = filteredVelocity

        // 3. Dynamic cutoff frequency based on velocity magnitude
        let speed = sqrt(filteredVelocity.x * filteredVelocity.x + filteredVelocity.y * filteredVelocity.y)
        let cutoff = minCutoff + beta * speed

        // 4. Filter position
        let alphaP = alpha(rate: CGFloat(1.0 / dt), cutoff: cutoff)
        let smoothedPoint = prevPoint.lerp(to: point, alpha: alphaP)
        smoothedJoints[joint] = smoothedPoint

        return smoothedPoint
    }

    /// Smooths an entire HandPose struct preserving structural integrity
    public func smooth(pose: HandPose) -> HandPose {
        var newJoints: [VNHumanHandPoseObservation.JointName: HandJoint] = [:]
        
        for (name, joint) in pose.allJoints {
            let smoothedPt = smooth(point: joint.point, joint: name, timestamp: pose.timestamp)
            newJoints[name] = HandJoint(name: name, point: smoothedPt, confidence: joint.confidence)
        }

        // Reconstruct fingers
        func makeFinger(_ tip: VNHumanHandPoseObservation.JointName,
                        _ dip: VNHumanHandPoseObservation.JointName,
                        _ pip: VNHumanHandPoseObservation.JointName,
                        _ mcp: VNHumanHandPoseObservation.JointName) -> FingerJoints {
            let tipPt = newJoints[tip]?.point ?? pose.allJoints[tip]?.point ?? .zero
            let dipPt = newJoints[dip]?.point ?? pose.allJoints[dip]?.point ?? .zero
            let pipPt = newJoints[pip]?.point ?? pose.allJoints[pip]?.point ?? .zero
            let mcpPt = newJoints[mcp]?.point ?? pose.allJoints[mcp]?.point ?? .zero
            let conf = newJoints[tip]?.confidence ?? 0
            return FingerJoints(tip: tipPt, dip: dipPt, pip: pipPt, mcp: mcpPt, confidence: conf)
        }

        let wristPt = newJoints[.wrist]?.point ?? pose.wrist
        let thumb = makeFinger(.thumbTip, .thumbIP, .thumbMP, .thumbCMC)
        let index = makeFinger(.indexTip, .indexDIP, .indexPIP, .indexMCP)
        let middle = makeFinger(.middleTip, .middleDIP, .middlePIP, .middleMCP)
        let ring = makeFinger(.ringTip, .ringDIP, .ringPIP, .ringMCP)
        let little = makeFinger(.littleTip, .littleDIP, .littlePIP, .littleMCP)
        
        let palmCenter = CGPoint(
            x: (wristPt.x + index.mcp.x + middle.mcp.x + ring.mcp.x + little.mcp.x) / 5.0,
            y: (wristPt.y + index.mcp.y + middle.mcp.y + ring.mcp.y + little.mcp.y) / 5.0
        )

        return HandPose(
            timestamp: pose.timestamp,
            chirality: pose.chirality,
            confidence: pose.confidence,
            wrist: wristPt,
            thumb: thumb,
            index: index,
            middle: middle,
            ring: ring,
            little: little,
            palmCenter: palmCenter,
            allJoints: newJoints
        )
    }

    private func alpha(rate: CGFloat, cutoff: CGFloat) -> CGFloat {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        let te = 1.0 / rate
        return 1.0 / (1.0 + tau / te)
    }
}
