//
//  QuestionnaireModels.swift
//
//  PRO feature — high-converting quiz/survey onboarding (Cal AI / Rise style).
//  Self-contained: delete `Modules/QuestionnaireOnboarding` + flip
//  `featureFlags.questionnaireOnboarding` off to remove.
//
//  CUSTOMIZE: edit `QuestionnaireConfig.steps` — that's the whole flow.
//

import Foundation

struct QuestionnaireOption: Identifiable, Sendable {
    let id = UUID()
    let label: String
    var icon: String?
    init(_ label: String, icon: String? = nil) {
        self.label = label; self.icon = icon
    }
}

struct QuestionnaireStep: Identifiable, Sendable {
    let id: String
    let question: String
    var subtitle: String?
    let options: [QuestionnaireOption]
    var multiSelect: Bool = false
}

enum QuestionnaireConfig {
    /// The entire onboarding flow lives here — add/remove/reorder freely.
    static let steps: [QuestionnaireStep] = [
        QuestionnaireStep(
            id: "goal",
            question: "What's your main goal?",
            subtitle: "We'll tailor your experience.",
            options: [
                .init("Build a habit", icon: "flame"),
                .init("Save time", icon: "clock"),
                .init("Learn something new", icon: "book"),
                .init("Just exploring", icon: "face.smiling")
            ]
        ),
        QuestionnaireStep(
            id: "experience",
            question: "How experienced are you?",
            options: [
                .init("Just starting out", icon: "leaf"),
                .init("Some experience", icon: "chart.line.uptrend.xyaxis"),
                .init("I'm a pro", icon: "crown")
            ]
        ),
        QuestionnaireStep(
            id: "focus",
            question: "What should we focus on?",
            subtitle: "Pick all that apply.",
            options: [
                .init("Speed", icon: "bolt"),
                .init("Quality", icon: "checkmark.seal"),
                .init("Consistency", icon: "calendar"),
                .init("Community", icon: "person.3")
            ],
            multiSelect: true
        ),
        QuestionnaireStep(
            id: "reminders",
            question: "Want daily reminders?",
            subtitle: "Stay on track with a gentle nudge.",
            options: [
                .init("Yes, keep me on track", icon: "bell"),
                .init("No thanks", icon: "bell.slash")
            ]
        )
    ]
}
