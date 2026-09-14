//
//  FeedbackView.swift
//
//  PRO feature — in-app feedback form. Pushed from Settings and the demo hub.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Swap `LocalFeedbackService` for your Supabase/API implementation.
    private let service: FeedbackService = LocalFeedbackService()
    /// Where "Email us instead" sends to — change to your support address.
    private let supportEmail = "support@example.com"

    @State private var category: FeedbackItem.Category = .bug
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorText: String?

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("feedback.category") {
                Picker("feedback.category", selection: $category) {
                    ForEach(FeedbackItem.Category.allCases, id: \.self) { c in
                        Label(c.title, systemImage: c.systemImage).tag(c)
                    }
                }
            }

            Section("feedback.message") {
                TextEditor(text: $message)
                    .frame(minHeight: 120)
            }

            Section("feedback.email") {
                TextField("feedback.email.placeholder", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if isSubmitting { ProgressView() }
                        Text("feedback.submit")
                    }
                }
                .disabled(trimmedMessage.isEmpty || isSubmitting)

                Button {
                    sendEmail()
                } label: {
                    Label("feedback.email.instead", systemImage: "envelope")
                }
            } footer: {
                Text(metadataFooter)
                    .appFont(.caption)
            }
        }
        .navigationTitle(Text("feedback.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("feedback.thanks.title", isPresented: $didSubmit) {
            Button("generic.ok") { dismiss() }
        } message: {
            Text("feedback.thanks.message")
        }
        .alert("feedback.error.title", isPresented: .constant(errorText != nil)) {
            Button("generic.ok") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let item = FeedbackItem(category: category, message: trimmedMessage, email: email)
        do {
            try await service.submit(item)
            didSubmit = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func sendEmail() {
        let subject = "App Feedback: \(category.rawValue.capitalized)"
        let body = "\(message)\n\n---\n\(metadataFooter)"
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportEmail
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = comps.url { openURL(url) }
    }

    private var metadataFooter: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        #if canImport(UIKit)
        return "App \(v) • iOS \(UIDevice.current.systemVersion) • \(UIDevice.current.model)"
        #else
        return "App \(v)"
        #endif
    }
}

extension FeedbackItem.Category {
    var title: LocalizedStringKey {
        switch self {
        case .bug:      return "feedback.cat.bug"
        case .idea:     return "feedback.cat.idea"
        case .question: return "feedback.cat.question"
        case .praise:   return "feedback.cat.praise"
        case .other:    return "feedback.cat.other"
        }
    }

    var systemImage: String {
        switch self {
        case .bug:      return "ladybug"
        case .idea:     return "lightbulb"
        case .question: return "questionmark.circle"
        case .praise:   return "heart"
        case .other:    return "ellipsis.circle"
        }
    }
}

#Preview {
    NavigationStack { FeedbackView() }
}
