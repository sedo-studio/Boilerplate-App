//
//  SwiftDataDemoView.swift
//
//  Offline-first CRUD demo backed by SwiftData. Data persists across launches.
//
//  PRODUCTION TIP: instead of attaching `.modelContainer` here, attach it once
//  at your app root (TheSwiftKitApp) so the whole app shares one store:
//      WindowGroup { RootView() }.modelContainer(for: StoredItem.self)
//

import SwiftUI
import SwiftData

@available(iOS 17, *)
struct SwiftDataDemoView: View {
    var body: some View {
        // Self-contained store for the demo. Hoist to the app root in production.
        SwiftDataItemListView()
            .modelContainer(for: StoredItem.self)
    }
}

@available(iOS 17, *)
private struct SwiftDataItemListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredItem.createdAt, order: .reverse) private var items: [StoredItem]
    @State private var newTitle = ""

    private var trimmed: String { newTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            Section {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("New item…", text: $newTitle)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(trimmed.isEmpty ? Color(.tertiaryLabel) : DS.accent)
                    }
                    .disabled(trimmed.isEmpty)
                }
            }

            Section("Items (\(items.count))") {
                if items.isEmpty {
                    Text("No items yet — add one above. It persists across app launches.")
                        .appFont(.footnote)
                        .foregroundColor(.secondary)
                }
                ForEach(items) { item in
                    Button { item.isDone.toggle(); try? context.save() } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isDone ? DS.accent : .secondary)
                            Text(item.title)
                                .strikethrough(item.isDone)
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                            Text(item.createdAt, style: .time)
                                .appFont(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle(Text("SwiftData Store"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        context.insert(StoredItem(title: trimmed))
        newTitle = ""
        try? context.save()
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(items[i]) }
        try? context.save()
    }
}
