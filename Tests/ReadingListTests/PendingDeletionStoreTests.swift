import Foundation
@testable import ReadingList
import Testing

@MainActor
@Suite("PendingDeletionStore")
struct PendingDeletionStoreTests {
    private func makeItem(_ title: String) -> ReadingListItem {
        ReadingListItem(
            title: title,
            url: URL(string: "https://example.com/\(title)")!,
            previewText: nil,
            dateAdded: Date(timeIntervalSinceReferenceDate: 700_000_000),
            dateLastViewed: nil
        )
    }

    @Test func stagedItemsSurviveARestart() {
        let storageURL = FileManager.default.temporaryDirectory
            .appending(path: "pending-\(UUID().uuidString).json", directoryHint: .notDirectory)
        defer { try? FileManager.default.removeItem(at: storageURL) }

        let store = PendingDeletionStore(storageURL: storageURL)
        store.stage([makeItem("A"), makeItem("B")])
        store.unstage(ids: [makeItem("A").id])

        let reopened = PendingDeletionStore(storageURL: storageURL)
        #expect(reopened.ids == [makeItem("B").id])
        #expect(reopened.entries.first?.title == "B")
    }

    @Test func storeWithoutStorageURLKeepsNothingOnDisk() {
        let store = PendingDeletionStore(storageURL: nil)
        store.stage([makeItem("A")])

        #expect(store.ids == [makeItem("A").id])
        #expect(PendingDeletionStore(storageURL: nil).ids.isEmpty)
    }

    @Test func stagingTheSameItemTwiceKeepsOneEntry() {
        let store = PendingDeletionStore(storageURL: nil)
        store.stage([makeItem("A")])
        store.stage([makeItem("A")])

        #expect(store.entries.count == 1)
    }
}
