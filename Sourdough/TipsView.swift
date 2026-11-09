import SwiftUI
import SourdoughKit

/// The tips and tricks: a table of contents and the pages behind it. Shown as
/// a sheet, so it can be opened from any screen and "Fertig" returns to
/// exactly where the user was. `initial` opens a page directly.
struct TipsView: View {
    @State private var path: [TipsTopic.ID]
    @Environment(\.dismiss) private var dismiss

    init(initial: TipsTopic.ID?) {
        _path = State(initialValue: initial.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(TipsTopic.Category.allCases, id: \.self) { category in
                    Section(category.germanTitle) {
                        ForEach(TipsCatalog.topics(in: category)) { topic in
                            NavigationLink(topic.title, value: topic.id)
                                .accessibilityIdentifier("tips-topic-\(topic.id.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Tipps und Tricks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TipsTopic.ID.self) { id in
                TipsTopicView(topic: TipsCatalog.topic(id), onOpen: { path.append($0) }) {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("tips-close")
                }
            }
        }
    }
}

/// One tips page, drawn from its blocks.
struct TipsTopicView: View {
    let topic: TipsTopic
    /// Called for a `tip:<id>` link in the text.
    let onOpen: (TipsTopic.ID) -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(topic.blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        // Set here and not on the stack: the links live in this page.
        .environment(\.openURL, OpenURLAction { url in
            guard let id = TipsText.topicID(from: url) else { return .systemAction }
            onOpen(id)
            return .handled
        })
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig", action: onClose)
                    .accessibilityIdentifier("tips-topic-close")
            }
        }
    }

    @ViewBuilder
    private func view(for block: TipsBlock) -> some View {
        switch block {
        case .title(let text):
            Text(text).font(.largeTitle.bold())
                .accessibilityIdentifier("tips-title")
        case .heading(let text):
            Text(text).font(.title3.bold()).padding(.top, 8)
        case .paragraph(let text):
            Text(TipsText.attributed(text))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(TipsText.attributed(item))
                    }
                }
            }
        }
    }
}

/// The lightbulb in the toolbar of a screen. Opens the tips as a sheet over
/// the screen; with `topic` straight at that page, otherwise at the contents.
struct TipsButton: View {
    var topic: TipsTopic.ID?
    /// Screens can be stacked (a sheet over a screen that has its own button),
    /// so the equipment form gives its button another identifier.
    var identifier = "tips-button"
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Label("Tipps", systemImage: "lightbulb")
        }
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showing) { TipsView(initial: topic) }
    }
}

/// The small symbol behind an item: opens the tips page of that item as a
/// sheet over the current screen.
struct TipsIconButton: View {
    let topic: TipsTopic.ID
    let identifier: String
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "lightbulb")
        }
        // Without this a whole list row would be the button.
        .buttonStyle(.borderless)
        .accessibilityLabel("Tipps zu \(TipsCatalog.topic(topic).title)")
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showing) { TipsView(initial: topic) }
    }
}

#Preview {
    TipsView(initial: nil)
}
