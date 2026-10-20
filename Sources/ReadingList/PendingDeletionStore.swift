import Foundation
import Observation

/// An item the user deleted in this app that hasn't been removed from Safari
/// yet. Deleting only stages items; they're removed from Safari together when
/// the user applies the edit list.
struct PendingDeletion: Codable, Hashable, Sendable {
    let id: ReadingListItem.ID
    let title: String
    let url: URL
    let dateAdded: Date?

    init(item: ReadingListItem) {
        id = item.id
        title = item.title
        url = item.url
        dateAdded = item.dateAdded
    }

    /// Enough of the item to find it in Safari's bookmarks file.
    var item: ReadingListItem {
        ReadingListItem(title: title, url: url, previewText: nil, dateAdded: dateAdded, dateLastViewed: nil)
    }
}

/// The edit list of pending deletions, saved to
/// `~/Library/Application Support/ReadingList/pending-deletions.json` so it
/// survives relaunches.
@MainActor
@Observable
final class PendingDeletionStore {
    private(set) var entries: [PendingDeletion] = []

    var ids: Set<ReadingListItem.ID> {
        Set(entries.map(\.id))
    }

    /// `nil` keeps the edit list in memory only, for demo mode and tests.
    private let storageURL: URL?

    init(storageURL: URL?) {
        self.storageURL = storageURL
        loadFromDisk()
    }

    static func defaultStorageURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return applicationSupportURL
            .appending(path: "ReadingList", directoryHint: .isDirectory)
            .appending(path: "pending-deletions.json", directoryHint: .notDirectory)
    }

    func stage(_ items: [ReadingListItem]) {
        let existingIDs = ids
        let newEntries = items
            .filter { !existingIDs.contains($0.id) }
            .map(PendingDeletion.init(item:))
        guard !newEntries.isEmpty else {
            return
        }
        entries.append(contentsOf: newEntries)
        saveToDisk()
    }

    func unstage(ids: Set<ReadingListItem.ID>) {
        let countBefore = entries.count
        entries.removeAll { ids.contains($0.id) }
        if entries.count != countBefore {
            saveToDisk()
        }
    }

    private func loadFromDisk() {
        guard let storageURL, let data = try? Data(contentsOf: storageURL) else {
            return
        }
        do {
            entries = try JSONDecoder().decode([PendingDeletion].self, from: data)
        } catch {
            NSLog("Failed to decode pending deletions: \(error.localizedDescription)")
        }
    }

    private func saveToDisk() {
        guard let storageURL else {
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: storageURL, options: .atomic)
        } catch {
            NSLog("Failed to save pending deletions: \(error.localizedDescription)")
        }
    }
}
