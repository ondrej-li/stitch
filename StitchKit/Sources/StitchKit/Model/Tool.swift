import Foundation

/// A concrete drawing tool. Several tools share one slot in the toolbar.
public enum ToolID: String, Codable, CaseIterable, Sendable {
    case arrow
    case text
    case rectangle
    case roundedRectangle
    case ellipse
    case line
    case pen
    case highlighter
    case eraser
    case stamp
    case crop

    public var displayName: String {
        switch self {
        case .arrow: "Arrow"
        case .text: "Text"
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded rectangle"
        case .ellipse: "Oval"
        case .line: "Line"
        case .pen: "Marker"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .stamp: "Stamp"
        case .crop: "Crop"
        }
    }

    /// Whether the tool draws freehand strokes that accumulate points.
    public var isFreehand: Bool {
        self == .pen || self == .highlighter || self == .eraser
    }

    /// Whether the tool is defined by two drag points rather than a rect or a path.
    public var isLinear: Bool {
        self == .arrow || self == .line
    }
}

/// A toolbar slot. Slots with more than one tool show the submenu chevron.
public enum ToolGroup: String, Codable, CaseIterable, Sendable {
    case arrow
    case text
    case shape
    case draw
    case stamp
    case crop

    public var tools: [ToolID] {
        switch self {
        case .arrow: [.arrow]
        case .text: [.text]
        case .shape: [.rectangle, .roundedRectangle, .ellipse, .line]
        case .draw: [.pen, .highlighter, .eraser]
        case .stamp: [.stamp]
        case .crop: [.crop]
        }
    }

    public var defaultTool: ToolID { tools[0] }

    public var hasSubmenu: Bool { tools.count > 1 }

    public static func group(for tool: ToolID) -> ToolGroup? {
        allCases.first { $0.tools.contains(tool) }
    }

    public var displayName: String {
        switch self {
        case .arrow: "Arrow"
        case .text: "Text"
        case .shape: "Shapes"
        case .draw: "Marker"
        case .stamp: "Stamps"
        case .crop: "Crop & Rotate"
        }
    }

    /// SF Symbol rendered in the toolbar, chosen to match the reference screenshot.
    public var symbolName: String { symbolName(for: defaultTool) }

    public func symbolName(for tool: ToolID) -> String {
        switch tool {
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .rectangle: "rectangle"
        case .roundedRectangle: "app"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        // The reference uses the "cross" badge itself as the stamp tool's icon.
        case .stamp: "xmark.circle.fill"
        case .crop: "crop"
        }
    }
}
