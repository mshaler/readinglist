import Foundation
@testable import ReadingList
import Testing
import WebKit

@MainActor
@Suite("PreviewDarkMode")
struct PreviewDarkModeTests {
    private let page = """
    <html><body style="background:#fff;color:#000">
    <p>Hello</p><img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=">
    </body></html>
    """

    @Test func enabledInvertsPageAndRestoresImages() async throws {
        let webView = WKWebView()
        PreviewDarkMode.apply(true, to: webView)
        try await load(page, in: webView)

        #expect(try await filter(of: "document.documentElement", in: webView).contains("invert(1)"))
        #expect(try await filter(of: "document.querySelector('img')", in: webView).contains("invert(1)"))
        #expect(webView.appearance?.name == .aqua)
    }

    @Test func disabledLeavesPageUntouched() async throws {
        let webView = WKWebView()
        PreviewDarkMode.apply(false, to: webView)
        try await load(page, in: webView)

        #expect(try await filter(of: "document.documentElement", in: webView) == "none")
        #expect(webView.appearance == nil)
    }

    @Test func togglingAppliesToLoadedPageWithoutReload() async throws {
        let webView = WKWebView()
        PreviewDarkMode.apply(false, to: webView)
        try await load(page, in: webView)

        PreviewDarkMode.apply(true, to: webView)
        #expect(try await filter(of: "document.documentElement", in: webView).contains("invert(1)"))

        PreviewDarkMode.apply(false, to: webView)
        #expect(try await filter(of: "document.documentElement", in: webView) == "none")
    }

    private func filter(of element: String, in webView: WKWebView) async throws -> String {
        let result = try await webView.evaluateJavaScript("getComputedStyle(\(element)).filter")
        return try #require(result as? String)
    }

    private func load(_ html: String, in webView: WKWebView) async throws {
        let delegate = NavigationWaiter()
        webView.navigationDelegate = delegate
        try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Error>?

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
