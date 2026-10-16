import Foundation
@testable import ReadingList
import Testing

@MainActor
@Suite("ReadingListViewModel")
struct ReadingListViewModelTests {
    /// Items A (newest) through E (oldest), listed in that order.
    private func makeViewModel() -> ReadingListViewModel {
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
            demoItems: items
        )
        viewModel.statusFilter = .all
        viewModel.sortOrder = .newestFirst
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
}
