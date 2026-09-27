import Foundation
import CoreMedia
import Vision
import CoreGraphics
import os.log

/// High-performance wrapper around Apple's Vision VNDetectHumanHandPoseRequest.
public final class HandPoseDetector: @unchecked Sendable {
    private let handPoseRequest: VNDetectHumanHandPoseRequest
    private let smoother = LandmarkSmoother()
    private let logger = Logger(subsystem: "com.airmac.gestures", category: "HandPoseDetector")

    public init(maximumHandCount: Int = 1) {
        self.handPoseRequest = VNDetectHumanHandPoseRequest()
        self.handPoseRequest.maximumHandCount = maximumHandCount
    }

    /// Resets tracking history and smoother
    public func reset() {
        smoother.reset()
    }

    /// Processes a CMSampleBuffer or CVPixelBuffer and extracts smoothed HandPose representations.
    public func detect(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, orientation: CGImagePropertyOrientation = .up) -> HandPose? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                smoother.reset()
                return nil
            }

            guard let rawPose = extractHandPose(from: observation, timestamp: timestamp) else {
                smoother.reset()
                return nil
            }

            // Apply adaptive smoothing
            return smoother.smooth(pose: rawPose)
        } catch {
            logger.error("Vision hand pose detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func extractHandPose(from observation: VNHumanHandPoseObservation, timestamp: TimeInterval) -> HandPose? {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return nil
        }

        var allJoints: [VNHumanHandPoseObservation.JointName: HandJoint] = [:]
        var overallConfidenceSum: Float = 0
        var validPointsCount: Float = 0

        for (jointName, point) in recognizedPoints {
            // Only consider points with decent confidence
            // Normalize to User Screen Coordinates: (0,0) Top-Left, (1,1) Bottom-Right
            let pt = CGPoint(
                x: CGFloat(1.0 - point.location.x), // Mirrored for natural user screen direction
                y: CGFloat(1.0 - point.location.y)  // Top-left origin
            )
            allJoints[jointName] = HandJoint(name: jointName, point: pt, confidence: point.confidence)
            overallConfidenceSum += point.confidence
            validPointsCount += 1
        }

        guard validPointsCount >= 5 else { return nil }
        let averageConfidence = overallConfidenceSum / validPointsCount

        func extractFinger(_ tip: VNHumanHandPoseObservation.JointName,
                           _ dip: VNHumanHandPoseObservation.JointName,
                           _ pip: VNHumanHandPoseObservation.JointName,
                           _ mcp: VNHumanHandPoseObservation.JointName) -> FingerJoints {
            let tipPt = allJoints[tip]?.point ?? .zero
            let dipPt = allJoints[dip]?.point ?? .zero
            let pipPt = allJoints[pip]?.point ?? .zero
            let mcpPt = allJoints[mcp]?.point ?? .zero
            let conf = allJoints[tip]?.confidence ?? 0
            return FingerJoints(tip: tipPt, dip: dipPt, pip: pipPt, mcp: mcpPt, confidence: conf)
        }

        let wristPt = allJoints[.wrist]?.point ?? .zero
        let thumb = extractFinger(.thumbTip, .thumbIP, .thumbMP, .thumbCMC)
        let index = extractFinger(.indexTip, .indexDIP, .indexPIP, .indexMCP)
        let middle = extractFinger(.middleTip, .middleDIP, .middlePIP, .middleMCP)
        let ring = extractFinger(.ringTip, .ringDIP, .ringPIP, .ringMCP)
        let little = extractFinger(.littleTip, .littleDIP, .littlePIP, .littleMCP)

        // Robust palm center from MCP knuckles
        let validMcps = [index.mcp, middle.mcp, ring.mcp, little.mcp].filter { $0 != .zero }
        let palmCenter: CGPoint
        if !validMcps.isEmpty {
            let sumX = validMcps.reduce(0.0) { $0 + $1.x }
            let sumY = validMcps.reduce(0.0) { $0 + $1.y }
            palmCenter = CGPoint(x: sumX / CGFloat(validMcps.count), y: sumY / CGFloat(validMcps.count))
        } else {
            palmCenter = wristPt
        }

        return HandPose(
            timestamp: timestamp,
            chirality: observation.chirality,
            confidence: averageConfidence,
            wrist: wristPt,
            thumb: thumb,
            index: index,
            middle: middle,
            ring: ring,
            little: little,
            palmCenter: palmCenter,
            allJoints: allJoints
        )
    }
}
