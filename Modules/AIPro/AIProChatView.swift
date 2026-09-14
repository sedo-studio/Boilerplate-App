//
//  AIProChatView.swift
//
//  PRO feature demo — a streaming chat with persisted history. Uses the mock
//  streamer by default so it works offline; toggle "Use live backend" to hit
//  your running /v1/chat/stream endpoint.
//

import SwiftUI

struct AIProChatView: View {
    @StateObject private var store = AIChatStore()
    @State private var input = ""
    @State private var useBackend = false

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.md) {
                        if store.messages.isEmpty { emptyState }
                        ForEach(store.messages) { bubble($0) }
                    }
                    .padding(DS.Spacing.lg)
                }
                .onChange(of: store.messages.last?.text) { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            inputBar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Text("AI PRO Chat"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle("Use live backend", isOn: $useBackend)
                    Button(role: .destructive) { store.clear() } label: {
                        Label("Clear history", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient(colors: [DS.accent, DS.primary], startPoint: .top, endPoint: .bottom))
            Text("Streaming AI chat").appFont(.headline)
            Text("Ask anything — replies stream in live and your history is saved.")
                .appFont(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxl)
    }

    private func bubble(_ msg: AIChatStore.Msg) -> some View {
        let isUser = msg.role == "user"
        let showCaret = !isUser && msg.text.isEmpty && store.isStreaming
        return HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            Text(showCaret ? "▍" : msg.text)
                .appFont(.body)
                .foregroundColor(isUser ? .white : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isUser ? AnyShapeStyle(DS.accent) : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                )
            if !isUser { Spacer(minLength: 40) }
        }
        .id(msg.id)
    }

    private var inputBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            TextField("Message…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
            Button {
                let text = input
                input = ""
                store.send(text, useBackend: useBackend)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? DS.accent : Color(.tertiaryLabel))
            }
            .disabled(!canSend)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack { AIProChatView() }
}
