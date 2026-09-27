import Foundation
import CoreGraphics
import AppKit
import os.log

public enum SpaceDirection: Sendable {
    case left
    case right
}

/// Synthesizes native macOS inputs with precise modifier sequencing, AppleScript fallbacks, and cursor-targeted continuous scrolling.
public final class EventSynthesizer: @unchecked Sendable {
    public static let shared = EventSynthesizer()
    private let logger = Logger(subsystem: "com.airmac.gestures", category: "EventSynthesizer")

    // Virtual Key Codes on macOS
    private let kVK_LeftArrow: CGKeyCode = 123
    private let kVK_RightArrow: CGKeyCode = 124
    private let kVK_DownArrow: CGKeyCode = 125
    private let kVK_UpArrow: CGKeyCode = 126
    private let kVK_F3: CGKeyCode = 99
    private let kVK_Tab: CGKeyCode = 48
    private let kVK_Control: CGKeyCode = 59
    private let kVK_Command: CGKeyCode = 55
    private let kVK_Option: CGKeyCode = 58
    private let kVK_Shift: CGKeyCode = 56
    private let kVK_ANSI_RightBracket: CGKeyCode = 30
    private let kVK_ANSI_LeftBracket: CGKeyCode = 33

    // Scroll sub-pixel accumulators
    private var scrollAccumulatorX: CGFloat = 0
    private var scrollAccumulatorY: CGFloat = 0
    private let scrollLock = NSLock()

    private init() {}

    /// Executes a system action corresponding to a recognized GestureType.
    public func execute(gesture: GestureType) {
        switch gesture {
        case .switchDesktopLeft:
            postSpaceSwitch(direction: .left)
            logger.info("Executed: Switch Desktop Left (^ + Left)")

        case .switchDesktopRight:
            postSpaceSwitch(direction: .right)
            logger.info("Executed: Switch Desktop Right (^ + Right)")

        case .switchTabLeft:
            postTabSwitch(isRight: false)
            logger.info("Executed: Switch Tab Left (Ctrl+Shift+Tab / Cmd+Shift+[)")

        case .switchTabRight:
            postTabSwitch(isRight: true)
            logger.info("Executed: Switch Tab Right (Ctrl+Tab / Cmd+Shift+])")

        case .missionControl:
            break

        case .showDesktop:
            break

        case .scroll(let dx, let dy):
            postScroll(dx: dx, dy: dy)

        case .cursorMove(let point):
            postMouseMove(point: point)

        case .pinch(let state, let point):
            postPinchMouse(state: state, point: point)

        case .peaceSign:
            postMediaKey(key: 16)

        case .fist:
            break

        case .thumbsUp:
            break
        }
    }

    // MARK: - Space Switching (Direct WindowServer CGSShowSpaces + Control + Arrow CGEvent)
    public func postSpaceSwitch(direction: SpaceDirection) {
        // 1. First attempt instant direct WindowServer space switch via SkyLight
        let cgsSuccess = SkyLightManager.shared.switchSpace(direction: direction)
        if cgsSuccess {
            logger.info("Executed WindowServer direct CGSShowSpaces switch (\(direction == .right ? "Right" : "Left"))")
        }

        // 2. Also synthesize CGEvent keystroke with Control Modifier for full system and window-manager compatibility
        let arrowKey: CGKeyCode = (direction == .right) ? kVK_RightArrow : kVK_LeftArrow
        let source = CGEventSource(stateID: .hidSystemState)
        let flags: CGEventFlags = .maskControl

        if let modDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: true) {
            modDown.flags = flags
            modDown.post(tap: .cghidEventTap)
            modDown.post(tap: .cgSessionEventTap)
        }

        usleep(15000)

        if let arrowDown = CGEvent(keyboardEventSource: source, virtualKey: arrowKey, keyDown: true) {
            arrowDown.flags = flags
            arrowDown.post(tap: .cghidEventTap)
            arrowDown.post(tap: .cgSessionEventTap)
        }

        usleep(35000)

        if let arrowUp = CGEvent(keyboardEventSource: source, virtualKey: arrowKey, keyDown: false) {
            arrowUp.flags = flags
            arrowUp.post(tap: .cghidEventTap)
            arrowUp.post(tap: .cgSessionEventTap)
        }

        usleep(15000)

