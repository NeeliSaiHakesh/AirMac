import SwiftUI
import AppKit

public struct AirMacApp: App {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some Scene {
        // Main Application Window (Gesture Studio & Sandbox)
        WindowGroup("AirMac Gesture Studio & Calibration", id: "main-studio") {
            GestureTestSandboxView(appState: appState)
                .onAppear {
                    appState.startEngine()
                    Task {
                        await appState.requestPermissions()
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 650)

        // Menu Bar Item
        MenuBarExtra("AirMac Gestures", systemImage: "hand.wave.fill") {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
