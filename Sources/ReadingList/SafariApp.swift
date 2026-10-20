import AppKit
import CoreServices

/// Safari keeps the Reading List in memory while it runs and writes it back
/// to Bookmarks.plist, undoing any deletion made to the file in the meantime.
/// Deletions only stick, and only sync to other devices, when made while
/// Safari is quit; Safari picks them up and syncs them the next time it opens.
@MainActor
enum SafariApp {
    private static var runningInstances: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari")
    }

    static var isRunning: Bool {
        !runningInstances.isEmpty
    }

    /// Asks Safari to quit and waits for it to exit. Returns `false` if Safari
    /// is still running when the wait ends, e.g. because the user cancelled
    /// Safari's own "quit with open tabs?" prompt or denied permission to
    /// control Safari.
    static func quit(timeout: Duration = .seconds(30)) async -> Bool {
        let instances = runningInstances

        // Sandboxed apps can't use NSRunningApplication.terminate() on other
        // apps, so this sends Safari a quit Apple Event instead. Not waiting for
        // a reply keeps the UI responsive while Safari shows its own prompts.
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEQuitApplication),
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.Safari"),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            try event.sendEvent(options: [.noReply], timeout: 10)
        } catch {
            return false
        }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if instances.allSatisfy(\.isTerminated) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return instances.allSatisfy(\.isTerminated)
    }
}
