import SwiftUI
import UIKit

struct ProductiveStudyView: View {
    let run: PreparedStudyRun
    let appModel: CueLensAppModel

    var body: some View {
        GeometryReader { geometry in
            Group {
                if appModel.productiveStudyViewportSuitable {
                    phaseContent(size: geometry.size)
                } else {
                    unsuitableViewport
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { appModel.updateProductiveStudyViewport(geometry.size) }
            .onChange(of: geometry.size) { _, size in
                appModel.updateProductiveStudyViewport(size)
            }
        }
    }

    @ViewBuilder
    private func phaseContent(size: CGSize) -> some View {
        switch run.session.phase {
        case .cueMatching:
            if let item = currentMatchingItem {
                cueScreen(named: item.cueAssetName, size: size) {
                    matchingControls(item: item)
                }
            }
        case .cueLabeling:
            if let item = currentLabelingItem {
                cueScreen(named: item.cueAssetName, size: size) {
                    labelingControls(item: item)
                }
            }
        case .craving:
            cravingContent
        }
    }

    private func cueScreen<Controls: View>(
        named name: String,
        size: CGSize,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        ZStack {
            if let image = StudyImageResource.load(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
            controls()
            LanguageButton(appModel: appModel)
                .padding(.top, max(16, size.height * 0.02))
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func matchingControls(item: MatchingItem) -> some View {
        let names = run.session.currentChoiceIsReversed
            ? [item.matchBAssetName, item.matchAAssetName]
            : [item.matchAAssetName, item.matchBAssetName]
        return HStack(spacing: 16) {
            matchingButton(
                named: names[0],
                label: "study.imageOption.first",
                identifier: "study.matching.choice.0"
            )
            if run.session.remainingSeconds > 0 {
                ZStack {
                    Circle().fill(CueLensPalette.noticeBackground)
                    Circle().stroke(CueLensPalette.primary, lineWidth: 4)
                    Text("\(run.session.remainingSeconds)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(CueLensPalette.text)
                }
                .frame(width: 72, height: 72)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("study.matching.wait"))
                .accessibilityValue(Text("\(run.session.remainingSeconds)"))
                .accessibilityIdentifier("study.matching.countdown")
            } else {
                Spacer().frame(width: 24)
            }
            matchingButton(
                named: names[1],
                label: "study.imageOption.second",
                identifier: "study.matching.choice.1"
            )
        }
        .frame(height: 140)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func matchingButton(
        named name: String,
        label: LocalizedStringKey,
        identifier: String
    ) -> some View {
        Button {
            appModel.selectProductiveStudyChoice()
        } label: {
            if let image = StudyImageResource.load(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 180, maxHeight: 140)
        .contentShape(Rectangle())
        .disabled(!run.session.selectionEnabled)
        .opacity(run.session.selectionEnabled ? 1 : 0.72)
        .accessibilityLabel(Text(label))
        .accessibilityValue(
            Text("study.trial.progress \(run.session.trialIndex + 1) \(StudySchedule.trialsPerSituation)")
        )
        .accessibilityIdentifier(identifier)
    }

    private func labelingControls(item: LabelingItem) -> some View {
        let pair = item.labels(for: appModel.language)
        let labels = run.session.currentChoiceIsReversed
            ? [pair.lessFitting, pair.fitting]
            : [pair.fitting, pair.lessFitting]
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                labelButton(labels[0], identifier: "study.labeling.choice.0")
                labelButton(labels[1], identifier: "study.labeling.choice.1")
            }
            VStack(spacing: 12) {
                labelButton(labels[0], identifier: "study.labeling.choice.0")
                labelButton(labels[1], identifier: "study.labeling.choice.1")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func labelButton(_ label: String, identifier: String) -> some View {
        Button(label) { appModel.selectProductiveStudyChoice() }
            .buttonStyle(CueLensPrimaryButtonStyle())
            .accessibilityIdentifier(identifier)
    }

    private var cravingContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    LanguageButton(appModel: appModel)
                }
                Text("study.craving.prompt")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(run.session.craving)")
                    .font(.largeTitle.monospacedDigit())
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("study.craving.value")
                Slider(
                    value: Binding(
                        get: { Double(run.session.craving) },
                        set: { appModel.updateProductiveCraving(Int($0.rounded())) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(CueLensPalette.primary)
                .disabled(appModel.productiveStudySubmitting)
                .accessibilityLabel(Text("study.craving.slider.accessibility"))
                .accessibilityValue(Text("\(run.session.craving)"))
                .accessibilityIdentifier("study.craving.slider")
                Button(appModel.productiveStudySubmitting ? "study.submitting" : "study.submit") {
                    Task { await appModel.submitProductiveCraving() }
                }
                .buttonStyle(CueLensPrimaryButtonStyle())
                .disabled(appModel.productiveStudySubmitting)
                .accessibilityIdentifier("study.craving.submit")
                if appModel.productiveStudySubmitting {
                    ProgressView().accessibilityIdentifier("study.submitting.progress")
                }
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(CueLensPalette.background)
    }

    private var unsuitableViewport: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    LanguageButton(appModel: appModel)
                }
                Text("study.viewport.unsuitable")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("study.viewport.unsuitable")
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(CueLensPalette.background)
    }

    private var currentMatchingItem: MatchingItem? {
        guard let index = run.session.currentItemIndex,
              run.content.matchingItems.indices.contains(index) else { return nil }
        return run.content.matchingItems[index]
    }

    private var currentLabelingItem: LabelingItem? {
        guard let index = run.session.currentItemIndex,
              run.content.labelingItems.indices.contains(index) else { return nil }
        return run.content.labelingItems[index]
    }
}
