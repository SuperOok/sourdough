import SwiftUI

extension View {
    /// Sets `now` to the current time every minute, so times shown relative to
    /// it (states, ages) stay current while a screen is open.
    func refreshing(_ now: Binding<Date>) -> some View {
        task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(60)); now.wrappedValue = Date() } }
    }
}