        if let modUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: false) {
            modUp.flags = []
            modUp.post(tap: .cghidEventTap)
            modUp.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Tab Switching (Ctrl + Tab / Ctrl + Shift + Tab & Cmd + Shift + [/])
    public func postTabSwitch(isRight: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Post standard Ctrl+Tab or Ctrl+Shift+Tab
        let flags: CGEventFlags = isRight ? .maskControl : [.maskControl, .maskShift]

        if !isRight, let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: true) {
            shiftDown.flags = flags
            shiftDown.post(tap: .cghidEventTap)
            shiftDown.post(tap: .cgSessionEventTap)
        }

        if let ctrlDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: true) {
            ctrlDown.flags = flags
            ctrlDown.post(tap: .cghidEventTap)
            ctrlDown.post(tap: .cgSessionEventTap)
        }

        usleep(15000)

        if let tabDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Tab, keyDown: true),
           let tabUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Tab, keyDown: false) {
            tabDown.flags = flags
            tabUp.flags = flags
            tabDown.post(tap: .cghidEventTap)
            tabDown.post(tap: .cgSessionEventTap)
            usleep(30000)
            tabUp.post(tap: .cghidEventTap)
            tabUp.post(tap: .cgSessionEventTap)
        }

        usleep(15000)

        if let ctrlUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: false) {
            ctrlUp.flags = []
            ctrlUp.post(tap: .cghidEventTap)
            ctrlUp.post(tap: .cgSessionEventTap)
        }

        if !isRight, let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: false) {
            shiftUp.flags = []
            shiftUp.post(tap: .cghidEventTap)
            shiftUp.post(tap: .cgSessionEventTap)
        }

        // Also execute Safari / Chrome shortcut via AppleScript
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptCode = isRight ?
                "tell application \"System Events\" to key code 48 using control down" :
                "tell application \"System Events\" to key code 48 using {control down, shift down}"
            if let script = NSAppleScript(source: scriptCode) {
                var errorInfo: NSDictionary?
                script.executeAndReturnError(&errorInfo)
            }
        }
    }

    // MARK: - Mission Control & Show Desktop
    private func postMissionControl() {
        if let mcURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.exposelauncher") ??
           URL(string: "file:///System/Applications/Mission%20Control.app") {
            NSWorkspace.shared.open(mcURL)
        } else {
            postShortcut(keyCode: kVK_UpArrow, modifierKey: kVK_Control, flags: .maskControl)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let scriptCode = "tell application \"System Events\" to key code 126 using control down"
            if let script = NSAppleScript(source: scriptCode) {
                var errorInfo: NSDictionary?
                script.executeAndReturnError(&errorInfo)
            }
        }
    }

    private func postShowDesktop() {
        postShortcut(keyCode: kVK_F3, modifierKey: kVK_Command, flags: .maskCommand)

        DispatchQueue.global(qos: .userInitiated).async {
            let scriptCode = "tell application \"System Events\" to key code 99 using command down"
            if let script = NSAppleScript(source: scriptCode) {
                var errorInfo: NSDictionary?
                script.executeAndReturnError(&errorInfo)
            }
        }
    }

    private func postShortcut(keyCode: CGKeyCode, modifierKey: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        if let mDown = CGEvent(keyboardEventSource: source, virtualKey: modifierKey, keyDown: true) {
            mDown.flags = flags
            mDown.post(tap: .cghidEventTap)
            mDown.post(tap: .cgSessionEventTap)
        }
        usleep(15000)
        if let kDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            kDown.flags = flags
            kDown.post(tap: .cghidEventTap)
            kDown.post(tap: .cgSessionEventTap)
        }
        usleep(35000)
        if let kUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            kUp.flags = flags
            kUp.post(tap: .cghidEventTap)
            kUp.post(tap: .cgSessionEventTap)
        }
        usleep(15000)
        if let mUp = CGEvent(keyboardEventSource: source, virtualKey: modifierKey, keyDown: false) {
            mUp.flags = []
            mUp.post(tap: .cghidEventTap)
            mUp.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Continuous 2D Scroll Emulation (Targeted directly at cursor location in Safari/macOS)
    public func postScroll(dx: CGFloat, dy: CGFloat) {
        scrollLock.lock()
        defer { scrollLock.unlock() }

        // Accumulate fractional delta across frames
        scrollAccumulatorY += dy * 1.5
        scrollAccumulatorX += dx * 1.5

        let vLines = Int32(scrollAccumulatorY)
        let hLines = Int32(scrollAccumulatorX)

        if vLines != 0 || hLines != 0 {
            scrollAccumulatorY -= CGFloat(vLines)
            scrollAccumulatorX -= CGFloat(hLines)

            // Target the scroll event specifically at the current mouse cursor location
            let cgCursor: CGPoint
            if let evLoc = CGEvent(source: nil)?.location {
                cgCursor = evLoc
            } else {
                let mainScreenHeight = NSScreen.main?.frame.height ?? 900
                cgCursor = CGPoint(x: NSEvent.mouseLocation.x, y: mainScreenHeight - NSEvent.mouseLocation.y)
            }

            // 1. Pixel / continuous scroll event
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: vLines * 12,
                wheel2: hLines * 12,
                wheel3: 0
            ) {
                scrollEvent.location = cgCursor
                scrollEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(vLines * 12))
                scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(hLines * 12))
                scrollEvent.post(tap: .cghidEventTap)
                scrollEvent.post(tap: .cgSessionEventTap)
            }

            // 2. Line scroll event fallback to ensure apps expecting line units (Terminal, legacy WebViews) also scroll
            if let lineScrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 2,
                wheel1: vLines,
                wheel2: hLines,
                wheel3: 0
            ) {
                lineScrollEvent.location = cgCursor
                lineScrollEvent.post(tap: .cghidEventTap)
                lineScrollEvent.post(tap: .cgSessionEventTap)
            }
        }
    }

    // MARK: - Mouse Emulation
    public func postMouseMove(point: CGPoint) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let targetX = point.x * screenRect.width
        let targetY = point.y * screenRect.height
        let screenPoint = CGPoint(x: targetX, y: targetY)

        if let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: screenPoint, mouseButton: .left) {
            mouseEvent.post(tap: .cghidEventTap)
            mouseEvent.post(tap: .cgSessionEventTap)
        }
    }

    public func postPinchMouse(state: PinchState, point: CGPoint) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let targetX = point.x * screenRect.width
        let targetY = point.y * screenRect.height
        let screenPoint = CGPoint(x: targetX, y: targetY)

        let eventType: CGEventType
        switch state {
        case .start:
            eventType = .leftMouseDown
        case .changed:
            eventType = .leftMouseDragged
        case .ended:
            eventType = .leftMouseUp
        }

        if let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: screenPoint, mouseButton: .left) {
            mouseEvent.post(tap: .cghidEventTap)
            mouseEvent.post(tap: .cgSessionEventTap)
        }
    }

    private func postMediaKey(key: Int32) {
        func doKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            if let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                ev.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        doKey(down: true)
        doKey(down: false)
    }
}

