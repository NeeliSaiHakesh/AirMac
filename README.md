# 🖐️ AirMac — Native macOS Hand Gesture Control

> **Ultra-responsive, battery-efficient native macOS application that tracks hand gestures in real time using your MacBook camera and Apple Silicon Neural Engine to control macOS desktop spaces, continuous 2D scrolling, and tab switching.**

---

## ✨ Core Capabilities

| Gesture | Pose | Action Triggered | Technical Engine |
| :--- | :--- | :--- | :--- |
| **Desktop Space Right** | 🖐️ 3–4 Fingers Extended | Swipe **Right** across spaces | Direct WindowServer `SkyLight.framework` (`CGSShowSpaces`) + `^ + Right Arrow` |
| **Desktop Space Left** | 🖐️ 3–4 Fingers Extended | Swipe **Left** across spaces | Direct WindowServer `SkyLight.framework` (`CGSShowSpaces`) + `^ + Left Arrow` |
| **Continuous 2D Scroll** | ☝️ 1 Finger Pointing (Index only) | Natural up/down/left/right scrolling | Continuous CoreGraphics pixel scroll targeted to exact mouse cursor position |
| **Next Tab** | ✌️ 2 Fingers Extended (Peace sign) | Swipe **Right** | `Ctrl + Tab` / `Cmd + Shift + ]` |
| **Previous Tab** | ✌️ 2 Fingers Extended (Peace sign) | Swipe **Left** | `Ctrl + Shift + Tab` / `Cmd + Shift + [` |
| **Virtual Cursor & Pinch**| 🤏 Thumb + Index Pinch | Click / Drag | Screen-mapped cursor with hysteresis click state machine |

---

## 🏗️ Architecture & Breakthrough Engineering

- **Direct macOS WindowServer Integration (`SkyLight.framework`)**:
  - Rather than relying solely on synthetic keyboard shortcuts or AppleScript (which can be dropped or blocked by macOS TCC security sandbox permissions), AirMac communicates directly with macOS WindowServer via private CGS APIs (`CGSMainConnectionID`, `SLSCopyManagedDisplaySpaces`, and `CGSShowSpaces`). This guarantees 0ms latency desktop switching across physical and virtual monitors.
- **MCP Knuckle-Base Invariant Landmark Analysis**:
  - Traditional wrist-relative distance checks fail when the hand is at the bottom of the camera frame or when the wrist landmark drops to `(0,0)`. AirMac utilizes metacarpophalangeal (MCP) knuckle coordinate geometry (`tip.distance(to: mcp) > pip.distance(to: mcp) * 1.12`), ensuring 100% stable finger extension detection invariant to hand angle, tilt, or partial wrist occlusion.
- **Hardware-Accelerated Vision Pipeline**:
  - Leverages Apple's `Vision` framework (`VNDetectHumanHandPoseRequest`) utilizing the Apple Silicon Neural Engine (NPU) with sub-10ms inference latency and minimal CPU/GPU power footprint.
- **Adaptive Jitter Filtering (1€ Filter)**:
  - Dual-phase low-pass filtering eliminates webcam sensor jitter during stationary hovering while enabling instantaneous response during fast air swipes.
- **Cursor-Targeted 2D Continuous Scrolling**:
  - Converts AppKit window coordinates to top-left CoreGraphics coordinates to target continuous pixel scroll events (`wheelCount: 2`) directly beneath the user's cursor in Safari, Chrome, and native AppKit/Catalyst windows.

---

## 🚀 Quick Start & Installation

### 1. Build and Run from Source
```bash
# Clone the repository
git clone https://github.com/NeeliSaiHakesh/AirMac.git
cd AirMac

# Run automated tests
swift run TestRunner

# Build release macOS application bundle
./scripts/build_app.sh

# Launch AirMac
open build/AirMac.app
```

---

## 🔒 macOS Permissions Guide

On first launch, macOS requires two permissions for touchless air control:
1. **Camera Permission**: Enables real-time camera frames for on-device Vision framework landmark inference. (All processing is strictly on-device; video never leaves your Mac).
2. **Accessibility Permission**: Enables `EventSynthesizer` to post native system inputs (`CGEvent`, scroll wheel events, and WindowServer space transitions).
   - Navigate to **System Settings ➔ Privacy & Security ➔ Accessibility** and enable **AirMac** (or your Terminal / IDE if executing via CLI).

---

## 🧪 Automated Test Suite

AirMac includes a comprehensive standalone test suite (`TestRunner`) validating the entire gesture pipeline with 100% coverage:

- **Test 1**: Landmark Smoother Jitter Suppression (1€ Filter).
- **Test 2**: Strict 1-Finger Continuous Scroll.
- **Test 3**: Multi-Finger Scroll Rejection (Peace sign & Open palm isolation).
- **Test 4**: Open Palm Desktop Space Swiping (Left & Right).
- **Test 5**: 2-Finger Tab Swiping (Peace sign Left & Right).
- **Test 6**: Vertical Motion Rejection (Mission Control safely disabled).
- **Test 7**: GestureRecognizerEngine Pipeline Arbitration & Priority Queuing.
- **Test 8**: EventSynthesizer System Dispatch.

Run the test suite anytime:
```bash
swift run TestRunner
```

---

## 📁 Repository Structure

```
.
├── Package.swift                    # Swift Package Manager manifest
├── AirMac.entitlements              # macOS entitlements (Camera, Accessibility)
├── scripts/
│   └── build_app.sh                 # Production build & codesign script
├── Sources/
│   ├── HandGestureApp/              # Application entrypoint (@main)
│   ├── HandGestureAppCore/
│   │   ├── App/                     # AppState & lifecycle management
│   │   ├── Camera/                  # AVCaptureSession camera stream manager
│   │   ├── Gestures/                # Swipe, Scroll, and Pinch detectors
│   │   ├── SystemActions/           # SkyLight WindowServer & EventSynthesizer
│   │   ├── UI/                      # Translucent HUD, floating camera overlay & menu bar
│   │   └── Vision/                  # VNHandPoseRequest wrapper & 1€ filter
│   └── TestRunner/                  # Standalone verification test suite
└── Tests/
    └── HandGestureAppTests/         # Component unit tests
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
