import SwiftUI

struct ContentView: View {
    @Bindable var appModel: CueLensAppModel

    var body: some View {
        ZStack {
            CueLensPalette.background
                .ignoresSafeArea()
            routeContent
            if appModel.showsPrivacyCurtain {
                PrivacyCurtainView()
                    .zIndex(100)
            }
        }
        .foregroundStyle(CueLensPalette.text)
        .preferredColorScheme(.light)
        .overlay(alignment: .bottom) {
            if let notice = appModel.notice {
                NoticeView(notice: notice) {
                    appModel.dismissNotice()
                }
            }
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch appModel.route {
        case .loading:
            ProgressView("app.initializing")
                .accessibilityIdentifier("app.foundationStatus.loading")
        case .infoFeed:
            if let feed = appModel.feed {
                InfoMessageView(feed: feed, appModel: appModel)
            }
        case .notificationConsent:
            NotificationConsentView(appModel: appModel)
        case .home:
            HomeView(appModel: appModel)
        case .activation:
            ActivationView(appModel: appModel)
        case .demo:
            if let demo = appModel.demo {
                DemoView(demo: demo, appModel: appModel)
            }
        case .feedback:
            FeedbackView(appModel: appModel)
        case .secureStorageFailure:
            SecureStorageFailureView()
        }
    }
}

enum CueLensPalette {
    static let background = Color(red: 215 / 255, green: 236 / 255, blue: 233 / 255)
    static let primary = Color(red: 0, green: 98 / 255, blue: 105 / 255)
    static let disabledPrimary = Color(red: 82 / 255, green: 124 / 255, blue: 121 / 255)
    static let text = Color(red: 32 / 255, green: 42 / 255, blue: 41 / 255)
    static let secondaryText = Color(red: 63 / 255, green: 74 / 255, blue: 73 / 255)
    static let noticeBackground = Color.white.opacity(0.96)
}

struct HomeView: View {
    let appModel: CueLensAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LanguageButton(appModel: appModel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("app.title")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("app.title")
                Text("home.welcome")
                    .foregroundStyle(CueLensPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("app.foundationStatus.ready")
                if appModel.isStudyCompleted {
                    Text("home.studyCompleted")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("home.completion")
                } else {
                    if appModel.isActivated {
                        Text("activation.alreadyCompleted")
                            .foregroundStyle(CueLensPalette.secondaryText)
                            .accessibilityIdentifier("activation.completed")
                    } else {
                        Button("activation.open") {
                            appModel.openActivation()
                        }
                        .buttonStyle(CueLensPrimaryButtonStyle())
                        .disabled(appModel.hasTokenStorageFailure)
                        .accessibilityIdentifier("activation.open")
                    }
                    if appModel.hasTokenStorageFailure {
                        Text("home.tokenStorageFailure")
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.tokenStorageFailure")
                    }
                    Button("demo.open") {
                        Task { await appModel.openDemo() }
                    }
                    .buttonStyle(CueLensPrimaryButtonStyle())
                    .accessibilityIdentifier("demo.open")
                }

                Button("feedback.title") {
                    appModel.openFeedback()
                }
                .buttonStyle(CueLensPrimaryButtonStyle())
                .accessibilityIdentifier("feedback.open")

                Divider().padding(.vertical, 4)
                Button("privacy.open") {
                    Task { await appModel.openPrivacyInformation() }
                }
                .buttonStyle(.bordered)
                .tint(CueLensPalette.primary)
                .accessibilityIdentifier("privacy.open")
                Text("rights.description")
                    .font(.footnote)
                    .foregroundStyle(CueLensPalette.secondaryText)
                    .multilineTextAlignment(.center)
                Button("rights.contact") {
                    Task { await appModel.openRightsContact() }
                }
                .buttonStyle(.bordered)
                .tint(CueLensPalette.primary)
                .accessibilityIdentifier("rights.contact")
            }
            .frame(maxWidth: 600)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ActivationView: View {
    let appModel: CueLensAppModel

    private var isRunning: Bool {
        appModel.activationState == .requestingToken
            || appModel.activationState == .confirmingToken
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    appModel.cancelActivation()
                } label: {
                    Label("navigation.back", systemImage: "chevron.left")
                }
                .disabled(isRunning)
                .accessibilityIdentifier("activation.back")
                Spacer()
                LanguageButton(appModel: appModel)
            }
            Spacer()
            Text("activation.title")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("activation.title")
            TextField(
                "activation.identifier",
                text: Binding(
                    get: { appModel.activationInput },
                    set: { appModel.updateActivationInput($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .disabled(!appModel.activationInputIsEnabled)
            .accessibilityIdentifier("activation.identifier")
            if appModel.activationState == .failed {
                Text("activation.failed")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("activation.error")
            } else if appModel.activationState == .supportRequired {
                Text("activation.supportRequired")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("activation.support")
            }
            Button(isRunning ? "activation.running" : "activation.submit") {
                Task { await appModel.activate() }
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .disabled(!appModel.activationInputIsValid || isRunning)
            .accessibilityIdentifier("activation.submit")
            if isRunning {
                ProgressView()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("activation.running"))
                    .accessibilityIdentifier("activation.progress")
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct NotificationConsentView: View {
    let appModel: CueLensAppModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                LanguageButton(appModel: appModel)
            }
            Spacer()
            Text("notification.consent.title")
                .font(.title.bold())
                .accessibilityIdentifier("notification.consent.title")
            Text("notification.consent.text")
                .multilineTextAlignment(.center)
                .foregroundStyle(CueLensPalette.secondaryText)
            Toggle(
                "notification.consent.toggle",
                isOn: Binding(
                    get: { appModel.notificationOptionEnabled },
                    set: { appModel.setNotificationOptionEnabled($0) }
                )
            )
            .tint(CueLensPalette.primary)
            .disabled(appModel.isCompletingNotificationConsent)
            .accessibilityIdentifier("notification.consent.toggle")
            Button("notification.consent.continue") {
                Task { await appModel.completeNotificationConsent() }
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .disabled(appModel.isCompletingNotificationConsent)
            .accessibilityIdentifier("notification.consent.continue")
            Spacer()
        }
        .padding(20)
    }
}

private struct InfoMessageView: View {
    let feed: InfoFeedPresentation
    let appModel: CueLensAppModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    Task { await appModel.navigateBackInFeed() }
                } label: {
                    Label("navigation.back", systemImage: "chevron.left")
                }
                .disabled(feed.isConfirming)
                .accessibilityIdentifier("info.back")
                Spacer()
                LanguageButton(appModel: appModel)
            }
            ScrollView {
                Text(messageText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .accessibilityIdentifier("info.message")
            }
            Toggle("info.hidePermanently", isOn: Binding(
                get: { feed.hidePermanently },
                set: { appModel.setHidePermanently($0) }
            ))
            .disabled(feed.isConfirming)
            .accessibilityIdentifier("info.hidePermanently")
            Button("info.confirm") {
                Task { await appModel.confirmCurrentMessage() }
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .disabled(feed.isConfirming)
            .accessibilityIdentifier("info.confirm")
        }
        .padding(20)
    }

    private var messageText: String {
        switch appModel.language {
        case .german: feed.currentMessage.textGerman
        case .english: feed.currentMessage.textEnglish
        }
    }
}

struct LanguageButton: View {
    let appModel: CueLensAppModel

    var body: some View {
        Button(appModel.language == .german ? "EN" : "DE") {
            Task { await appModel.toggleLanguage() }
        }
        .buttonStyle(.bordered)
        .tint(CueLensPalette.primary)
        .accessibilityLabel(Text("language.switch.accessibility"))
        .accessibilityIdentifier("language.switch")
    }
}

private struct SecureStorageFailureView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("app.title")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("app.title")
            Text("app.secureStorageFailure")
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("app.foundationStatus.failure")
        }
        .padding(20)
    }
}

private struct PrivacyCurtainView: View {
    var body: some View {
        ZStack {
            CueLensPalette.background
                .ignoresSafeArea()
            Text("app.title")
                .font(.largeTitle.bold())
        }
        .accessibilityIdentifier("privacy.curtain")
    }
}

private struct NoticeView: View {
    let notice: UserNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .accessibilityIdentifier("app.notice.message")
            Button("notice.dismiss", action: dismiss)
        }
        .padding()
        .background(CueLensPalette.noticeBackground, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var key: LocalizedStringKey {
        switch notice {
        case .feedLoadFailed: "info.loadFailed"
        case .settingSaveFailed: "settings.saveFailed"
        case .externalLinkFailed: "links.openFailed"
        }
    }
}

struct CueLensPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                isEnabled ? CueLensPalette.primary : CueLensPalette.disabledPrimary,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
