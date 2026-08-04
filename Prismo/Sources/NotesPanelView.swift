import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var store: ReviewStore
    let onCopy: () -> Void
    let onSubmit: () -> Void
    let isSubmitting: Bool
    let canSubmit: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Notes (\(store.notesForSelectedPR.count))", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Copy MD", action: onCopy)
                    .disabled(store.notesForSelectedPR.isEmpty)
                Button {
                    onSubmit()
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Post to GitHub")
                    }
                }
                .disabled(!canSubmit || store.notesForSelectedPR.isEmpty || isSubmitting)
                .help("COMMENT レビューとして一括投稿")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.notesForSelectedPR.isEmpty {
                Text("シンボルを選んでメモを追加")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.notesForSelectedPR) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.symbolName)
                                .font(.caption.weight(.semibold))
                            Text("\(note.filePath):\(note.line)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Text(note.body)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("削除", role: .destructive) {
                                store.deleteNote(id: note.id)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteNote(id: store.notesForSelectedPR[index].id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct AddNoteSheet: View {
    let symbolName: String
    let filePath: String
    let line: Int
    @State private var bodyText: String = ""
    let onCancel: () -> Void
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモを追加")
                .font(.headline)
            Text("\(symbolName) · \(filePath):\(line)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            TextEditor(text: $bodyText)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.12))
                )
            HStack {
                Spacer()
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave(bodyText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
