import CoreGraphics
import Foundation

/// One undoable edit expressed as the pixels that changed.
///
/// Storing only the dirty rect keeps history cheap: a stroke on a 5K screenshot costs
/// a few kilobytes instead of another full-size bitmap.
public struct PixelPatch: Sendable {
    /// Integral canvas rect the patch covers.
    public let rect: CGRect
    public let before: [UInt8]
    public let after: [UInt8]

    public init(rect: CGRect, before: [UInt8], after: [UInt8]) {
        self.rect = rect
        self.before = before
        self.after = after
    }

    public var byteCount: Int { before.count + after.count }
}

/// A history step. Most edits are pixel patches; an operation that replaces the whole
/// surface (crop, rotate, flip, loading a new image) stores the two images instead.
///
/// `CGBitmapContext.makeImage()` is copy-on-write, so retaining both images is far
/// cheaper than it looks — the buffer is only duplicated once something writes again.
public enum HistoryEntry {
    case pixels(PixelPatch)
    case canvas(before: CGImage, after: CGImage)

    public var byteCount: Int {
        switch self {
        case let .pixels(patch): patch.byteCount
        case let .canvas(before, after):
            before.bytesPerRow * before.height + after.bytesPerRow * after.height
        }
    }
}

public struct History {
    public private(set) var undoStack: [HistoryEntry] = []
    public private(set) var redoStack: [HistoryEntry] = []

    /// Beyond this many steps the oldest entries are dropped.
    public var limit: Int = 60

    public init(limit: Int = 60) {
        self.limit = limit
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }

    public mutating func push(_ entry: HistoryEntry) {
        undoStack.append(entry)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
    }

    /// Pops the newest undo step, moving it onto the redo stack. The caller applies `before`.
    public mutating func undo() -> HistoryEntry? {
        guard let entry = undoStack.popLast() else { return nil }
        redoStack.append(entry)
        return entry
    }

    /// Pops the newest redo step, moving it back onto the undo stack. The caller applies `after`.
    public mutating func redo() -> HistoryEntry? {
        guard let entry = redoStack.popLast() else { return nil }
        undoStack.append(entry)
        return entry
    }

    public mutating func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    public var byteCount: Int {
        undoStack.reduce(0) { $0 + $1.byteCount } + redoStack.reduce(0) { $0 + $1.byteCount }
    }
}
