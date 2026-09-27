import SwiftUI

/// Comprehensive Interactive Testing Studio & Calibration Playground to test all gestures for perfection.
public struct GestureTestSandboxView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private let simulatedDesktops = [
        ("Desktop 1: Code Editor", "chevron.left.forwardslash.chevron.right", Color.blue),
        ("Desktop 2: Safari Web", "safari.fill", Color.purple),
        ("Desktop 3: Design Studio", "paintbrush.fill", Color.orange),
        ("Desktop 4: Terminal", "terminal.fill", Color.green)
    ]

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Content Area (Split: Left Camera & Telemetry / Right Interactive Test Stations)
            HSplitView {
                // Left Panel: Live Skeleton & Telemetry
                leftTelemetryPanel
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)

                // Right Panel: Interactive Gesture Testing Playgrounds
                rightPlaygroundPanel
                    .frame(minWidth: 420)
            }

            Divider()

            // Bottom Status & Permissions Bar
            bottomStatusBar
        }
        .frame(minWidth: 840, minHeight: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: appState.latestGesture) { _, newGesture in
            handleGestureFeedback(newGesture)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.accentColor)

            Text("AirMac Gesture Studio")
                .font(.system(size: 16, weight: .bold))

            Spacer()

            // Mode Toggle: Real System Control vs Sandbox Testing
            Toggle(isOn: $appState.enableSystemActions) {
                HStack(spacing: 4) {
                    Image(systemName: appState.enableSystemActions ? "macwindow.on.rectangle" : "lock.shield.fill")
                        .foregroundColor(appState.enableSystemActions ? .green : .orange)
                    Text(appState.enableSystemActions ? "System Control Active" : "Sandbox Only Mode")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .toggleStyle(.switch)

            // Floating Skeleton HUD Toggle
            Toggle(isOn: $appState.showFloatingOverlay) {
                HStack(spacing: 4) {
                    Image(systemName: "pip.fill")
                        .foregroundColor(appState.showFloatingOverlay ? .cyan : .secondary)
                    Text("Corner HUD")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .toggleStyle(.switch)

            // Tracking Active Toggle
            Button(action: {
                appState.toggleTracking()
            }) {
                Label(appState.isTrackingEnabled ? "Tracking On" : "Paused",
                      systemImage: appState.isTrackingEnabled ? "play.circle.fill" : "pause.circle.fill")
                    .foregroundColor(appState.isTrackingEnabled ? .green : .secondary)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Left Panel (Camera + Joint Stream + Event Log)
    private var leftTelemetryPanel: some View {
        VStack(spacing: 12) {
            // Live Camera Skeleton View
            CameraOverlayView(appState: appState)
                .frame(height: 240)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Live Performance Metrics
            HStack(spacing: 8) {
                MetricCard(title: "LIVE FPS", value: String(format: "%.1f", appState.liveFPS), unit: "fps", color: .green)
                MetricCard(title: "LATENCY", value: String(format: "%.1f", appState.inferenceLatencyMs), unit: "ms", color: .cyan)
                MetricCard(title: "TARGET", value: "\(appState.targetFPS)", unit: "fps", color: .purple)
            }

            // Real-Time Gesture Event Log
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LIVE GESTURE STREAM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(appState.recentGestures.count) captured")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        if appState.recentGestures.isEmpty {
                            Text("No gestures detected yet. Wave in front of camera.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        } else {
                            ForEach(Array(appState.recentGestures.prefix(12).enumerated()), id: \.offset) { index, event in
                                HStack {
                                    Image(systemName: event.type.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(index == 0 ? .green : .secondary)
                                        .frame(width: 18)

                                    Text(event.type.description)
                                        .font(.system(size: 11, weight: index == 0 ? .bold : .regular))
                                        .foregroundColor(index == 0 ? .primary : .secondary)

                                    Spacer()

                                    Text(String(format: "%.0f%%", event.confidence * 100))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(index == 0 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(14)
    }

    // MARK: - Right Panel (Interactive Test Stations)
    private var rightPlaygroundPanel: some View {
        VStack(spacing: 12) {
            // Tab Picker for Test Stations
            Picker("Test Station", selection: $appState.sandboxSelectedTab) {
                Text("Desktop Space Switcher").tag(0)
                Text("Natural 2D Scroller").tag(1)
                Text("Pinch & Cursor").tag(2)
                Text("Sensitivity Tuner").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.top, 12)
            .padding(.horizontal, 14)

            // Active Playground Station
            Group {
                switch appState.sandboxSelectedTab {
                case 0:
                    desktopSwitcherPlayground
                case 1:
                    scrollTestingPlayground
                case 2:
                    pinchTestingPlayground
                case 3:
                    sensitivityTunerPlayground
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Station 1: Desktop Space Switcher Playground
    private var desktopSwitcherPlayground: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Swipe Left / Right in the air to switch simulated desktops")
                    .font(.system(size: 13, weight: .semibold))
                Text("Mapped to native macOS shortcut (^ + Left / Right Arrow)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Virtual Spaces Carousel
            ZStack {
                ForEach(0..<simulatedDesktops.count, id: \.self) { idx in
                    let desktop = simulatedDesktops[idx]
                    let offset = CGFloat(idx - appState.sandboxDesktopIndex) * 320
                    let scale = idx == appState.sandboxDesktopIndex ? 1.0 : 0.85
                    let opacity = idx == appState.sandboxDesktopIndex ? 1.0 : 0.4

                    VStack(spacing: 12) {
                        Image(systemName: desktop.1)
                            .font(.system(size: 44))
                            .foregroundColor(desktop.2)

                        Text(desktop.0)
                            .font(.system(size: 16, weight: .bold))

                        Text("Virtual Space #\(idx + 1)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 280, height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(idx == appState.sandboxDesktopIndex ? 0.2 : 0.05), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(idx == appState.sandboxDesktopIndex ? desktop.2 : Color.gray.opacity(0.2), lineWidth: 2)
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(x: offset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appState.sandboxDesktopIndex)
                }
            }
            .frame(height: 220)

            // Interactive Navigation Indicators
            HStack(spacing: 8) {
                Button(action: { switchDesktop(delta: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)

                ForEach(0..<simulatedDesktops.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == appState.sandboxDesktopIndex ? Color.accentColor : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }

                Button(action: { switchDesktop(delta: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Station 2: Natural 2D Scroll Playground
    private var scrollTestingPlayground: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Two-Finger / Open-Palm Continuous Scroll Test")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Hold two fingers in view and move up/down to test velocity & damping")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(appState.sandboxTestItems, id: \.self) { item in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 10, height: 10)
                            Text(item)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(8)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Station 3: Pinch & Cursor Testing Playground
    private var pinchTestingPlayground: some View {
        VStack(spacing: 12) {
            Text("Pinch Index & Thumb to grab and move objects")
                .font(.system(size: 13, weight: .semibold))

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    // Movable Box
                    VStack(spacing: 6) {
                        Image(systemName: appState.sandboxIsPinching ? "hand.pinch.fill" : "hand.draw")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        Text(appState.sandboxIsPinching ? "PINCHED!" : "Pinch Me")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(appState.sandboxIsPinching ? Color.green : Color.blue)
                            .shadow(radius: appState.sandboxIsPinching ? 12 : 4)
                    )
                    .position(appState.sandboxPinchPosition)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Station 4: Real-Time Sensitivity Tuner
    private var sensitivityTunerPlayground: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Gesture Sensitivity Calibration")
                .font(.system(size: 14, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Swipe Sensitivity (Desktop Switch)")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(String(format: "%.1fx", appState.swipeSensitivity))
                        .font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $appState.swipeSensitivity, in: 0.4...2.5, step: 0.1)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Scroll Speed & Velocity")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(String(format: "%.1fx", appState.scrollSensitivity))
                        .font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $appState.scrollSensitivity, in: 0.4...3.0, step: 0.1)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pinch Threshold")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(String(format: "%.1fx", appState.pinchSensitivity))
                        .font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $appState.pinchSensitivity, in: 0.5...2.0, step: 0.1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Camera Capture Rate")
                    .font(.system(size: 12, weight: .medium))
                Picker("FPS", selection: $appState.targetFPS) {
                    Text("30 FPS (Low Battery Overhead)").tag(30)
                    Text("60 FPS (Ultra Snappy)").tag(60)
                }
                .pickerStyle(.segmented)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Bottom Permissions & Diagnostics Bar
    private var bottomStatusBar: some View {
        HStack(spacing: 16) {
            // Camera Permission Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.isCameraAuthorized ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(appState.isCameraAuthorized ? "Camera Connected" : "Camera Access Required")
                    .font(.system(size: 11))
            }

            // Accessibility Permission Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(appState.isAccessibilityGranted ? "Accessibility Granted" : "Accessibility Needed for macOS Input")
                    .font(.system(size: 11))
            }

            Spacer()

            if !appState.isAccessibilityGranted || !appState.isCameraAuthorized {
                Button("Fix Permissions") {
                    Task {
                        await appState.requestPermissions()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func switchDesktop(delta: Int) {
        let newIdx = appState.sandboxDesktopIndex + delta
        if newIdx >= 0 && newIdx < simulatedDesktops.count {
            appState.sandboxDesktopIndex = newIdx
        }
    }

    private func handleGestureFeedback(_ event: GestureEvent?) {
        guard let event = event, !appState.enableSystemActions else { return }
        switch event.type {
        case .switchDesktopLeft:
            switchDesktop(delta: -1)
        case .switchDesktopRight:
            switchDesktop(delta: 1)
        case .pinch(let state, let point):
            if state == .start || state == .changed {
                appState.sandboxIsPinching = true
                appState.sandboxPinchPosition = CGPoint(x: point.x * 350, y: point.y * 220)
            } else {
                appState.sandboxIsPinching = false
            }
        default:
            break
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
