import Foundation
import CoreGraphics
import Vision
import HandGestureAppCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ FAIL [\(file):\(line)] Expected \(expected), got \(actual). \(message)")
        exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ FAIL [\(file):\(line)] Assertion failed. \(message)")
        exit(1)
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if condition {
        print("❌ FAIL [\(file):\(line)] Expected false but got true. \(message)")
        exit(1)
    }
}

func assertNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) {
    if value != nil {
        print("❌ FAIL [\(file):\(line)] Expected nil but got \(String(describing: value)). \(message)")
        exit(1)
    }
}

func assertNotNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) {
    if value == nil {
        print("❌ FAIL [\(file):\(line)] Expected non-nil value. \(message)")
        exit(1)
    }
}

// Helpers
func makeHandPose(
    indexUp: Bool,
    middleUp: Bool,
    ringUp: Bool,
    littleUp: Bool = false,
    palmX: CGFloat,
    palmY: CGFloat,
    timestamp: TimeInterval
) -> HandPose {
    let wrist = CGPoint(x: palmX, y: palmY + 0.15)
    
    func fingerJoints(isUp: Bool, xOffset: CGFloat) -> FingerJoints {
        let tipY = isUp ? (palmY - 0.12) : (palmY + 0.05)
        let mcpY = palmY
        return FingerJoints(
            tip: CGPoint(x: palmX + xOffset, y: tipY),
            dip: CGPoint(x: palmX + xOffset, y: (tipY + mcpY) / 2),
            pip: CGPoint(x: palmX + xOffset, y: (tipY + mcpY) / 2 + 0.02),
            mcp: CGPoint(x: palmX + xOffset, y: mcpY),
            confidence: 0.95
        )
    }

    let thumb = fingerJoints(isUp: false, xOffset: -0.08)
    let index = fingerJoints(isUp: indexUp, xOffset: -0.03)
    let middle = fingerJoints(isUp: middleUp, xOffset: 0.0)
    let ring = fingerJoints(isUp: ringUp, xOffset: 0.03)
    let little = fingerJoints(isUp: littleUp, xOffset: 0.06)

    return HandPose(
        timestamp: timestamp,
        chirality: .right,
        confidence: 0.95,
        wrist: wrist,
        thumb: thumb,
        index: index,
        middle: middle,
        ring: ring,
        little: little,
        palmCenter: CGPoint(x: palmX, y: palmY),
        allJoints: [:]
    )
}

print("🧪 Starting AirMac Test Suite...")

// MARK: - Test 1: Landmark Smoother Jitter Suppression
print("  ▶️ Testing Landmark Smoother...")
let smoother = LandmarkSmoother(minCutoff: 1.0, beta: 0.05)
let basePoint = CGPoint(x: 0.5, y: 0.5)
var t: TimeInterval = 1.0
_ = smoother.smooth(point: basePoint, joint: .indexTip, timestamp: t)

var maxJitterDisplacement: CGFloat = 0
for i in 1...10 {
    t += 0.033
    let jitteredX = basePoint.x + (i % 2 == 0 ? 0.02 : -0.02)
    let rawPoint = CGPoint(x: jitteredX, y: basePoint.y)
    let smoothed = smoother.smooth(point: rawPoint, joint: .indexTip, timestamp: t)
    let displacement = abs(smoothed.x - basePoint.x)
    maxJitterDisplacement = max(maxJitterDisplacement, displacement)
}
assertTrue(maxJitterDisplacement < 0.01, "Landmark smoother should reduce stationary jitter")
print("    ✅ Landmark Smoother passed")

// MARK: - Test 2: Strict 1-Finger Scrolling
print("  ▶️ Testing Strict 1-Finger Continuous Scroll...")
let scrollDetector = ScrollGestureDetector()
var scrollEvents: [GestureType] = []
t = 1.0

_ = scrollDetector.process(pose: makeHandPose(indexUp: true, middleUp: false, ringUp: false, palmX: 0.5, palmY: 0.40, timestamp: t))

for i in 1...5 {
    t += 0.033
    let y = 0.40 + CGFloat(i) * 0.02
    let pose = makeHandPose(indexUp: true, middleUp: false, ringUp: false, palmX: 0.5, palmY: y, timestamp: t)
    if let result = scrollDetector.process(pose: pose) {
        scrollEvents.append(result)
    }
}

assertTrue(!scrollEvents.isEmpty, "1-finger downward motion must generate scroll events")
if case .scroll(_, let dy) = scrollEvents.first! {
    assertTrue(dy < 0, "Downward movement should scroll down (dy < 0)")
}
print("    ✅ 1-Finger Continuous Scroll passed")

// MARK: - Test 3: Scroll Rejection on Multi-Finger Poses
print("  ▶️ Testing Scroll Rejection for Peace Sign and Open Palm...")
scrollDetector.reset()
let twoFingerPose = makeHandPose(indexUp: true, middleUp: true, ringUp: false, palmX: 0.5, palmY: 0.40, timestamp: 2.0)
assertNil(scrollDetector.process(pose: twoFingerPose), "Scroll detector must reject 2-finger poses")

let openPalmPose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, palmX: 0.5, palmY: 0.40, timestamp: 2.1)
assertNil(scrollDetector.process(pose: openPalmPose), "Scroll detector must reject open palm poses")
print("    ✅ Multi-Finger Scroll Rejection passed")

// MARK: - Test 4: Open Palm Desktop Spaces Swiping
print("  ▶️ Testing Open Palm Desktop Spaces Swiping...")
let swipeDetector = SwipeGestureDetector()
var desktopSwipe: GestureType? = nil
t = 3.0

