import AppKit
import WebKit

/// Forces web previews dark by inverting the page's colors, then inverting
/// media back so photos and video keep their real colors.
@MainActor
enum PreviewDarkMode {
    private static let styleElementID = "readinglist-preview-dark-mode"

    private static let css = """
    html {
        filter: invert(1) hue-rotate(180deg) !important;
        background-color: #fff !important;
    }
    img, picture, video, canvas, iframe, embed, object {
        filter: invert(1) hue-rotate(180deg) !important;
    }
    """

    /// Applies the setting to the current page and to every page loaded afterwards.
    static func apply(_ isEnabled: Bool, to webView: WKWebView) {
        // Inversion assumes a light page. Pinning the web view to the light
        // appearance stops sites that honor prefers-color-scheme from serving
        // a dark theme that would then be inverted back to light.
        webView.appearance = isEnabled ? NSAppearance(named: .aqua) : nil

        let source = script(isEnabled: isEnabled)
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(
            WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        webView.evaluateJavaScript(source)
    }

    private static func script(isEnabled: Bool) -> String {
        """
        (() => {
            const existing = document.getElementById("\(styleElementID)");
            if (!\(isEnabled)) {
                existing?.remove();
                return;
            }
            if (existing) {
                return;
            }
            const style = document.createElement("style");
            style.id = "\(styleElementID)";
            style.textContent = `\(css)`;
            (document.head || document.documentElement).appendChild(style);
        })();
        """
    }
}
