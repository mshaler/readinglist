import SwiftUI

struct SettingsView: View {
    var store: SmartFolderStore
    var accessManager: BookmarkAccessManager

    private let router = SettingsRouter.shared

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(accessManager: accessManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            SmartFolderManagerView(store: store)
                .tabItem {
                    Label("Smart Lists", systemImage: "line.3.horizontal.decrease.circle")
                }
                .tag(SettingsTab.smartLists)
        }
        .onAppear {
            applyPendingNavigation()
        }
        .onChange(of: store.pendingEditFolderID) {
            applyPendingNavigation()
        }
        .onChange(of: router.pendingTab) {
            applyPendingNavigation()
        }
    }

    private func applyPendingNavigation() {
        if store.pendingEditFolderID != nil {
            selectedTab = .smartLists
        }
        if let tab = router.pendingTab {
            selectedTab = tab
            router.pendingTab = nil
        }
    }
}

private struct GeneralSettingsView: View {
    var accessManager: BookmarkAccessManager

    var body: some View {
        Form {
            Section("Safari Bookmarks") {
                LabeledContent("File") {
                    Text(filePathDescription)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }

                if isDemoDataModeEnabled {
                    Text("Running with demo data — file access is disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button("Change File\u{2026}") {
                            accessManager.promptUserToSelectFile()
                        }

                        Button("Back Up\u{2026}") {
                            if case let .ready(url) = accessManager.state {
                                BookmarksBackup.promptAndSave(bookmarksPlistURL: url)
                            }
                        }
                        .disabled(!accessManager.state.isReady)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 640, height: 200)
    }

    private var filePathDescription: String {
        guard case let .ready(url) = accessManager.state else {
            return "Not selected"
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(homePath) {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }
}
