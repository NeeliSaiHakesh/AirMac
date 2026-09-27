import SwiftUI
import Vision

/// Renders a real-time visual skeleton of the tracked hand joints and confidence scores.
public struct CameraOverlayView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background preview backdrop
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))

                if let pose = appState.latestPose {
                    // Hand Skeleton Canvas
                    Canvas { context, size in
                        drawSkeleton(pose: pose, context: &context, size: size)
                    }
                    .drawingGroup() // Metal hardware acceleration
                    
                    // Metadata HUD
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("TRACKING: \(pose.chirality == .left ? "LEFT" : "RIGHT") HAND")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)

                            Spacer()

                            Text(String(format: "CONF: %.0f%%", pose.confidence * 100))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                        .padding(12)

                        Spacer()

                        // Finger Status Bar
                        HStack(spacing: 8) {
                            FingerIndicator(name: "THUMB", isExtended: pose.thumb.tip.distance(to: pose.wrist) > 0.15)
                            FingerIndicator(name: "INDEX", isExtended: pose.index.isExtended(wrist: pose.wrist))
                            FingerIndicator(name: "MID", isExtended: pose.middle.isExtended(wrist: pose.wrist))
                            FingerIndicator(name: "RING", isExtended: pose.ring.isExtended(wrist: pose.wrist))
                            FingerIndicator(name: "PINKY", isExtended: pose.little.isExtended(wrist: pose.wrist))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(8)
                        .padding(.bottom, 12)
                    }
                } else {
                    // Waiting for hand state
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Bring your hand into camera view")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func drawSkeleton(pose: HandPose, context: inout GraphicsContext, size: CGSize) {
        func convert(_ pt: CGPoint) -> CGPoint {
            return CGPoint(
                x: pt.x * size.width,
                y: pt.y * size.height
            )
        }

        let boneColor = Color.cyan.opacity(0.7)
        let jointColor = Color.cyan
        let tipColor = Color.green
        let palmColor = Color.orange

        // Draw finger bones
        func drawBoneChain(_ finger: FingerJoints) {
            var path = Path()
            path.move(to: convert(pose.wrist))
            path.addLine(to: convert(finger.mcp))
            path.addLine(to: convert(finger.pip))
            path.addLine(to: convert(finger.dip))
            path.addLine(to: convert(finger.tip))
            context.stroke(path, with: .color(boneColor), lineWidth: 3)
        }

        drawBoneChain(pose.thumb)
        drawBoneChain(pose.index)
        drawBoneChain(pose.middle)
        drawBoneChain(pose.ring)
        drawBoneChain(pose.little)

        // Draw palm web
        var palmPath = Path()
        palmPath.move(to: convert(pose.wrist))
        palmPath.addLine(to: convert(pose.thumb.mcp))
        palmPath.addLine(to: convert(pose.index.mcp))
        palmPath.addLine(to: convert(pose.middle.mcp))
        palmPath.addLine(to: convert(pose.ring.mcp))
        palmPath.addLine(to: convert(pose.little.mcp))
        palmPath.closeSubpath()
        context.stroke(palmPath, with: .color(boneColor.opacity(0.5)), lineWidth: 2)

        // Draw Joints
        for (_, joint) in pose.allJoints {
            let pt = convert(joint.point)
            let rect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: rect), with: .color(jointColor))
        }

        // Highlight Fingertips
        let tips = [pose.thumb.tip, pose.index.tip, pose.middle.tip, pose.ring.tip, pose.little.tip]
        for tip in tips {
            let pt = convert(tip)
            let rect = CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: rect), with: .color(tipColor))
        }

        // Draw Palm Center
        let palmPt = convert(pose.palmCenter)
        let palmRect = CGRect(x: palmPt.x - 7, y: palmPt.y - 7, width: 14, height: 14)
        context.fill(Path(ellipseIn: palmRect), with: .color(palmColor))
    }
}

private struct FingerIndicator: View {
    let name: String
    let isExtended: Bool

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isExtended ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isExtended ? .white : .secondary)
        }
    }
}