// MARK: - SkyLight Private Framework WindowServer Space Manager
private typealias CGSMainConnectionIDFunc = @convention(c) () -> Int32
private typealias SLSCopyManagedDisplaySpacesFunc = @convention(c) (Int32) -> Unmanaged<CFArray>?
private typealias CGSShowSpacesFunc = @convention(c) (Int32, CFArray) -> Void

final class SkyLightManager: @unchecked Sendable {
    static let shared = SkyLightManager()

    private var cgsMainConnectionID: CGSMainConnectionIDFunc?
    private var slsCopyManagedDisplaySpaces: SLSCopyManagedDisplaySpacesFunc?
    private var cgsShowSpaces: CGSShowSpacesFunc?
    private var isLoaded = false

    private init() {
        loadSkyLight()
    }

    private func loadSkyLight() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            return
        }
        if let cidSym = dlsym(handle, "CGSMainConnectionID") {
            cgsMainConnectionID = unsafeBitCast(cidSym, to: CGSMainConnectionIDFunc.self)
        }
        if let copySym = dlsym(handle, "SLSCopyManagedDisplaySpaces") {
            slsCopyManagedDisplaySpaces = unsafeBitCast(copySym, to: SLSCopyManagedDisplaySpacesFunc.self)
        }
        if let showSym = dlsym(handle, "CGSShowSpaces") {
            cgsShowSpaces = unsafeBitCast(showSym, to: CGSShowSpacesFunc.self)
        }
        isLoaded = (cgsMainConnectionID != nil && slsCopyManagedDisplaySpaces != nil && cgsShowSpaces != nil)
    }

    @discardableResult
    func switchSpace(direction: SpaceDirection) -> Bool {
        guard isLoaded,
              let getCID = cgsMainConnectionID,
              let getSpaces = slsCopyManagedDisplaySpaces,
              let showSpaces = cgsShowSpaces else {
            return false
        }

        let cid = getCID()
        guard let unmanagedSpaces = getSpaces(cid) else {
            return false
        }

        let displays = unmanagedSpaces.takeRetainedValue() as NSArray
        guard displays.count > 0 else { return false }

        for displayObj in displays {
            guard let displayDict = displayObj as? [String: Any],
                  let currentSpaceDict = displayDict["Current Space"] as? [String: Any],
                  let currentID = currentSpaceDict["id64"] as? Int64,
                  let spaces = displayDict["Spaces"] as? [[String: Any]] else {
                continue
            }

            let spaceIDs = spaces.compactMap { $0["id64"] as? Int64 }
            guard let currentIndex = spaceIDs.firstIndex(of: currentID) else { continue }

            let targetIndex: Int
            switch direction {
            case .right:
                targetIndex = currentIndex + 1
            case .left:
                targetIndex = currentIndex - 1
            }

            if targetIndex >= 0 && targetIndex < spaceIDs.count {
                let targetSpaceID = spaceIDs[targetIndex]
                let targetArray = [NSNumber(value: targetSpaceID)] as CFArray
                showSpaces(cid, targetArray)
                return true
            }
        }
        return false
    }
}
