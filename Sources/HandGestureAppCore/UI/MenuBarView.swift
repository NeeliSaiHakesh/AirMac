import SwiftUI

/// Compact Menu Bar Popover offering quick switches, status inspection, and shortcut to Gesture Studio.
public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "hand.wave.fill")
                    .foregroundColor(.accentColor)
                Text("AirMac Gestures")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.isCameraRunning && appState.isTrackingEnabled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }

            Divider()

            // Quick Toggle: Enable Gestures
            Toggle("Enable Gesture Tracking", isOn: $appState.isTrackingEnabled)
                .toggleStyle(.switch)

            // Quick Toggle: System Actions vs Sandbox
            Toggle("Control System Windows", isOn: $appState.enableSystemActions)
                .toggleStyle(.switch)

            // Quick Toggle: Floating Top-Right Overlay
            Toggle("Floating Hand Skeleton HUD", isOn: $appState.showFloatingOverlay)
                .toggleStyle(.switch)

            Divider()

            // Live Performance Quick Stats
            HStack {
                Text("FPS: \(String(format: "%.0f", appState.liveFPS))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Latency: \(String(format: "%.1f ms", appState.inferenceLatencyMs))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Open Full Testing Studio Button
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main-studio")
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Open Gesture Studio & Sandbox")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // Quit App Button
            Button(role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit AirMac")
                }
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(width: 260)
    }
}
