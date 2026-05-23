import AppKit
import SwiftUI

struct PromptUI {
    static func show(for filePath: String, config: Config) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let presets = config.tagPresets
        let history = Tagger.loadHistory()
        // Merge presets + history, presets first
        let allTags = presets + history.filter { !presets.contains($0) }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ssap — Tag Screenshot"
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false

        let viewModel = TagPromptViewModel(
            filePath: filePath,
            availableTags: allTags,
            showDelete: config.deletePrompt,
            window: window
        )

        window.contentView = NSHostingView(rootView: TagPromptView(viewModel: viewModel))
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

class TagPromptViewModel: ObservableObject {
    let filePath: String
    let showDelete: Bool
    weak var window: NSWindow?

    @Published var availableTags: [String]
    @Published var selectedTags: Set<String> = []
    @Published var customTag: String = ""

    init(filePath: String, availableTags: [String], showDelete: Bool, window: NSWindow) {
        self.filePath = filePath
        self.availableTags = availableTags
        self.showDelete = showDelete
        self.window = window
    }

    var filename: String {
        (filePath as NSString).lastPathComponent
    }

    func addCustomTag() {
        let tag = customTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        if !availableTags.contains(tag) {
            availableTags.append(tag)
        }
        selectedTags.insert(tag)
        customTag = ""
    }

    func save() {
        if !selectedTags.isEmpty {
            try? Tagger.applyTags(Array(selectedTags), to: filePath)
        }
        close()
    }

    func skip() {
        close()
    }

    func delete() {
        try? FileManager.default.removeItem(atPath: filePath)
        close()
    }

    private func close() {
        window?.close()
        NSApplication.shared.terminate(nil)
    }
}

struct TagPromptView: View {
    @ObservedObject var viewModel: TagPromptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            if let image = NSImage(contentsOfFile: viewModel.filePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }

            // Filename
            Text(viewModel.filename)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            // Tag selection
            Text("Tags")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(viewModel.availableTags, id: \.self) { tag in
                    TagChip(
                        label: tag,
                        isSelected: viewModel.selectedTags.contains(tag),
                        action: {
                            if viewModel.selectedTags.contains(tag) {
                                viewModel.selectedTags.remove(tag)
                            } else {
                                viewModel.selectedTags.insert(tag)
                            }
                        }
                    )
                }
            }

            // Custom tag input
            HStack {
                TextField("Add custom tag...", text: $viewModel.customTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.addCustomTag() }

                Button("+") { viewModel.addCustomTag() }
                    .disabled(viewModel.customTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            // Action buttons
            HStack {
                if viewModel.showDelete {
                    Button(role: .destructive) {
                        viewModel.delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .keyboardShortcut(.delete, modifiers: .command)
                }

                Spacer()

                Button("Skip") { viewModel.skip() }
                    .keyboardShortcut(.escape, modifiers: [])

                Button("Save") { viewModel.save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

struct TagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Simple flow layout for tag chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
