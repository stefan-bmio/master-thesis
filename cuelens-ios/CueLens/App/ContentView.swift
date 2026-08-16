import SwiftUI

struct ContentView: View {
    @Bindable var appModel: CueLensAppModel

    var body: some View {
        ZStack {
            Color(red: 215 / 255, green: 236 / 255, blue: 233 / 255)
                .ignoresSafeArea()
            routeContent
            if appModel.showsPrivacyCurtain {
                PrivacyCurtainView()
                    .zIndex(100)
            }
        }
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
        case .home:
            HomePlaceholderView(appModel: appModel)
        case .secureStorageFailure:
            SecureStorageFailureView()
        }
    }
}

private struct HomePlaceholderView: View {
    let appModel: CueLensAppModel

    var body: some View {
        VStack(spacing: 20) {
            LanguageButton(appModel: appModel)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer()
            Text("app.title")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("app.title")
            Text("home.placeholder")
                .foregroundStyle(Color(red: 63 / 255, green: 74 / 255, blue: 73 / 255))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("app.foundationStatus.ready")
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

private struct LanguageButton: View {
    let appModel: CueLensAppModel

    var body: some View {
        Button(appModel.language == .german ? "EN" : "DE") {
            Task { await appModel.toggleLanguage() }
        }
        .buttonStyle(.bordered)
        .tint(Color(red: 0, green: 98 / 255, blue: 105 / 255))
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
            Color(red: 215 / 255, green: 236 / 255, blue: 233 / 255)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var key: LocalizedStringKey {
        switch notice {
        case .feedLoadFailed: "info.loadFailed"
        case .settingSaveFailed: "settings.saveFailed"
        }
    }
}

private struct CueLensPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Color(red: 0, green: 98 / 255, blue: 105 / 255), in: RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
