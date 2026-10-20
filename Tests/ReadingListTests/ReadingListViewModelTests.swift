import Foundation
@testable import ReadingList
import Testing

@MainActor
@Suite("ReadingListViewModel")
struct ReadingListViewModelTests {
    /// Items A (newest) through E (oldest), listed in that order.
    private func makeViewModel(
        pendingDeletionStore: PendingDeletionStore = PendingDeletionStore(storageURL: nil)
    ) -> ReadingListViewModel {
        let items = ["A", "B", "C", "D", "E"].enumerated().map { index, title in
            ReadingListItem(
                title: title,
                url: URL(string: "https://example.com/\(title)")!,
                previewText: nil,
                dateAdded: Date(timeIntervalSinceReferenceDate: 700_000_000 - Double(index) * 60),
                dateLastViewed: nil
            )
        }
        let storageURL = FileManager.default.temporaryDirectory
            .appending(path: "smart-folders-\(UUID().uuidString).json", directoryHint: .notDirectory)
        let viewModel = ReadingListViewModel(
            smartFolderStore: SmartFolderStore(storageURL: storageURL),
            pendingDeletionStore: pendingDeletionStore,
            demoItems: items
        )
        viewModel.statusFilter = .all
        viewModel.sortOrder = .newestFirst
        viewModel.reload()
        return viewModel
    }

    /// Unread items: `count` from each host, oldest first, with distinct dates.
    private func makeViewModel(hostCounts: [(host: String, count: Int)]) -> ReadingListViewModel {
        var items: [ReadingListItem] = []
        for (host, count) in hostCounts {
            for index in 0 ..< count {
                items.append(ReadingListItem(
                    title: "\(host) \(index)",
                    url: URL(string: "https://\(host)/\(index)")!,
                    previewText: nil,
                    dateAdded: Date(timeIntervalSinceReferenceDate: 700_000_000 - Double(items.count) * 60),
                    dateLastViewed: nil
                ))
            }
        }
        let storageURL = FileManager.default.temporaryDirectory
            .appending(path: "smart-folders-\(UUID().uuidString).json", directoryHint: .notDirectory)
        let viewModel = ReadingListViewModel(
            smartFolderStore: SmartFolderStore(storageURL: storageURL),
            pendingDeletionStore: PendingDeletionStore(storageURL: nil),
            demoItems: items
        )
        viewModel.statusFilter = .all
        viewModel.reload()
        return viewModel
    }

    private func select(_ titles: Set<String>, in viewModel: ReadingListViewModel) {
        viewModel.selectedItemIDs = Set(viewModel.filteredItems.filter { titles.contains($0.title) }.map(\.id))
    }

    private func selectedTitles(_ viewModel: ReadingListViewModel) -> Set<String> {
        Set(viewModel.selectedItems.map(\.title))
    }

    @Test func selectedItemIsOnlySetForASingleSelection() {
        let viewModel = makeViewModel()

        select(["B"], in: viewModel)
        #expect(viewModel.selectedItem?.title == "B")

        select(["B", "C"], in: viewModel)
        #expect(viewModel.selectedItem == nil)
        #expect(viewModel.selectedItems.map(\.title) == ["B", "C"])
    }

    @Test func deletingSelectionRemovesAllAndSelectsNextRemainingItem() {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)

        viewModel.delete(viewModel.selectedItems)

