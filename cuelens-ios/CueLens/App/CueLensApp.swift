import SwiftUI

@main
struct CueLensApp: App {
    @State private var appModel = CueLensAppModel(
        persistence: LiveLocalPersistenceBootstrap()
    )

    var body: some Scene {
        WindowGroup {
            ContentView(initializationState: appModel.initializationState)
                .task {
                    await appModel.initialize()
                }
        }
    }
}
