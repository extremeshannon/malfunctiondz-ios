// File: ASC/Views/GroundSchool/LessonDetailView.swift
// Purpose: Displays lesson content with YouTube video embedding, scroll-to-bottom
//          gate for mark complete, and previous/next lesson navigation.
import SwiftUI
import WebKit
import SafariServices

// MARK: - Models

struct LessonDetail: Codable {
    let id: Int
    let title: String
    let lessonType: String
    let contentUrl: String?
    let content: String?
    let durationMin: Int?
    let required: Bool
    let courseId: Int
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, content, required, completed
        case lessonType  = "lesson_type"
        case contentUrl  = "content_url"
        case durationMin = "duration_min"
        case courseId    = "course_id"
    }
}

struct LessonDetailResponse: Codable {
    let ok: Bool
    let lesson: LessonDetail?
}

// MARK: - YouTube Player

struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    var onVideoFinished: (() -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedVideoId != videoId else { return }
        context.coordinator.lastLoadedVideoId = videoId
        // Load the embed URL directly so the WebView's origin is YouTube — avoids
        // error 152-4 ("video unavailable") caused by loadHTMLString referrer/baseURL issues.
        let embedURLString = "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&rel=0"
        guard let url = URL(string: embedURLString) else { return }
        var request = URLRequest(url: url)
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator { Coordinator(onVideoFinished: onVideoFinished) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onVideoFinished: (() -> Void)?
        var lastLoadedVideoId: String?
        init(onVideoFinished: (() -> Void)?) { self.onVideoFinished = onVideoFinished }
    }
}

// MARK: - Safari full-screen player (reliable playback; avoids 152-4 in WebView)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariVideoView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - HTML Lesson Content (with clickable images)

struct HTMLLessonWebView: UIViewRepresentable {
    let html: String
    var onImageTapped: ((URL) -> Void)?
    var onContentHeightChanged: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageTapped: onImageTapped, onContentHeightChanged: onContentHeightChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "imageTapped")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.navigationDelegate = context.coordinator

        let baseURL = URL(string: "\(kServerURL)/")
        let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasHtml = body.contains("<") && body.contains(">")
        let wrappedHtml = hasHtml ? body : "<p>\(body.replacingOccurrences(of: "\n", with: "<br>"))</p>"

        let fullHtml = """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:16px;line-height:1.55;color:rgba(232,237,245,0.95);background:transparent;margin:0;padding:0;}
        h1,h2,h3{color:rgba(232,237,245,0.98);margin:0.8em 0 0.4em;}
        p,ul,ol{margin:0.6em 0;}
        ul,ol{padding-left:1.5em;}
        img{max-width:100%;height:auto;border-radius:8px;cursor:pointer;border:1px solid rgba(255,255,255,0.2);}
        img:active{opacity:0.9;}
        a{color:#F39C12;}
        </style></head><body>\(wrappedHtml)
        <script>
        document.querySelectorAll('img').forEach(function(img){
          img.onclick=function(){window.webkit.messageHandlers.imageTapped.postMessage(img.src);};
        });
        </script></body></html>
        """
        wv.loadHTMLString(fullHtml, baseURL: baseURL)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastHtml != html {
            context.coordinator.lastHtml = html
            let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasHtml = body.contains("<") && body.contains(">")
            let wrappedHtml = hasHtml ? body : "<p>\(body.replacingOccurrences(of: "\n", with: "<br>"))</p>"
            let fullHtml = """
            <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
            <style>body{font-family:-apple-system;font-size:16px;line-height:1.55;color:rgba(232,237,245,0.95);background:transparent;}img{max-width:100%;cursor:pointer;}</style></head><body>\(wrappedHtml)
            <script>document.querySelectorAll('img').forEach(function(img){img.onclick=function(){window.webkit.messageHandlers.imageTapped.postMessage(img.src);};});</script></body></html>
            """
            wv.loadHTMLString(fullHtml, baseURL: URL(string: "\(kServerURL)/"))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onImageTapped: ((URL) -> Void)?
        var onContentHeightChanged: ((CGFloat) -> Void)?
        var lastHtml: String = ""

        init(onImageTapped: ((URL) -> Void)?, onContentHeightChanged: ((CGFloat) -> Void)?) {
            self.onImageTapped = onImageTapped
            self.onContentHeightChanged = onContentHeightChanged
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "imageTapped", let src = message.body as? String, let url = URL(string: src) else { return }
            onImageTapped?(url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.body.offsetHeight)") { val, _ in
                guard let h = val as? CGFloat, h > 0 else { return }
                DispatchQueue.main.async { self.onContentHeightChanged?(h) }
            }
        }
    }
}

