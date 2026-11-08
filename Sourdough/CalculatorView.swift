import SwiftUI

struct CalculatorView: View {
    @State private var model = DoughViewModel()

    var body: some View {
        Form {
            Section("Zutaten") {
                field("Mehl (g)", text: $model.flourText, id: "flour-field")
                field("Wasser (g)", text: $model.waterText, id: "water-field")
                field("Anstellgut (g)", text: $model.starterText, id: "starter-field")
            }
            Section("Ergebnis") {
                HStack {
                    Text("Hydration")
                    Spacer()
                    Text(model.hydrationText)
                        .accessibilityIdentifier("hydration-result")
                }
                if !model.isInputValid {
                    Text(DoughViewModel.invalidText)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("input-error")
                }
            }
        }
        .navigationTitle("Dein Teig")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ title: String, text: Binding<String>, id: String) -> some View {
        LabeledContent(title) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }
}

#Preview {
    NavigationStack { CalculatorView() }
}
