import SwiftUI

struct SnippetSettingsView: View {
    @EnvironmentObject var snippetStore: SnippetStore
    @State private var selectedSnippet: Snippet?
    @State private var isEditing = false
    @State private var editTrigger = ""
    @State private var editReplacement = ""

    var body: some View {
        Form {
            Section {
                Text("Say a trigger phrase and it will be expanded to the replacement text. Supports {{date}}, {{time}}, and {{clipboard}} variables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    editTrigger = ""
                    editReplacement = ""
                    selectedSnippet = nil
                    isEditing = true
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }

                if snippetStore.snippets.isEmpty {
                    VStack(spacing: 6) {
                        Text("No snippets yet")
                            .foregroundStyle(.secondary)
                        Text("Add a snippet to quickly expand trigger phrases into longer text.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                ForEach(snippetStore.snippets) { snippet in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.trigger)
                            .fontWeight(.medium)
                        Text(snippet.replacement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Edit") {
                            editTrigger = snippet.trigger
                            editReplacement = snippet.replacement
                            selectedSnippet = snippet
                            isEditing = true
                        }
                        Button("Delete", role: .destructive) {
                            if let index = snippetStore.snippets.firstIndex(where: { $0.id == snippet.id }) {
                                snippetStore.removeSnippet(at: IndexSet(integer: index))
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    snippetStore.removeSnippet(at: offsets)
                }
            } header: {
                Text("Snippets")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isEditing) {
            SnippetEditorSheet(
                trigger: $editTrigger,
                replacement: $editReplacement,
                isNew: selectedSnippet == nil
            ) {
                if let existing = selectedSnippet {
                    var updated = existing
                    updated.trigger = editTrigger
                    updated.replacement = editReplacement
                    snippetStore.updateSnippet(updated)
                } else {
                    snippetStore.addSnippet(Snippet(trigger: editTrigger, replacement: editReplacement))
                }
                isEditing = false
            }
        }
    }
}

struct SnippetEditorSheet: View {
    @Binding var trigger: String
    @Binding var replacement: String
    let isNew: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(isNew ? "New Snippet" : "Edit Snippet")
                .font(.headline)

            TextField("Trigger phrase", text: $trigger)
                .textFieldStyle(.roundedBorder)

            Text("Replacement:")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)

            TextEditor(text: $replacement)
                .font(.body)
                .frame(minHeight: 100)
                .border(.quaternary)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trigger.isEmpty || replacement.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
