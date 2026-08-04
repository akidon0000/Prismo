import SwiftUI

struct PRListView: View {
    @ObservedObject var store: ReviewStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedPRID },
            set: { id in
                guard let id, let pr = store.pullRequests.first(where: { $0.id == id }) else { return }
                store.select(pr)
            }
        )) {
            Section("レビュー依頼（自分）") {
                ForEach(store.pullRequests.filter(\.isAssignedToMe)) { pr in
                    PRRow(pr: pr)
                        .tag(pr.id)
                }
            }
            Section("その他") {
                ForEach(store.pullRequests.filter { !$0.isAssignedToMe }) { pr in
                    PRRow(pr: pr)
                        .tag(pr.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Prismo")
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
            Text(pr.author)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