        #expect(viewModel.filteredItems.map(\.title) == ["A", "D", "E"])
        #expect(selectedTitles(viewModel) == ["D"])
    }

    @Test func deletingSelectionAtEndSelectsPreviousItem() {
        let viewModel = makeViewModel()
        select(["D", "E"], in: viewModel)

        viewModel.delete(viewModel.selectedItems)

        #expect(viewModel.filteredItems.map(\.title) == ["A", "B", "C"])
        #expect(selectedTitles(viewModel) == ["C"])
    }

    @Test func deletingEverythingClearsSelection() {
        let viewModel = makeViewModel()
        select(["A", "B", "C", "D", "E"], in: viewModel)

        viewModel.delete(viewModel.selectedItems)

        #expect(viewModel.filteredItems.isEmpty)
        #expect(viewModel.selectedItemIDs.isEmpty)
    }

    @Test func deletingUnselectedItemKeepsSelection() throws {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)

        let itemE = try #require(viewModel.filteredItems.last)
        viewModel.delete([itemE])

        #expect(selectedTitles(viewModel) == ["B", "C"])
    }

    @Test func filteringDropsSelectedItemsThatAreNoLongerShown() {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)

        viewModel.searchQuery = "example.com/B"

        #expect(selectedTitles(viewModel) == ["B"])
    }

    @Test func wwwAndBareHostAreOneWebsite() {
        let viewModel = makeViewModel(hostCounts: [("www.example.com", 6), ("example.com", 6)])

        #expect(viewModel.frequentDomainFolders.map(\.hostname) == ["example.com"])
        #expect(viewModel.frequentDomainFolders.first?.count == 12)
    }

    @Test func otherWebsitesHoldsSitesBelowTheCutoff() {
        let viewModel = makeViewModel(hostCounts: [("big.com", 10), ("small.com", 3), ("tiny.com", 1)])

        #expect(viewModel.frequentDomainFolders.map(\.hostname) == ["big.com"])
        #expect(viewModel.otherDomainsCount == 4)

        viewModel.selectedFolder = .otherDomains
        #expect(Set(viewModel.filteredItems.map(\.hostname)) == ["small.com", "tiny.com"])
    }

    @Test func websitesAddUpToAll() {
        let viewModel = makeViewModel(hostCounts: [("a.com", 12), ("www.b.com", 10), ("c.com", 9), ("d.com", 2)])

        let websitesTotal = viewModel.frequentDomainFolders.map(\.count).reduce(0, +) + viewModel.otherDomainsCount
        #expect(websitesTotal == viewModel.allCount)
    }

    @Test func deletingStagesItemsInsteadOfRemovingThem() {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)

        viewModel.delete(viewModel.selectedItems)

        #expect(viewModel.allCount == 3)
        #expect(viewModel.pendingDeletionCount == 2)
        viewModel.selectedFolder = .pendingDeletions
        #expect(viewModel.filteredItems.map(\.title) == ["B", "C"])
    }

    @Test func restoringReturnsItemsToTheirLists() throws {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)
        viewModel.delete(viewModel.selectedItems)

        viewModel.selectedFolder = .pendingDeletions
        let itemB = try #require(viewModel.filteredItems.first { $0.title == "B" })
        viewModel.restore([itemB])

        #expect(viewModel.pendingDeletionCount == 1)
        viewModel.selectedFolder = .all
        #expect(viewModel.filteredItems.map(\.title) == ["A", "B", "D", "E"])
    }

    @Test func applyingRemovesStagedItemsAndEmptiesTheEditList() async throws {
        let viewModel = makeViewModel()
        select(["B", "C"], in: viewModel)
        viewModel.delete(viewModel.selectedItems)

        let result = try await viewModel.applyPendingDeletions()

        #expect(result == PendingDeletionResult(deletedCount: 2, alreadyGoneCount: 0))
        #expect(viewModel.pendingDeletionCount == 0)
        #expect(viewModel.allCount == 3)
    }

    @Test func stagedItemsStayHiddenAfterRelaunch() {
        let pendingStore = PendingDeletionStore(storageURL: nil)
        let first = makeViewModel(pendingDeletionStore: pendingStore)
        select(["B"], in: first)
        first.delete(first.selectedItems)

        let relaunched = makeViewModel(pendingDeletionStore: pendingStore)

        #expect(relaunched.filteredItems.map(\.title) == ["A", "C", "D", "E"])
        #expect(relaunched.pendingDeletionCount == 1)
    }

    @Test func reloadDropsStagedItemsThatAreGoneFromSafari() {
        let pendingStore = PendingDeletionStore(storageURL: nil)
        pendingStore.stage([ReadingListItem(
            title: "Gone",
            url: URL(string: "https://example.com/gone")!,
            previewText: nil,
            dateAdded: nil,
            dateLastViewed: nil
        )])

        let viewModel = makeViewModel(pendingDeletionStore: pendingStore)

        #expect(viewModel.pendingDeletionCount == 0)
        #expect(pendingStore.ids.isEmpty)
    }
}
