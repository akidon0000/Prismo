import SwiftUI

struct PRListView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var languageFilter: Language? = nil

    private var filtered: [PullRequest] {
        let base = store.filteredPullRequests(query: query, language: languageFilter)
        if settings.showAssignedOnly {
            return base.filter(\.isAssignedToMe)
        }
        return base
    }

    var body: some View {
        List(selection: Binding(
            get: { store.selectedPRID },
            set: { id in
                guard let id, let pr = store.pullRequests.first(where: { $0.id == id }) else { return }
                store.select(pr, settings: settings)
            }
        )) {
            Section("レビュー依頼（自分）") {
                ForEach(filtered.filter(\.isAssignedToMe)) { pr in
                    PRRow(pr: pr)
                        .tag(pr.id)
                }
            }
            Section("その他") {
                ForEach(filtered.filter { !$0.isAssignedToMe }) { pr in
                    PRRow(pr: pr)
                        .tag(pr.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Prismo")
        .searchable(text: $query, prompt: "タイトル / リポ / 作者")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $settings.showAssignedOnly) {
                    Image(systemName: settings.showAssignedOnly ? "person.fill.checkmark" : "person.2")
                }
                .toggleStyle(.button)
                .help(settings.showAssignedOnly ? "アサイン済みのみ表示中" : "すべて表示中")
            }
            ToolbarItem(placement: .automatic) {
                Picker("言語", selection: $languageFilter) {
                    Text("すべて").tag(Optional<Language>.none)
                    ForEach([Language.swift, .kotlin, .dart]) { lang in
                        Text(lang.label).tag(Optional(lang))
                    }
                }
                .pickerStyle(.menu)
                .help("言語で絞り込み")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = store.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct PRRow: View {
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: pr.language.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(pr.repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("#\(pr.number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(pr.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(pr.author)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                Text(pr.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help(pr.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(.vertical, 2)
    }
}
