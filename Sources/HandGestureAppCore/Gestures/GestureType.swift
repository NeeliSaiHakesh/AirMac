import Foundation
import CoreGraphics

/// Categorization of gestures recognized by the engine.
public enum GestureType: Sendable, Equatable, CustomStringConvertible {
    case switchDesktopLeft
    case switchDesktopRight
    case switchTabLeft
    case switchTabRight
    case missionControl
    case showDesktop
    case scroll(dx: CGFloat, dy: CGFloat)
    case cursorMove(point: CGPoint)
    case pinch(state: PinchState, point: CGPoint)
    case peaceSign
    case fist
    case thumbsUp

    public var description: String {
        switch self {
        case .switchDesktopLeft: return "Switch Space Left"
        case .switchDesktopRight: return "Switch Space Right"
        case .switchTabLeft: return "Previous Tab"
        case .switchTabRight: return "Next Tab"
        case .missionControl: return "Mission Control"
        case .showDesktop: return "Show Desktop"
        case .scroll(let dx, let dy): return String(format: "Scroll (dx: %.1f, dy: %.1f)", dx, dy)
        case .cursorMove(let pt): return String(format: "Cursor (%.2f, %.2f)", pt.x, pt.y)
        case .pinch(let state, _): return "Pinch \(state)"
        case .peaceSign: return "Peace Sign"
        case .fist: return "Fist"
        case .thumbsUp: return "Thumbs Up"
        }
    }

    public var icon: String {
        switch self {
        case .switchDesktopLeft: return "arrow.left.to.line"
        case .switchDesktopRight: return "arrow.right.to.line"
        case .switchTabLeft: return "chevron.left.2"
        case .switchTabRight: return "chevron.right.2"
        case .missionControl: return "rectangle.split.3x3"
        case .showDesktop: return "macwindow"
        case .scroll: return "arrow.up.and.down"
        case .cursorMove: return "cursorarrow"
        case .pinch: return "hand.pinch"
        case .peaceSign: return "hand.raised"
        case .fist: return "hand.raised.fill"
        case .thumbsUp: return "hand.thumbsup"
        }
    }
}

public enum PinchState: Sendable, Equatable {
    case start
    case changed
    case ended
}

/// Represents a recognized gesture event with timestamp and confidence.
public struct GestureEvent: Sendable, Equatable {
    public let type: GestureType
    public let timestamp: TimeInterval
    public let confidence: Float

    public init(type: GestureType, timestamp: TimeInterval, confidence: Float) {
        self.type = type
        self.timestamp = timestamp
        self.confidence = confidence
    }
}
