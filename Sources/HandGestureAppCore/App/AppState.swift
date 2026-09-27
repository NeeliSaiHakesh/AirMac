import Foundation
import SwiftUI
import Combine
import CoreGraphics
import CoreVideo

@MainActor
public final class AppState: ObservableObject, CameraManagerDelegate {
    // Pipeline components
    public let cameraManager = CameraManager()
    public let poseDetector = HandPoseDetector()
    public let gestureEngine = GestureRecognizerEngine()
    public let eventSynthesizer = EventSynthesizer.shared
    public let permissions = AccessibilityPermission.shared

    // Status & Telemetry
    @Published public var isTrackingEnabled: Bool = true
    @Published public var isCameraRunning: Bool = false
    @Published public var enableSystemActions: Bool = true
    @Published public var liveFPS: Double = 0.0
    @Published public var inferenceLatencyMs: Double = 0.0
    @Published public var latestPose: HandPose? = nil
    @Published public var latestGesture: GestureEvent? = nil
    @Published public var recentGestures: [GestureEvent] = []
    
    // Permissions State
    @Published public var isAccessibilityGranted: Bool = false
    @Published public var isCameraAuthorized: Bool = false

    // Sensitivity & Configuration
    @Published public var swipeSensitivity: Double = 1.0 {
        didSet { updateEngineSettings() }
    }
    @Published public var scrollSensitivity: Double = 1.0 {
        didSet { updateEngineSettings() }
    }
    @Published public var pinchSensitivity: Double = 1.0 {
        didSet { updateEngineSettings() }
    }
    @Published public var targetFPS: Int = 30 {
        didSet {
            cameraManager.setupCamera(targetFPS: targetFPS)
        }
    }
    @Published public var showCameraSkeleton: Bool = true
    @Published public var showHUDNotifications: Bool = true
    @Published public var showFloatingOverlay: Bool = true {
        didSet {
            FloatingOverlayController.shared.toggle(show: showFloatingOverlay)
        }
    }

    // Sandbox interactive testing state
    @Published public var sandboxDesktopIndex: Int = 0
    @Published public var sandboxSelectedTab: Int = 0
    @Published public var sandboxPinchPosition: CGPoint = CGPoint(x: 150, y: 150)
    @Published public var sandboxIsPinching: Bool = false
    @Published public var sandboxTestItems: [String] = (1...60).map { "Item #\($0) - Continuous Scroll Test Track" }

    // FPS / Performance tracking
    private var frameCount: Int = 0
    private var lastFPSCheckTime: TimeInterval = 0

    public init() {
        cameraManager.delegate = self
        checkPermissions()
        updateEngineSettings()
        FloatingOverlayController.shared.configure(with: self)
        startEngine()
        Task {
            await requestPermissions()
        }
    }

    public func checkPermissions() {
        isAccessibilityGranted = permissions.isAccessibilityGranted
        isCameraAuthorized = permissions.cameraStatus == .authorized
    }

    public func requestPermissions() async {
        let camResult = await permissions.requestCameraPermission()
        let _ = permissions.requestAccessibilityPermission()
        self.isCameraAuthorized = camResult
        self.isAccessibilityGranted = permissions.isAccessibilityGranted
    }

    public func startEngine() {
        cameraManager.setupCamera(targetFPS: targetFPS)
        cameraManager.start()
        isCameraRunning = true
    }

    public func stopEngine() {
        cameraManager.stop()
        isCameraRunning = false
        latestPose = nil
        latestGesture = nil
    }

    public func toggleTracking() {
        isTrackingEnabled.toggle()
        if !isTrackingEnabled {
            latestPose = nil
            gestureEngine.reset()
        }
    }

    private func updateEngineSettings() {
        gestureEngine.swipeDetector.minDisplacement = CGFloat(0.025 / max(swipeSensitivity, 0.2))
        gestureEngine.swipeDetector.minVelocity = CGFloat(0.06 / max(swipeSensitivity, 0.2))
        gestureEngine.scrollDetector.scrollMultiplier = CGFloat(120.0 * scrollSensitivity)
        gestureEngine.pinchDetector.pinchThreshold = CGFloat(0.055 * pinchSensitivity)
    }

    // MARK: - CameraManagerDelegate (Background Thread Callback)
    nonisolated public func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let detectedPose = poseDetector.detect(in: pixelBuffer, timestamp: timestamp)

        var triggeredGesture: GestureEvent? = nil
        if let pose = detectedPose {
            triggeredGesture = gestureEngine.process(pose: pose)
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.inferenceLatencyMs = latency
            self.trackFPS(timestamp: timestamp)

            if self.isTrackingEnabled {
                self.latestPose = detectedPose

                if let gesture = triggeredGesture {
                    self.latestGesture = gesture
                    self.recentGestures.insert(gesture, at: 0)
                    if self.recentGestures.count > 20 {
                        self.recentGestures.removeLast()
                    }

                    if self.enableSystemActions {
                        self.eventSynthesizer.execute(gesture: gesture.type)
                    }
                }
            } else {
                self.latestPose = nil
            }
        }
    }

    private func trackFPS(timestamp: TimeInterval) {
        frameCount += 1
        if lastFPSCheckTime == 0 {
            lastFPSCheckTime = timestamp
        } else if timestamp - lastFPSCheckTime >= 1.0 {
            liveFPS = Double(frameCount) / (timestamp - lastFPSCheckTime)
            frameCount = 0
            lastFPSCheckTime = timestamp
        }
    }
}
