import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("app.title")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .accessibilityIdentifier("app.title")

            Text("app.foundationStatus")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("app.foundationStatus")
        }
        .padding()
    }
}
