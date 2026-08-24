import SwiftUI

struct DemoView: View {
    let demo: DemoPresentation
    let appModel: CueLensAppModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    appModel.leaveDemo()
                } label: {
                    Label("navigation.back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("demo.back")
                Spacer()
                LanguageButton(appModel: appModel)
            }
            ScrollView {
                Group {
                    switch demo.step {
                    case .cueMatching: matchingContent
                    case .cueLabeling: labelingContent
                    case .craving: cravingContent
                    case .completed: completedContent
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Text(titleKey)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("demo.title")
            if demo.step != .completed {
                Text("demo.notice")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CueLensPalette.secondaryText)
            }
        }
    }

    private var matchingContent: some View {
        VStack(spacing: 16) {
            heading
            studyImage(named: "cue_000", label: "demo.cue.accessibility")
                .accessibilityIdentifier("demo.matching.cue")
            if demo.remainingSeconds > 0 {
                HStack(spacing: 4) {
                    Text("demo.matching.wait.prefix")
                    Text("\(demo.remainingSeconds)").monospacedDigit()
                    Text("demo.matching.wait.suffix")
                }
                .font(.headline)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("demo.matching.countdown")
            } else {
                Text("demo.matching.prompt")
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("demo.matching.prompt")
            }
            HStack(spacing: 12) {
                ForEach(Array(demo.matchingChoices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        Task { await appModel.selectDemoMatching() }
                    } label: {
                        studyImage(
                            named: choice.rawValue,
                            label: index == 0
                                ? "demo.choice.first.accessibility"
                                : "demo.choice.second.accessibility"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .background(
                        demo.matchingSelectionEnabled
                            ? CueLensPalette.primary
                            : CueLensPalette.disabledPrimary,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .disabled(!demo.matchingSelectionEnabled)
                    .accessibilityIdentifier("demo.matching.choice.\(index)")
                }
            }
        }
    }

    private var labelingContent: some View {
        VStack(spacing: 16) {
            heading
            studyImage(named: "cue_001", label: "demo.cue.accessibility")
                .accessibilityIdentifier("demo.labeling.cue")
            Text("demo.labeling.prompt")
                .multilineTextAlignment(.center)
            ForEach(Array(demo.labelingChoices.enumerated()), id: \.offset) { index, choice in
                Button(labelKey(for: choice)) {
                    appModel.selectDemoLabel()
                }
                .buttonStyle(CueLensPrimaryButtonStyle())
                .accessibilityIdentifier("demo.labeling.choice.\(index)")
            }
        }
    }

    private var cravingContent: some View {
        VStack(spacing: 20) {
            heading
            Text("demo.craving.prompt")
                .multilineTextAlignment(.center)
            Text("\(demo.craving)")
                .font(.largeTitle.monospacedDigit())
                .accessibilityIdentifier("demo.craving.value")
            Slider(
                value: Binding(
                    get: { Double(demo.craving) },
                    set: { appModel.updateDemoCraving(Int($0.rounded())) }
                ),
                in: 0...100,
                step: 1
            )
            .tint(CueLensPalette.primary)
            .accessibilityIdentifier("demo.craving.slider")
            Button("demo.continue") {
                appModel.completeDemoCraving()
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .accessibilityIdentifier("demo.craving.continue")
        }
    }

    private var completedContent: some View {
        VStack(spacing: 20) {
            heading
            Text("demo.completed.notice")
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("demo.completed.notice")
            Button("navigation.home") {
                appModel.leaveDemo()
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .accessibilityIdentifier("demo.completed.home")
        }
    }

    private func studyImage(named name: String, label: LocalizedStringKey) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .accessibilityLabel(Text(label))
    }

    private var titleKey: LocalizedStringKey {
        switch demo.step {
        case .cueMatching: "demo.matching.title"
        case .cueLabeling: "demo.labeling.title"
        case .craving: "demo.craving.title"
        case .completed: "demo.completed.title"
        }
    }

    private func labelKey(for choice: DemoLabelChoice) -> LocalizedStringKey {
        choice == .fitting ? "demo.label.fitting" : "demo.label.lessFitting"
    }
}

struct FeedbackView: View {
    let appModel: CueLensAppModel

    private var isSubmitting: Bool { appModel.feedbackState == .submitting }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    appModel.leaveFeedback()
                } label: {
                    Label("navigation.back", systemImage: "chevron.left")
                }
                .disabled(isSubmitting)
                .accessibilityIdentifier("feedback.back")
                Spacer()
                LanguageButton(appModel: appModel)
            }
            ScrollView {
                VStack(spacing: 16) {
                    Text("feedback.title")
                        .font(.title.bold())
                        .accessibilityIdentifier("feedback.title")
                    Text("feedback.privacyNotice")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(CueLensPalette.secondaryText)
                    if appModel.feedbackState == .submitted {
                        Text("feedback.submitted")
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("feedback.submitted")
                        Button("navigation.home") {
                            appModel.leaveFeedback()
                        }
                        .buttonStyle(CueLensPrimaryButtonStyle())
                        .accessibilityIdentifier("feedback.home")
                    } else {
                        feedbackForm
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("feedback.source")
            TextField(
                "feedback.source",
                text: Binding(
                    get: { appModel.feedbackSource },
                    set: { appModel.updateFeedbackSource($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .disabled(isSubmitting)
            .accessibilityIdentifier("feedback.source")
            characterCount(appModel.feedbackSource.unicodeScalars.count, maximum: 500)

            Text("feedback.comment")
            TextEditor(text: Binding(
                get: { appModel.feedbackComment },
                set: { appModel.updateFeedbackComment($0) }
            ))
            .frame(minHeight: 140)
            .padding(4)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            .disabled(isSubmitting)
            .accessibilityIdentifier("feedback.comment")
            characterCount(appModel.feedbackComment.unicodeScalars.count, maximum: 5_000)

            if appModel.feedbackState == .failed {
                Text("feedback.failed")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("feedback.failed")
            }
            Button(isSubmitting ? "feedback.submitting" : "feedback.submit") {
                Task { await appModel.submitFeedback() }
            }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .disabled(!appModel.feedbackInputIsValid || isSubmitting)
            .accessibilityIdentifier("feedback.submit")
            if isSubmitting {
                ProgressView()
                    .accessibilityIdentifier("feedback.progress")
            }
        }
    }

    private func characterCount(_ count: Int, maximum: Int) -> some View {
        Text("\(count)/\(maximum)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(count > maximum ? .red : CueLensPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
