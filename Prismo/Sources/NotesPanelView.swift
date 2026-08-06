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
        ContentPane(
            title: "メモ",
            symbol: "note.text",
            trailing: "下書き \(store.notesForSelectedPR.count) · GitHub \(store.remoteComments.count)"
        ) {
            HStack(spacing: 10) {
                Spacer()
                Button("Markdownをコピー") { onCopy() }
                    .font(Theme.caption)
                    .disabled(store.notesForSelectedPR.isEmpty)
                Button {
                    confirmingPost = true
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("GitHubに投稿")
                            .font(Theme.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canSubmit || store.notesForSelectedPR.isEmpty || isSubmitting)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().opacity(0.4)

            List {
                Section {
                    if store.notesForSelectedPR.isEmpty {
                        Text("シンボルを選んでメモを追加")
                            .font(Theme.monoCaption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.notesForSelectedPR) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(note.symbolName)  \(note.filePath):\(note.line)")
                                    .font(Theme.monoCaption2)
                                    .foregroundStyle(Theme.accent)
                                Text(note.body)
                                    .font(Theme.monoCaption)
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
                } header: {
                    Text("draft")
                        .font(Theme.monoCaption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Section {
                    if store.remoteComments.isEmpty {
                        Text("— none —")
                            .font(Theme.monoCaption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.remoteCommentsForSelectedFile) { comment in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(comment.user?.login ?? "unknown")
                                        .font(Theme.monoCaption2.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                    Spacer()
                                    if let line = comment.line {
                                        Text("L\(line)")
                                            .font(Theme.monoCaption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if let path = comment.path {
                                    Text(path)
                                        .font(Theme.monoCaption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(comment.body)
                                    .font(Theme.monoCaption)
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
                } header: {
                    Text(
                        store.remoteCommentCountForSelectedFile > 0
                            ? "on-github  sel:\(store.remoteCommentCountForSelectedFile)/\(store.remoteComments.count)"
                            : "on-github  \(store.remoteComments.count)"
                    )
                    .font(Theme.monoCaption2.weight(.bold))
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
            Text("note")
                .font(Theme.monoCallout.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text("\(symbolName) · \(filePath):\(line)")
                .font(Theme.monoCaption)
                .foregroundStyle(.secondary)
            TextEditor(text: $bodyText)
                .font(Theme.mono)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.accent.opacity(0.35))
                )
            HStack {
                Spacer()
                Button("cancel", action: onCancel)
                    .font(Theme.monoCaption)
                    .keyboardShortcut(.cancelAction)
                Button("save") {
                    onSave(bodyText)
                }
                .font(Theme.monoCaption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 420)
    }
}