// Open Palm Swipe Right
for i in 0...5 {
    t += 0.033
    let x = 0.20 + CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, littleUp: true, palmX: x, palmY: 0.5, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        desktopSwipe = result
    }
}
assertEqual(desktopSwipe, .switchDesktopRight, "Open palm swipe right should trigger .switchDesktopRight")

// Open Palm Swipe Left
swipeDetector.reset()
desktopSwipe = nil
t = 4.0
for i in 0...5 {
    t += 0.033
    let x = 0.70 - CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, littleUp: true, palmX: x, palmY: 0.5, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        desktopSwipe = result
    }
}
assertEqual(desktopSwipe, .switchDesktopLeft, "Open palm swipe left should trigger .switchDesktopLeft")
print("    ✅ Open Palm Desktop Spaces Swiping passed")

// MARK: - Test 5: 2-Finger Tab Swiping (Peace Sign)
print("  ▶️ Testing 2-Finger Tab Swiping (Peace Sign)...")
swipeDetector.reset()
var tabSwipe: GestureType? = nil
t = 5.0

// 2 Fingers (Index + Middle extended, Ring + Little folded) Swipe Right
for i in 0...5 {
    t += 0.033
    let x = 0.20 + CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: false, littleUp: false, palmX: x, palmY: 0.5, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        tabSwipe = result
    }
}
assertEqual(tabSwipe, .switchTabRight, "2-Finger swipe right should trigger .switchTabRight")

// 2 Fingers Swipe Left
swipeDetector.reset()
tabSwipe = nil
t = 6.0
for i in 0...5 {
    t += 0.033
    let x = 0.70 - CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: false, littleUp: false, palmX: x, palmY: 0.5, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        tabSwipe = result
    }
}
assertEqual(tabSwipe, .switchTabLeft, "2-Finger swipe left should trigger .switchTabLeft")
print("    ✅ 2-Finger Tab Swiping passed")

// MARK: - Test 6: Vertical Motion Does Not Trigger Mission Control
print("  ▶️ Testing Vertical Motion Rejection (Mission Control Disabled)...")
swipeDetector.reset()
var mcSwipe: GestureType? = nil
t = 7.0

// Upward swipe
for i in 0...5 {
    t += 0.033
    let y = 0.70 - CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, littleUp: true, palmX: 0.5, palmY: y, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        mcSwipe = result
    }
}
assertNil(mcSwipe, "Upward swipe must be ignored so Mission Control never pops up")

// Downward swipe
swipeDetector.reset()
var showDesktopSwipe: GestureType? = nil
t = 8.0
for i in 0...5 {
    t += 0.033
    let y = 0.20 + CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, littleUp: true, palmX: 0.5, palmY: y, timestamp: t)
    if let result = swipeDetector.process(pose: pose) {
        showDesktopSwipe = result
    }
}
assertNil(showDesktopSwipe, "Downward swipe must be ignored")
print("    ✅ Vertical Motion Ignored (Mission Control Disabled) passed")

// MARK: - Test 7: GestureRecognizerEngine Integration & Priority Arbitration
print("  ▶️ Testing GestureRecognizerEngine Pipeline Arbitration...")
let engine = GestureRecognizerEngine()

// 1. Strict 1-finger scrolling
var engineScrollEvents: [GestureType] = []
t = 9.0
for i in 0...5 {
    t += 0.033
    let y = 0.40 + CGFloat(i) * 0.015
    let pose = makeHandPose(indexUp: true, middleUp: false, ringUp: false, littleUp: false, palmX: 0.5, palmY: y, timestamp: t)
    if let event = engine.process(pose: pose) {
        engineScrollEvents.append(event.type)
    }
}
assertTrue(!engineScrollEvents.isEmpty, "Engine should process 1-finger continuous scroll")

// 2. Open palm desktop spaces
engine.reset()
var engineSpaceEvent: GestureType? = nil
t = 10.0
for i in 0...5 {
    t += 0.033
    let x = 0.20 + CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: true, littleUp: true, palmX: x, palmY: 0.5, timestamp: t)
    if let event = engine.process(pose: pose) {
        engineSpaceEvent = event.type
    }
}
assertEqual(engineSpaceEvent, .switchDesktopRight, "Engine should prioritize and trigger desktop space switch")

// 3. Two finger tabs
engine.reset()
var engineTabEvent: GestureType? = nil
t = 11.0
for i in 0...5 {
    t += 0.033
    let x = 0.20 + CGFloat(i) * 0.06
    let pose = makeHandPose(indexUp: true, middleUp: true, ringUp: false, littleUp: false, palmX: x, palmY: 0.5, timestamp: t)
    if let event = engine.process(pose: pose) {
        engineTabEvent = event.type
    }
}
assertEqual(engineTabEvent, .switchTabRight, "Engine should prioritize and trigger tab switch")
print("    ✅ GestureRecognizerEngine Pipeline Arbitration passed")

// MARK: - Test 8: EventSynthesizer Verification
print("  ▶️ Testing EventSynthesizer dispatch...")
let synth = EventSynthesizer.shared
synth.execute(gesture: .scroll(dx: 0, dy: 10))
synth.execute(gesture: .switchTabRight)
synth.execute(gesture: .switchTabLeft)
synth.execute(gesture: .switchDesktopRight)
synth.execute(gesture: .switchDesktopLeft)
synth.execute(gesture: .missionControl)
synth.execute(gesture: .showDesktop)
print("    ✅ EventSynthesizer execution passed")

print("\n🎉 ALL 8 TEST SUITES PASSED SUCCESSFULLY (100% PASS RATE)!")
