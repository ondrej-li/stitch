import StitchKit
import SwiftUI

/// Stamp sheet: the curated badge set, a quick emoji grid, and a route to the system
/// emoji picker for anything else.
struct StampPickerView: View {
    @Environment(EditorModel.self) private var model

    @State private var customEmoji: String = ""
    @FocusState private var isCustomFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Badges")

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(StampCatalog.badges, id: \.self) { badge in
                    cell(isSelected: model.stampContent == .badge(badge)) {
                        Image(systemName: badge.symbolName)
                            .font(.system(size: 20))
                            .foregroundStyle(Color(badge.color))
                    } action: {
                        select(.badge(badge))
                    }
                    .help(badge.displayName)
                }
            }

            sectionTitle("Emoji")

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(StampCatalog.quickEmoji, id: \.self) { emoji in
                    cell(isSelected: model.stampContent == .emoji(emoji)) {
                        Text(emoji).font(.system(size: 19))
                    } action: {
                        select(.emoji(emoji))
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                TextField("Custom emoji", text: $customEmoji)
                    .textFieldStyle(.roundedBorder)
                    .focused($isCustomFieldFocused)
                    .onSubmit(applyCustomEmoji)
                    .onChange(of: customEmoji) { _, _ in applyCustomEmoji() }

                #if os(macOS)
                Button {
                    isCustomFieldFocused = true
                    // Opens the system Emoji & Symbols palette into the focused field.
                    NSApplication.shared.orderFrontCharacterPalette(nil)
                } label: {
                    Image(systemName: "face.smiling")
                }
                .help("Open the system emoji picker")
                #endif
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func select(_ content: StampContent) {
        model.stampContent = content
        model.select(tool: .stamp)
    }

    private func applyCustomEmoji() {
        let trimmed = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        select(.emoji(trimmed))
    }

    private func cell<Content: View>(
        isSelected: Bool,
        @ViewBuilder content: () -> Content,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            content()
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.raisedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}