// MARK: - Fullscreen image (tap to enlarge)
struct EnlargeableImageSheet: View {
    let imageURL: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .failure: Text("Could not load image").foregroundColor(.white)
                default: ProgressView().tint(.white)
                }
            }
        }
        .onTapGesture { onDismiss() }
    }
}

// MARK: - Helpers

func extractYouTubeId(from text: String) -> String? {
    // Patterns: youtu.be/ID, youtube.com/watch?v=ID, youtube.com/embed/ID
    let patterns = [
        "youtu\\.be/([a-zA-Z0-9_-]{11})",
        "youtube\\.com/watch\\?v=([a-zA-Z0-9_-]{11})",
        "youtube\\.com/embed/([a-zA-Z0-9_-]{11})",
    ]
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
    }
    return nil
}

// MARK: - ViewModel

@MainActor
class LessonDetailViewModel: ObservableObject {
    @Published var lesson: LessonDetail?
    @Published var isLoading = false
    @Published var isMarkingComplete = false
    @Published var completed = false
    @Published var hasScrolledToBottom = false
    @Published var videoFinished = false
    @Published var error: String?

    let lessonId: Int

    init(lessonId: Int) { self.lessonId = lessonId }

    var canComplete: Bool {
        if completed { return false }
        guard let lesson = lesson else { return false }
        let youtubeId = extractYouTubeId(from: lesson.content ?? "")
        if youtubeId != nil {
            return videoFinished
        }
        return hasScrolledToBottom
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/lesson.php?id=\(lessonId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(LessonDetailResponse.self, from: data)
            if let l = resp.lesson {
                lesson = l
                completed = l.completed
                if l.completed { hasScrolledToBottom = true; videoFinished = true }
            }
        } catch { self.error = error.localizedDescription }
    }

