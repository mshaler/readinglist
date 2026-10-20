import Foundation

struct ReadingListItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let hostname: String
    let previewText: String?
    let dateAdded: Date?
    let dateLastViewed: Date?

    var isViewed: Bool {
        dateLastViewed != nil
    }

    init(
        title: String,
        url: URL,
        previewText: String?,
        dateAdded: Date?,
        dateLastViewed: Date?
    ) {
        self.title = title
        self.url = url
        let normalizedHost = url.host.map(Self.normalizedHostname) ?? ""
        hostname = normalizedHost.isEmpty ? "(no host)" : normalizedHost
        self.previewText = previewText
        self.dateAdded = dateAdded
        self.dateLastViewed = dateLastViewed

        let dateStamp = dateAdded?.timeIntervalSince1970 ?? 0
        id = "\(url.absoluteString)|\(dateStamp)"
    }

    /// Lowercased, without a leading "www.", so www.example.com and
    /// example.com count as the same website.
    static func normalizedHostname(_ host: String) -> String {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
