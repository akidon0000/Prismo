import SwiftUI
import AppKit

struct NotesPanelView: View {
    @ObservedObject var store: ReviewStore
    let onCopy: () -> Void
    let onSubmit: () -> Void
    let isSubmitting: Bool
    let canSubmit: Bool
    @State private var confirmingPost = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    "Notes (\(store.notesForSelectedPR.count)) · GitHub (\(store.remoteComments.count))",
                    systemImage: "note.text"
                )
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                Spacer()
                Button("Copy MD", action: onCopy)
                    .disabled(store.notesForSelectedPR.isEmpty)
                Button {
                    confirmingPost = true
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Post to GitHub")
                    }
                }
                .disabled(!canSubmit || store.notesForSelectedPR.isEmpty || isSubmitting)
                .help("COMMENT レビューとして一括投稿")
                .confirmationDialog(
                    "GitHub に投稿しますか？",
                    isPresented: $confirmingPost,
                    titleVisibility: .visible
                ) {
                    Button("投稿する (\(store.notesForSelectedPR.count)件)") {
                        onSubmit()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("COMMENT レビューとして \(store.notesForSelectedPR.count) 件のメモを投稿します。投稿後、ローカルの下書きはクリアされます。")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List {
                Section("Draft") {
                    if store.notesForSelectedPR.isEmpty {
                        Text("シンボルを選んでメモを追加")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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
                }

                Section(
                    store.remoteCommentCountForSelectedFile > 0
                        ? "On GitHub（選択ファイル \(store.remoteCommentCountForSelectedFile) / 全体 \(store.remoteComments.count)）"
                        : "On GitHub（\(store.remoteComments.count)）"
                ) {
                    if store.remoteComments.isEmpty {
                        Text("既存の行コメントはありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.remoteCommentsForSelectedFile) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.user?.login ?? "unknown")
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    if let line = comment.line {
                                        Text("L\(line)")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if let path = comment.path {
                                    Text(path)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(comment.body)
                                    .font(.callout)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let url = comment.htmlURL.flatMap(URL.init(string:)) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
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
