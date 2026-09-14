//
//  AIChatStore.swift
//
//  Conversation state for AI PRO: persists history (UserDefaults) and appends
//  streamed deltas live. Falls back to the mock streamer when the backend is
//  unreachable so the chat always works in the demo.
//

import Foundation
import SwiftUI

@MainActor
final class AIChatStore: ObservableObject {
    struct Msg: Identifiable, Codable, Equatable {
        let id: UUID
        var role: String     // "user" | "assistant"
        var text: String
        init(role: String, text: String) { self.id = UUID(); self.role = role; self.text = text }
    }

    @Published private(set) var messages: [Msg] = []
    @Published private(set) var isStreaming = false

    private let key = "aipro.history.v1"
    private let client = AIProStreamClient()

    init() { load() }

    /// Send a user message and stream the assistant reply.
    /// - Parameter useBackend: when false (or on failure) uses the mock streamer.
    func send(_ text: String, useBackend: Bool) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }

        messages.append(Msg(role: "user", text: prompt))
        let assistant = Msg(role: "assistant", text: "")
        messages.append(assistant)
        save()
        isStreaming = true

        Task {
            if useBackend {
                do {
                    let payload = messages.dropLast().map { ["role": $0.role, "content": $0.text] }
                    for try await delta in client.stream(messages: Array(payload)) {
                        append(delta, to: assistant.id)
                    }
                } catch {
                    // Backend unreachable → keep the demo alive with the mock stream.
                    for await delta in AIProStreamClient.mockStream(for: prompt) {
                        append(delta, to: assistant.id)
                    }
                }
            } else {
                for await delta in AIProStreamClient.mockStream(for: prompt) {
                    append(delta, to: assistant.id)
                }
            }
            isStreaming = false
            save()
        }
    }

    func clear() {
        messages = []
        save()
    }

    private func append(_ delta: String, to id: UUID) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[i].text += delta
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Msg].self, from: data) else { return }
        messages = saved
    }

    private func save() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
