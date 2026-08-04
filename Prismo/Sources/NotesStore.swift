import Foundation

/// レビューメモの永続化（Application Support/Prismo/notes.json）。
enum NotesStore {
    private static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Prismo", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("notes.json")
    }

    static func load() -> [ReviewNote] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ReviewNote].self, from: data)) ?? []
    }

    static func save(_ notes: [ReviewNote]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
