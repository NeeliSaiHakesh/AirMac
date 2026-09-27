import Foundation
import AppKit
import AVFoundation

public enum PermissionStatus: Sendable {
    case authorized
    case denied
    case notDetermined
}

public final class AccessibilityPermission: @unchecked Sendable {
    public static let shared = AccessibilityPermission()

    private init() {}

    /// Checks if the app has macOS Accessibility permissions to simulate keystrokes & scroll events.
    public var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    /// Requests accessibility permission and prompts the system dialog if not granted.
    public func requestAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true as CFBoolean] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens macOS System Settings -> Privacy & Security -> Accessibility
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Checks camera permission status
    public var cameraStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Requests camera authorization asynchronously
    public func requestCameraPermission() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Opens macOS System Settings -> Privacy & Security -> Camera
    public func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
