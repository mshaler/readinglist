# Session: dark mode, multi-select, and making deletions stick

2026-10-15 to 2026-10-20. Fork of marckohlbrugge/readinglist, installed locally as Reading List 1.3.2 signed with Michael's Developer ID.

## Shipped

| Feature | Commit |
|---|---|
| Moon toggle that forces web previews dark (CSS invert, media re-inverted, preview pinned to light appearance while forced) | 7171952 |
| Multi-select in the item list; ⌫ and context menu act on the whole selection | 0702b20, 09f4168 |
| Deleting quits Safari first, via a quit Apple Event | fbd9be3 |
| Deleting a URL removes its hidden duplicate copies | f05d23e |
| `www.example.com` and `example.com` count as one website; "Other Websites" holds sites below the 10-item cutoff | 68303cc |
| Deletions are staged in a Pending Deletions edit list and applied to Safari in one write | 2c83a54 |

## What we learned

### Safari undoes deletions made while it runs

Symptom: items deleted in the app were still in Safari on the Mac and the iPhone, and the app still showed 2,000+ unread.

Evidence:
- A backup of `Bookmarks.plist` showed every Reading List item carries iCloud sync metadata (`Sync.ServerID` plus an archived `CKRecord`), and the root holds CloudKit sync state.
- Safari rewrote the file on its own (modified at 10:09 with no app activity).
- Test: quit Safari, delete one item in the app, reopen Safari. The item stayed gone on the Mac and the iPhone.

Conclusion: Safari keeps the Reading List in memory and writes it back, which overwrites edits made to the file while it's open. If Safari is quit when an item is removed, it notices the removal when it next opens and syncs it to other devices.

### Read state is different

Marking an item read while Safari was open stuck on the Mac, the iPhone and in the app. Only deletions get undone, so read state needs no special handling.

### Duplicates

26 URLs had more than one entry. The app shows one row per URL (the newest), so deleting the row used to leave the older copies behind.

### The Websites section never added up to All

The Websites section only lists sites with 10 or more items. From the backup: 2,024 unread items, of which 871 were in 31 listed sites and 1,153 were spread across 717 smaller sites. "Other Websites" now closes that gap.

## Decisions

- **Deleting stages, applying deletes.** Staging is reversible, so it has no confirmation dialog and no opt-in setting; the Settings → Advanced tab was removed. Applying offers a backup, quits Safari, deletes everything in one write, and reports how many items were already gone.
- **Skip items that are already gone** rather than failing the whole batch. Staged items Safari no longer has are also dropped on reload.
- **The edit list persists** in `~/Library/Application Support/ReadingList/pending-deletions.json` (inside the sandbox container for the installed app). Demo mode keeps it in memory only.
- **Quitting Safari uses an Apple Event**, because sandboxed apps can't call `NSRunningApplication.terminate()` on other apps. This needs `com.apple.security.automation.apple-events`, a temporary exception for `com.apple.Safari`, and `NSAppleEventsUsageDescription`.
- **The version is pinned to 1.3.2** so the update checker, which polls upstream's releases, stays quiet until upstream ships something newer.

## iPhone: researched, not started

iOS gives no access to Safari's Reading List; `SSReadingList` can only add items. Options, best first:

1. **Mac relays to iPhone through CloudKit, with changes written back.** About 2 weeks. Needs the Mac app running, and handling conflicts with Safari's own sync is the risky part.
2. **Read-only relay.** About 1 week. Browse with smart lists and domains on the iPhone; change things on the Mac.
3. **A separate list of the app's own**, not Safari's. That would be a different product.

Undecided. Plan: keep a "Reading List wishes" note on the phone for a week, then pick option 1, option 2 or neither.

## Loose ends

- `SettingsRouter` now has no caller that sets `pendingTab`.
- `SafariReadingListService.deleteItem(url:dateAdded:)` is only used by tests.
- The x86_64 build prints a deprecation warning that cites a deployment target of macOS 27.0, though `Package.swift` says macOS 14.
