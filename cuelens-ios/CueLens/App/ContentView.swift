import SwiftUI

struct ContentView: View {
    @Bindable var appModel: CueLensAppModel

    var body: some View {
        ZStack {
            CueLensPalette.background
                .ignoresSafeArea()
            routeContent
                .accessibilityHidden(appModel.showsPrivacyCurtain)
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
        case .productiveStudy:
            if let run = appModel.productiveRun {
                ProductiveStudyView(run: run, appModel: appModel)
            }
        case .secureStorageFailure:
            SecureStorageFailureView()
        }
    }
}

struct CueLensSRGBColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }

    func contrastRatio(with other: CueLensSRGBColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: Double {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    private static func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

enum CueLensPalette {
    static let backgroundDefinition = CueLensSRGBColor(red: 215 / 255, green: 236 / 255, blue: 233 / 255)
    static let primaryDefinition = CueLensSRGBColor(red: 0, green: 98 / 255, blue: 105 / 255)
    static let disabledPrimaryDefinition = CueLensSRGBColor(red: 82 / 255, green: 124 / 255, blue: 121 / 255)
    static let textDefinition = CueLensSRGBColor(red: 32 / 255, green: 42 / 255, blue: 41 / 255)
    static let secondaryTextDefinition = CueLensSRGBColor(red: 63 / 255, green: 74 / 255, blue: 73 / 255)
    static let errorDefinition = CueLensSRGBColor(red: 148 / 255, green: 23 / 255, blue: 31 / 255)
    static let whiteDefinition = CueLensSRGBColor(red: 1, green: 1, blue: 1)

    static let background = backgroundDefinition.color
    static let primary = primaryDefinition.color
    static let disabledPrimary = disabledPrimaryDefinition.color
    static let text = textDefinition.color
    static let secondaryText = secondaryTextDefinition.color
    static let error = errorDefinition.color
    static let noticeBackground = Color.white.opacity(0.96)
}

struct HomeView: View {
    let appModel: CueLensAppModel
    @AccessibilityFocusState private var focusedNotice: HomeAccessibilityFocus?

    private enum HomeAccessibilityFocus: Hashable {
        case tokenFailure
        case invalidState
        case transferFailure
    }

    var body: some View {
        GeometryReader { geometry in
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
                    if let code = appModel.directCompensationCode {
                        Text("completion.direct.instructions")
                            .multilineTextAlignment(.center)
                        Text(code)
                            .font(.body.monospaced())
                            .accessibilityIdentifier("completion.direct.code")
                        Button("completion.copy") {
                            Task { await appModel.copyCompensationCode() }
                        }
                        .buttonStyle(CueLensPrimaryButtonStyle())
                        .accessibilityIdentifier("completion.copy")
                        if appModel.compensationCodeWasCopied {
                            Text("completion.copied")
                                .accessibilityIdentifier("completion.copied")
                        }
                    } else if appModel.hasProlificCompletion {
                        Text("completion.prolific")
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("completion.prolific")
                    }
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
                            .foregroundStyle(CueLensPalette.error)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.tokenStorageFailure")
                            .accessibilityFocused($focusedNotice, equals: .tokenFailure)
                    }
                    if appModel.hasInvalidStudyState {
                        Text("study.state.invalid")
                            .foregroundStyle(CueLensPalette.error)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("study.state.invalid")
                            .accessibilityFocused($focusedNotice, equals: .invalidState)
                    } else if appModel.hasPendingStudyTransfer {
                        Text("study.transfer.pending")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("study.transfer.pending")
                        studyRetry
                    } else if appModel.hasPendingDirectConfirmation {
                        Text("completion.confirmation.pending")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("completion.confirmation.pending")
                        studyRetry
                    } else if appModel.showsNextStudyRun {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let enabled = appModel.nextStudyRunIsEnabled(now: context.date)
                            Button {
                                Task { await appModel.openProductiveStudy(viewportSize: geometry.size) }
                            } label: {
                                if enabled {
                                    Text("study.nextRun")
                                } else {
                                    Text(
                                        "study.nextRun.countdown \(StudyCooldown.formattedRemaining(until: appModel.studyState?.nextSituationAvailableAt, now: context.date))"
                                    )
                                }
                            }
                            .buttonStyle(CueLensPrimaryButtonStyle())
                            .disabled(!enabled)
                            .accessibilityIdentifier("study.start")
                        }
                    } else if appModel.isActivated
                                && appModel.productiveStudyFeatureEnabled
                                && !appModel.productiveStudyContentAvailable {
                        Text("study.resources.unavailable")
                            .foregroundStyle(CueLensPalette.error)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("study.resources.unavailable")
                    }
                    if appModel.productiveStudyBlockReason == .unsuitableViewport {
                        Text("study.viewport.unsuitable")
                            .foregroundStyle(CueLensPalette.error)
                            .multilineTextAlignment(.center)
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
        .onAppear { focusCurrentNotice() }
        .onChange(of: appModel.studyTransferState) { _, state in
            if state == .failed { focusedNotice = .transferFailure }
        }
    }

    private var studyRetry: some View {
        VStack(spacing: 12) {
            if appModel.studyTransferState == .failed {
                Text("study.transfer.failed")
                    .foregroundStyle(CueLensPalette.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("study.transfer.failed")
                    .accessibilityFocused($focusedNotice, equals: .transferFailure)
            }
            Button(appModel.studyTransferIsRunning ? "study.submitting" : "study.transfer.retry") {
                Task { await appModel.retryPendingStudyTransfer() }
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .disabled(appModel.studyTransferIsRunning)
            .accessibilityIdentifier("study.transfer.retry")
            if appModel.studyTransferIsRunning {
                ProgressView()
                    .accessibilityIdentifier("study.transfer.progress")
            }
        }
    }

    private func focusCurrentNotice() {
        if appModel.hasTokenStorageFailure {
            focusedNotice = .tokenFailure
        } else if appModel.hasInvalidStudyState {
            focusedNotice = .invalidState
        } else if appModel.studyTransferState == .failed {
            focusedNotice = .transferFailure
        }
    }
}

private struct ActivationView: View {
    let appModel: CueLensAppModel
    @AccessibilityFocusState private var errorFocused: Bool

    private var isRunning: Bool {
        appModel.activationState == .requestingToken
            || appModel.activationState == .confirmingToken
    }

    var body: some View {
        ScrollView {
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
                    .foregroundStyle(CueLensPalette.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("activation.error")
                    .accessibilityFocused($errorFocused)
            } else if appModel.activationState == .supportRequired {
                Text("activation.supportRequired")
                    .foregroundStyle(CueLensPalette.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("activation.support")
                    .accessibilityFocused($errorFocused)
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
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .onChange(of: appModel.activationState) { _, state in
            errorFocused = state == .failed || state == .supportRequired
        }
    }
}

private struct NotificationConsentView: View {
    let appModel: CueLensAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            HStack {
                Spacer()
                LanguageButton(appModel: appModel)
            }
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
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
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
                VStack(spacing: 16) {
                Text(messageText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .accessibilityIdentifier("info.message")
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
            }
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
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(Text("language.switch.accessibility"))
        .accessibilityIdentifier("language.switch")
    }
}

private struct SecureStorageFailureView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("app.title")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("app.title")
                Text("app.secureStorageFailure")
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("app.foundationStatus.failure")
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
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
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .accessibilityIdentifier("app.notice.message")
            Button("notice.dismiss", action: dismiss)
        }
        .padding()
        .background(CueLensPalette.noticeBackground, in: RoundedRectangle(cornerRadius: 12))
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isFocused)
        .onAppear { isFocused = true }
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
            .frame(minHeight: 44)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                isEnabled ? CueLensPalette.primary : CueLensPalette.disabledPrimary,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
