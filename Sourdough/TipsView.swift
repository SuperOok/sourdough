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
                            NavigationLink(value: topic.id) {
                                Label { Text(topic.title) } icon: {
                                    CustomIcon(name: TipsIcon.name(topic.id))
                                }
                            }
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
                    TipsBlockView(block: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        // Set here and not on the stack: the links live in this page.
        .environment(\.openURL, OpenURLAction { TipsText.open($0, show: onOpen) })
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig", action: onClose)
                    .accessibilityIdentifier("tips-topic-close")
            }
        }
    }
}

/// One block of Markdown, for a tips page or, `compact`, for the
/// instructions of a bake: there titles are headlines and lists are tighter.
struct TipsBlockView: View {
    let block: TipsBlock
    var compact = false

    var body: some View {
        switch block {
        case .title(let text):
            if compact {
                Text(text).font(.headline)
            } else {
                Text(text).font(.largeTitle.bold())
                    .accessibilityIdentifier("tips-title")
            }
        case .heading(let text):
            // Only tips pages have sections; the steps of a bake have none.
            Text(text).font(.title3.bold()).padding(.top, 8)
        case .paragraph(let text):
            Text(TipsText.attributed(text))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: compact ? 4 : 8) {
                        Text("•")
                        // In a list row the text beside the bullet got one
                        // line and an ellipsis; it may grow as tall as it needs.
                        Text(TipsText.attributed(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .image(let name, let caption):
            TipsPicture(name: name, caption: caption)
        case .animation(let animation, let caption):
            TipsAnimationView(animation: animation, caption: caption)
        }
    }
}

/// A photo of a tips page with its caption.
struct TipsPicture: View {
    let name: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: TipsText.picture(named: name))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 280)
                .clipShape(.rect(cornerRadius: 12))
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityIdentifier("tips-image-\(name)")
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
