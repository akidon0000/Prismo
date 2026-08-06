import SwiftUI

struct PRListView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var languageFilter: Language? = nil
    @State private var otherExpanded = false
    @AppStorage("ui.showInboxFilters") private var showFilters = false

    private var filtered: [PullRequest] {
        let base = store.filteredPullRequests(query: query, language: languageFilter)
        if settings.showAssignedOnly {
            return base.filter(\.isAssignedToMe)
        }
        return base
    }

    private var assigned: [PullRequest] { filtered.filter(\.isAssignedToMe) }
    private var others: [PullRequest] { filtered.filter { !$0.isAssignedToMe } }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { store.selectedPRID },
                set: { id in
                    guard let id, let pr = store.pullRequests.first(where: { $0.id == id }) else { return }
                    store.select(pr, settings: settings)
                }
            )) {
                Section {
                    ForEach(assigned) { pr in
                        PRRow(pr: pr)
                            .tag(pr.id)
                    }
                } header: {
                    Text("レビュー依頼")
                        .font(Theme.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section(isExpanded: $otherExpanded) {
                    ForEach(others) { pr in
                        PRRow(pr: pr)
                            .tag(pr.id)
                    }
                } header: {
                    Text("その他（\(others.count)）")
                        .font(Theme.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("Inbox")
        .navigationSubtitle(settings.activeAccount?.shortTitle ?? "Prismo")
        .searchable(text: $query, prompt: "タイトル、リポジトリ、作者")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $showFilters) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .toggleStyle(.button)
                .help("フィルタ")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if showFilters {
                    filterBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let error = store.lastError {
                    Text(error)
                        .font(Theme.caption2)
                        .foregroundStyle(Theme.risk)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.risk.opacity(0.08))
                }
            }
        }
        .onAppear {
            otherExpanded = assigned.isEmpty
        }
        .onChange(of: assigned.count) { _, count in
            if count > 0 { otherExpanded = false }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $settings.showAssignedOnly) {
                Text("依頼のみ")
                    .font(Theme.caption)
            }
            .toggleStyle(.checkbox)

            Picker("言語", selection: $languageFilter) {
                Text("すべて").tag(Optional<Language>.none)
                ForEach([Language.swift, .kotlin, .dart]) { lang in
                    Text(lang.label).tag(Optional(lang))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 120)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct PRRow: View {
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: pr.language.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(pr.repository)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("#\(pr.number)")
                    .font(Theme.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(pr.title)
                .font(Theme.callout.weight(.medium))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(pr.author)
                    .font(Theme.caption2)
                    .foregroundStyle(.tertiary)
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(pr.updatedAt, style: .relative)
                    .font(Theme.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }
}
