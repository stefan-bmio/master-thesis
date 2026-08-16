import SwiftUI

struct ContentView: View {
    let initializationState: AppInitializationState

    var body: some View {
        VStack(spacing: 12) {
            Text("app.title")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .accessibilityIdentifier("app.title")

            Text(statusKey)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("app.foundationStatus")
        }
        .padding()
    }

    private var statusKey: LocalizedStringKey {
        switch initializationState {
        case .loading:
            "app.initializing"
        case .ready:
            "app.foundationStatus"
        case .secureStorageFailure:
            "app.secureStorageFailure"
        }
    }
}
