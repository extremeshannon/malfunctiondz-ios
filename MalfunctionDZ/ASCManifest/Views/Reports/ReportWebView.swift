import SwiftUI
import WebKit

struct ReportWebView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var reportsStore: ReportsStore

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let report = reportsStore.selectedReport {
                AuthenticatedReportWebView(
                    reportPath: report.path,
                    baseURL: session.environment.baseURL,
                    token: session.token,
                    dropzoneSlug: ManifestAppConfig.dropzoneSlug
                )
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightOps.surface.ignoresSafeArea())
        .navigationTitle(reportsStore.selectedReport?.title ?? "Reports")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            NightOps.gradientBar.frame(height: 4)
            Text(reportsStore.selectedReport?.title ?? "Pick a report")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Same reports as the web hub — filters and export work in-page.")
                .font(.caption)
                .foregroundStyle(NightOps.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(NightOps.navy)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(NightOps.textMuted)
            Text("Select a report")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Choose a report from the list on the left.")
                .font(.footnote)
                .foregroundStyle(NightOps.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AuthenticatedReportWebView: UIViewRepresentable {
    let reportPath: String
    let baseURL: URL
    let token: String?
    let dropzoneSlug: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(NightOps.surface)
        webView.scrollView.backgroundColor = UIColor(NightOps.surface)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedPath != reportPath else { return }
        context.coordinator.loadedPath = reportPath
        guard let token, !token.isEmpty else { return }

        var base = baseURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        var components = URLComponents(string: "\(base)/api/manifest/web-session")!
        components.queryItems = [URLQueryItem(name: "next", value: reportPath)]
        guard let sessionURL = components.url else { return }

        var request = URLRequest(url: sessionURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(dropzoneSlug, forHTTPHeaderField: "X-Dropzone-Slug")
        webView.load(request)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedPath: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Reports pages are light-themed; no injection needed.
        }
    }
}
