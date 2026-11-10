import SwiftUI
// UIKit only for `UITextField`: SwiftUI cannot select a field's text.
import UIKit

/// A form with number fields. Above the decimal pad, which has no return
/// key, "Weiter" moves to the next field and "Fertig" closes the keyboard.
/// The field with the focus scrolls to the middle: at the bottom, the
/// keyboard covered the fields below it and the floating "Fertig" covered
/// the field itself, so a tap meant for the next field hit a key.
struct NumberForm<Content: View>: View {
    /// The identifiers of the number fields on screen, top to bottom.
    let fields: [String]
    @ViewBuilder let content: (FocusState<String?>.Binding) -> Content
    @FocusState private var focus: String?

    var body: some View {
        ScrollViewReader { proxy in
            Form { content($focus) }
                // Room below the last field, so that it too can scroll up to
                // the middle.
                .contentMargins(.bottom, focus == nil ? 0 : 320, for: .scrollContent)
                .onChange(of: focus) { _, id in
                    guard let id else { return }
                    // After the room below is laid out.
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        let next = NumberForm.field(after: focus, in: fields)
                        Button("Weiter") { focus = next }
                            .disabled(next == nil)
                            .accessibilityIdentifier("keyboard-next")
                        Spacer()
                        Button("Fertig") {
                            // Also for a text field outside `fields`, like a name.
                            focus = nil
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                        }
                        .accessibilityIdentifier("keyboard-done")
                    }
                }
        }
    }

    /// The field after `current`; `nil` after the last one or without focus.
    static func field(after current: String?, in fields: [String]) -> String? {
        guard let current, let index = fields.firstIndex(of: current), index + 1 < fields.count else { return nil }
        return fields[index + 1]
    }
}

/// A labelled field for a number of grams, degrees or centimetres, in a
/// visible box so that it stands apart from computed values.
struct NumberField: View {
    let title: String
    @Binding var text: String
    let id: String
    let focus: FocusState<String?>.Binding

    var body: some View {
        LabeledContent(title) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused(focus, equals: id)
                .accessibilityIdentifier(id)
                // Tapping a number selects all of it, so typing replaces it.
                .onReceive(NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification)) { note in
                    DispatchQueue.main.async { (note.object as? UITextField)?.selectAll(nil) }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: 96)
                .background(.fill.tertiary, in: .rect(cornerRadius: 8))
        }
        .id(id)
    }
}
