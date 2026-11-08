import SwiftUI

/// Placeholder for the start animation: a loaf that grows into place.
struct SplashView: View {
    @State private var risen = false

    var body: some View {
        ZStack {
            Color.splashBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "oval.portrait.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96)
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.orange)
                    .scaleEffect(risen ? 1 : 0.5)
                Text("Sourdough")
                    .font(.largeTitle.bold())
                Text("Backen mit Sauerteig")
                    .foregroundStyle(.secondary)
            }
            .opacity(risen ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { risen = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("splash")
    }
}

private extension Color {
    static let splashBackground = Color(.systemBackground)
}

#Preview {
    SplashView()
}
