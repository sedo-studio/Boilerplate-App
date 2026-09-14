//
//  QuestionnaireOnboardingView.swift
//
//  Paged quiz onboarding with a progress bar, single/multi-select options, and
//  persisted answers. Present it as a `fullScreenCover`; on finish it calls
//  `onComplete(answers)` and dismisses (route to your paywall/home next).
//

import SwiftUI

struct QuestionnaireOnboardingView: View {
    var steps: [QuestionnaireStep] = QuestionnaireConfig.steps
    /// stepID → selected option labels.
    var onComplete: ([String: [String]]) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answers: [String: Set<String>] = [:]

    private var step: QuestionnaireStep { steps[index] }
    private var selected: Set<String> { answers[step.id] ?? [] }
    private var canContinue: Bool { !selected.isEmpty }
    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(step.question).appFont(.title)
                        if let s = step.subtitle {
                            Text(s).appFont(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(step.options) { optionRow($0) }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.lg)
            }

            Button(action: advance) {
                Text(isLast ? "Finish" : "Continue")
                    .appFont(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        DS.accent.opacity(canContinue ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .padding(DS.Spacing.lg)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: DS.Motion.normal), value: index)
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                if index > 0 { withAnimation { index -= 1 } } else { dismiss() }
            } label: {
                Image(systemName: index > 0 ? "chevron.left" : "xmark")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            ProgressView(value: Double(index + 1), total: Double(steps.count))
                .tint(DS.accent)
            Text("\(index + 1)/\(steps.count)")
                .appFont(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DS.Spacing.lg)
    }

    private func optionRow(_ opt: QuestionnaireOption) -> some View {
        let isSel = selected.contains(opt.label)
        return Button { toggle(opt.label) } label: {
            HStack(spacing: DS.Spacing.md) {
                if let icon = opt.icon {
                    Image(systemName: icon)
                        .foregroundColor(isSel ? DS.accent : .secondary)
                        .frame(width: 26)
                }
                Text(opt.label).appFont(.body).foregroundColor(.primary)
                Spacer(minLength: 0)
                Image(systemName: selectionSymbol(isSel))
                    .foregroundColor(isSel ? DS.accent : Color(.tertiaryLabel))
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSel ? DS.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectionSymbol(_ isSel: Bool) -> String {
        if step.multiSelect { return isSel ? "checkmark.square.fill" : "square" }
        return isSel ? "largecircle.fill.circle" : "circle"
    }

    private func toggle(_ label: String) {
        var set = answers[step.id] ?? []
        if step.multiSelect {
            if set.contains(label) { set.remove(label) } else { set.insert(label) }
        } else {
            set = [label]
        }
        answers[step.id] = set
    }

    private func advance() {
        guard canContinue else { return }
        if isLast {
            let result = answers.mapValues { Array($0) }
            if let data = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(data, forKey: "questionnaire.answers")
            }
            UserDefaults.standard.set(true, forKey: "questionnaire.completed")
            onComplete(result)
            dismiss()
        } else {
            withAnimation { index += 1 }
        }
    }
}

#Preview {
    QuestionnaireOnboardingView()
}