    func markComplete(courseId: Int) async {
        guard !completed else { return }
        isMarkingComplete = true
        defer { isMarkingComplete = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/lesson.php?id=\(lessonId)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            completed = true
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - View

struct LessonDetailView: View {
    let lessonId: Int
    let lessonTitle: String
    var allLessons: [LMSLesson] = []
    var courseId: Int = 0

    @StateObject private var vm: LessonDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var safariVideoURL: IdentifiableURL?
    @State private var enlargedImageURL: URL?
    @State private var htmlContentHeight: CGFloat = 300

    init(lessonId: Int, lessonTitle: String, allLessons: [LMSLesson] = [], courseId: Int = 0) {
        self.lessonId    = lessonId
        self.lessonTitle = lessonTitle
        self.allLessons  = allLessons
        self.courseId    = courseId
        _vm = StateObject(wrappedValue: LessonDetailViewModel(lessonId: lessonId))
    }

    private var currentIndex: Int? { allLessons.firstIndex(where: { $0.id == lessonId }) }
    private var prevLesson: LMSLesson? {
        guard let idx = currentIndex, idx > 0 else { return nil }
        return allLessons[idx - 1]
    }
    private var nextLesson: LMSLesson? {
        guard let idx = currentIndex, idx < allLessons.count - 1 else { return nil }
        return allLessons[idx + 1]
    }

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Top bar ──────────────────────────────────
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.mdzAmber)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.lesson?.title ?? lessonTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.mdzText)
                            .lineLimit(1)
                        if let idx = currentIndex {
                            Text("Lesson \(idx + 1) of \(allLessons.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.mdzMuted)
                        }
                    }
                    Spacer()
                    if vm.completed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.mdzGreen)
                            Text("Done").font(.system(size: 12, weight: .semibold)).foregroundColor(.mdzGreen)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.mdzNavyMid)

                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                    Spacer()
                } else if let lesson = vm.lesson {
                    let youtubeId = extractYouTubeId(from: lesson.content ?? "")

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {

                            Text(lesson.title)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.mdzText)

                            // ── YouTube embed ─────────────────
                            if let ytId = youtubeId {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Primary: play in Safari (always works; avoids 152-4 in WebView)
                                    Button {
                                        if let url = URL(string: "https://www.youtube.com/watch?v=\(ytId)") {
                                            safariVideoURL = IdentifiableURL(url: url)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "play.rectangle.fill")
                                                .font(.system(size: 24))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Play video")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.mdzText)
                                                Text("Opens in Safari for reliable playback")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.mdzMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.mdzAmber)
                                        }
                                        .padding(14)
                                        .background(Color.mdzCard)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    // In-app embed (may show "video unavailable" on some devices)
                                    YouTubePlayerView(videoId: ytId) {
                                        vm.videoFinished = true
                                    }
                                    .frame(height: 220)
                                    .cornerRadius(10)
                                    .clipped()

                                    // Open in YouTube app
                                    if let ytUrl = URL(string: "https://youtu.be/\(ytId)") {
                                        Link(destination: ytUrl) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.system(size: 12))
                                                Text("Open in YouTube app")
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundColor(.mdzMuted)
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle").font(.system(size: 12))
                                        Text("Tap fullscreen for best view. Rotate for landscape.")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.mdzMuted)

                                    Button {
                                        vm.videoFinished = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: vm.videoFinished ? "checkmark.circle.fill" : "eye.fill")
                                            Text(vm.videoFinished ? "Video watched" : "I've watched the video")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(vm.videoFinished ? .mdzGreen : .mdzAmber)
                                    }
                                    .disabled(vm.videoFinished)
                                }
                            }

                            // ── HTML content (strip comments; images tappable) ───
                            let cleanText = lesson.content?
                                .replacingOccurrences(of: "<!--.*?-->", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                            if !cleanText.isEmpty {
                                HTMLLessonWebView(
                                    html: cleanText,
                                    onImageTapped: { url in enlargedImageURL = url },
                                    onContentHeightChanged: { htmlContentHeight = max(200, $0) }
                                )
                                .frame(height: htmlContentHeight)
                            }

                            // ── Bottom sentinel ───────────────
                            Color.clear
                                .frame(height: 1)
                                .onAppear { vm.hasScrolledToBottom = true }
                        }
                        .padding(20)
                        .padding(.bottom, 120)
                    }
                    .refreshable { await vm.load() }

                    // ── Bottom bar ────────────────────────────
                    VStack(spacing: 0) {
                        Divider().background(Color.mdzBorder)
                        VStack(spacing: 10) {

                            Button {
                                Task { await vm.markComplete(courseId: courseId) }
                            } label: {
                                HStack(spacing: 8) {
                                    if vm.isMarkingComplete {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: vm.completed ? "checkmark.circle.fill" : "checkmark.circle")
                                    }
                                    Text(completeButtonLabel(lesson: lesson, youtubeId: youtubeId))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(vm.canComplete || vm.completed ? .white : .mdzMuted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    vm.completed ? Color.mdzGreen :
                                    vm.canComplete ? Color.mdzAmber :
                                    Color.mdzBorder.opacity(0.5)
                                )
                                .cornerRadius(10)
                            }
                            .disabled(!vm.canComplete && !vm.completed || vm.isMarkingComplete)

                            // Prev / Next
                            if !allLessons.isEmpty {
                                HStack(spacing: 12) {
                                    navButton(lesson: prevLesson, label: "Previous", icon: "chevron.left", isLeft: true)
                                    navButton(lesson: nextLesson, label: "Next", icon: "chevron.right", isLeft: false)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.mdzNavyMid)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.load() }
        .sheet(item: $safariVideoURL, onDismiss: { safariVideoURL = nil }) { item in
            SafariVideoView(url: item.url)
        }
        .fullScreenCover(isPresented: Binding(
            get: { enlargedImageURL != nil },
            set: { if !$0 { enlargedImageURL = nil } }
        )) {
            if let url = enlargedImageURL {
                EnlargeableImageSheet(imageURL: url, onDismiss: { enlargedImageURL = nil })
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    private func completeButtonLabel(lesson: LessonDetail, youtubeId: String?) -> String {
        if vm.completed   { return "Completed" }
        if vm.canComplete { return "Mark as Complete" }
        if youtubeId != nil { return "Watch video to complete" }
        return "Scroll to the end to complete"
    }

    @ViewBuilder
    private func navButton(lesson: LMSLesson?, label: String, icon: String, isLeft: Bool) -> some View {
        if let lesson = lesson {
            NavigationLink(destination: LessonDetailView(
                lessonId: lesson.id,
                lessonTitle: lesson.title,
                allLessons: allLessons,
                courseId: courseId
            )) {
                HStack(spacing: 6) {
                    if isLeft { Image(systemName: icon).font(.system(size: 12)) }
                    Text(label).font(.system(size: 13, weight: .semibold))
                    if !isLeft { Image(systemName: icon).font(.system(size: 12)) }
                }
                .foregroundColor(.mdzAmber)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.mdzCard)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
            }
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: 40)
        }
    }
}
