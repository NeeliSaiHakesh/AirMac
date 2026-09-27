import SwiftUI
import AppKit

/// Ultra-translucent compact floating overlay showing real-time hand skeleton tracking in the top-right corner.
public struct FloatingHandView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            // Translucent glass backdrop
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            if let pose = appState.latestPose {
                // Real-Time Skeleton Canvas
                Canvas { context, size in
                    drawMiniSkeleton(pose: pose, context: &context, size: size)
                }
                .drawingGroup()

                // Header status & close button
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(pose.chirality == .left ? "L HAND" : "R HAND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        Spacer()

                        Button(action: {
                            appState.showFloatingOverlay = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    Spacer()

                    // Triggered Gesture Flash Indicator
                    if let gesture = appState.latestGesture {
                        HStack(spacing: 4) {
                            Image(systemName: gesture.type.icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(gesture.type.description)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.7))
                        .cornerRadius(6)
                        .padding(.bottom, 6)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "hand.wave")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("Hand Tracking")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 180, height: 140)
    }

    private func drawMiniSkeleton(pose: HandPose, context: inout GraphicsContext, size: CGSize) {
        func convert(_ pt: CGPoint) -> CGPoint {
            return CGPoint(
                x: pt.x * (size.width - 24) + 12,
                y: pt.y * (size.height - 30) + 18
            )
        }

        let boneColor = Color.cyan.opacity(0.65)
        let jointColor = Color.cyan
        let tipColor = Color.green
        let palmColor = Color.orange

        func drawChain(_ finger: FingerJoints) {
            var path = Path()
            path.move(to: convert(pose.wrist))
            path.addLine(to: convert(finger.mcp))
            path.addLine(to: convert(finger.pip))
            path.addLine(to: convert(finger.dip))
            path.addLine(to: convert(finger.tip))
            context.stroke(path, with: .color(boneColor), lineWidth: 2)
        }

        drawChain(pose.thumb)
        drawChain(pose.index)
        drawChain(pose.middle)
        drawChain(pose.ring)
        drawChain(pose.little)

        // Draw Joints
        for (_, joint) in pose.allJoints {
            let pt = convert(joint.point)
            let rect = CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: rect), with: .color(jointColor))
        }

        // Highlight Fingertips
        let tips = [pose.thumb.tip, pose.index.tip, pose.middle.tip, pose.ring.tip, pose.little.tip]
        for tip in tips {
            let pt = convert(tip)
            let rect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: rect), with: .color(tipColor))
        }

        // Palm Center
        let palmPt = convert(pose.palmCenter)
        let palmRect = CGRect(x: palmPt.x - 4, y: palmPt.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: palmRect), with: .color(palmColor))
    }
}
