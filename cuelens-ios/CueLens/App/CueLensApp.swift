import SwiftUI

@main
struct CueLensApp: App {
    @UIApplicationDelegateAdaptor(CueLensAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel: CueLensAppModel

    init() {
        let model: CueLensAppModel
        do {
            model = CueLensAppModel(environment: try AppEnvironment.live())
        } catch {
            model = CueLensAppModel(configurationFailure: ())
        }
        _appModel = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
                .environment(\.locale, Locale(identifier: appModel.language.rawValue))
                .task {
                    await appModel.initialize(lifecyclePhase: lifecyclePhase)
                }
                .onChange(of: scenePhase) { _, _ in
                    Task { await appModel.updateLifecycle(lifecyclePhase) }
                }
        }
    }

    private var lifecyclePhase: AppLifecyclePhase {
        switch scenePhase {
        case .active: .active
        case .background: .background
        default: .inactive
        }
    }
}
