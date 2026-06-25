// File: ASC/Views/GroundSchool/LessonDetailView.swift
// Purpose: Displays lesson content with YouTube video embedding, scroll-to-bottom
//          gate for mark complete, and previous/next lesson navigation.
import SwiftUI
import WebKit
import SafariServices
import MalfunctionDZCore

// MARK: - Models

struct LessonDetail: Codable {
    let id: Int
    let title: String
    let lessonType: String
    let contentUrl: String?
    let content: String?
    let durationMin: Int?
    let required: Bool
    let requireAcknowledgement: Bool
    let courseId: Int
    let completed: Bool
    let isLocked: Bool
    let lockReason: String?
    let quizId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, content, required, completed
        case lessonType  = "lesson_type"
        case contentUrl  = "content_url"
        case durationMin = "duration_min"
        case requireAcknowledgement = "require_acknowledgement"
        case courseId    = "course_id"
        case isLocked    = "is_locked"
        case lockReason  = "lock_reason"
        case quizId      = "quiz_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        lessonType = try c.decodeIfPresent(String.self, forKey: .lessonType) ?? "text"
        contentUrl = try c.decodeIfPresent(String.self, forKey: .contentUrl)
        content = try c.decodeIfPresent(String.self, forKey: .content)
        durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin)
        required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? true
        requireAcknowledgement = try c.decodeIfPresent(Bool.self, forKey: .requireAcknowledgement) ?? false
        courseId = try c.decode(Int.self, forKey: .courseId)
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        lockReason = try c.decodeIfPresent(String.self, forKey: .lockReason)
        quizId = try c.decodeIfPresent(Int.self, forKey: .quizId)
    }
}

struct LessonCompleteBody: Codable {
    let acknowledged: Bool
}

struct LessonCompleteResponse: Codable {
    let ok: Bool
    let signoffRequested: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case signoffRequested = "signoff_requested"
    }
}

struct LessonDetailResponse: Codable {
    let ok: Bool
    let lesson: LessonDetail?
    let error: String?
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
    var textColorHex: String = "#1A2830"
    var headingColorHex: String = "#1E2D38"
    var linkColorHex: String = "#C87810"
    var imageBorderColor: String = "rgba(42,58,71,0.15)"
    var onImageTapped: ((URL) -> Void)?
    var onContentHeightChanged: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageTapped: onImageTapped, onContentHeightChanged: onContentHeightChanged)
    }

    private func wrappedBody() -> String {
        let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasHtml = body.contains("<") && body.contains(">")
        return hasHtml ? body : "<p>\(body.replacingOccurrences(of: "\n", with: "<br>"))</p>"
    }

    private func fullHTML() -> String {
        let wrappedHtml = wrappedBody()
        return """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:16px;line-height:1.55;color:\(textColorHex);background:transparent;margin:0;padding:0;}
        h1,h2,h3{color:\(headingColorHex);margin:0.8em 0 0.4em;}
        p,ul,ol{margin:0.6em 0;}
        ul,ol{padding-left:1.5em;}
        li{margin:0.25em 0;}
        img{max-width:100%;height:auto;border-radius:8px;cursor:pointer;border:1px solid \(imageBorderColor);}
        img:active{opacity:0.9;}
        a{color:\(linkColorHex);}
        </style></head><body>\(wrappedHtml)
        <script>
        document.querySelectorAll('img').forEach(function(img){
          img.onclick=function(){window.webkit.messageHandlers.imageTapped.postMessage(img.src);};
        });
        function reportHeight(){
          var h=Math.max(document.body.scrollHeight,document.documentElement.scrollHeight,document.body.offsetHeight);
          window.webkit.messageHandlers.heightChanged.postMessage(h);
        }
        document.querySelectorAll('img').forEach(function(img){
          if(img.complete) reportHeight(); else img.onload=reportHeight;
        });
        reportHeight();
        setTimeout(reportHeight,400);
        setTimeout(reportHeight,1200);
        </script></body></html>
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "imageTapped")
        config.userContentController.add(context.coordinator, name: "heightChanged")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.navigationDelegate = context.coordinator
        context.coordinator.lastHtml = html
        wv.loadHTMLString(fullHTML(), baseURL: URL(string: "\(kServerURL)/"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastHtml != html {
            context.coordinator.lastHtml = html
            wv.loadHTMLString(fullHTML(), baseURL: URL(string: "\(kServerURL)/"))
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
            if message.name == "imageTapped", let src = message.body as? String, let url = URL(string: src) {
                onImageTapped?(url)
                return
            }
            if message.name == "heightChanged", let h = message.body as? Double, h > 0 {
                DispatchQueue.main.async { self.onContentHeightChanged?(CGFloat(h)) }
            } else if message.name == "heightChanged", let h = message.body as? Int, h > 0 {
                DispatchQueue.main.async { self.onContentHeightChanged?(CGFloat(h)) }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.body.offsetHeight)") { val, _ in
                guard let h = val as? CGFloat, h > 0 else { return }
                DispatchQueue.main.async { self.onContentHeightChanged?(h) }
            }
        }
    }
}

// Fullscreen image (tap to enlarge); use full space and allow landscape for maximum size
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @Published var slideshowFinished = false
    @Published var acknowledged = false
    @Published var signoffSubmitted = false
    @Published var error: String?

    let lessonId: Int
    let moduleId: Int

    init(lessonId: Int, moduleId: Int = 0) {
        self.lessonId = lessonId
        self.moduleId = moduleId
    }

    var isSlideshowLesson: Bool {
        guard let lesson = lesson else { return false }
        if lesson.lessonType == "slideshow" { return true }
        return LMSSlideshowParser.parse(lesson.content ?? "") != nil
    }

    var isPlannerLesson: Bool {
        guard let lesson = lesson else { return false }
        if lesson.lessonType == "planner" { return true }
        return LMSPlannerParser.parse(lesson.content ?? "") != nil
    }

    var canComplete: Bool {
        if completed { return false }
        guard let lesson = lesson else { return false }
        if lesson.isLocked { return false }
        if lesson.requireAcknowledgement && !acknowledged { return false }
        if isSlideshowLesson {
            if let qid = lesson.quizId, qid > 0 { return false }
            return slideshowFinished
        }
        let youtubeId = extractYouTubeId(from: lesson.content ?? "")
        if youtubeId != nil {
            return videoFinished
        }
        return hasScrolledToBottom
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else { return }
        var components = URLComponents(string: "\(kServerURL)/api/lms/lesson.php")
        var query = [URLQueryItem(name: "id", value: "\(lessonId)")]
        if moduleId > 0 {
            query.append(URLQueryItem(name: "module_id", value: "\(moduleId)"))
        }
        components?.queryItems = query
        guard let url = components?.url else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                self.error = "Session expired — sign in again."
                return
            }
            let resp = try JSONDecoder().decode(LessonDetailResponse.self, from: data)
            guard resp.ok, let l = resp.lesson else {
                self.error = resp.error ?? "Could not load this lesson."
                return
            }
            lesson = l
            completed = l.completed
            if l.completed {
                hasScrolledToBottom = true
                videoFinished = true
                slideshowFinished = true
                acknowledged = true
            } else {
                slideshowFinished = false
            }
        } catch {
            self.error = "Could not load lesson. Pull to refresh or check your connection."
        }
    }

    func markComplete(courseId: Int) async {
        guard !completed else { return }
        guard let lesson = lesson else { return }
        if lesson.requireAcknowledgement && !acknowledged { return }
        isMarkingComplete = true
        defer { isMarkingComplete = false }
        guard let token = KeychainHelper.readToken() else { return }
        var components = URLComponents(string: "\(kServerURL)/api/lms/lesson.php")
        var query = [URLQueryItem(name: "id", value: "\(lessonId)")]
        if moduleId > 0 {
            query.append(URLQueryItem(name: "module_id", value: "\(moduleId)"))
        }
        components?.queryItems = query
        guard let url = components?.url else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(LessonCompleteBody(acknowledged: acknowledged))
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let resp = try? JSONDecoder().decode(LessonCompleteResponse.self, from: data) {
                signoffSubmitted = resp.signoffRequested == true
            }
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
    var moduleId: Int = 0
    var onBackToModule: (() -> Void)?
    var onGoToLesson: ((LessonNavItem) -> Void)?

    @StateObject private var vm: LessonDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var safariVideoURL: IdentifiableURL?
    @State private var enlargedImageURL: URL?
    @State private var htmlContentHeight: CGFloat = 300
    @State private var slideshowSlideIndex = 0
    @State private var slideshowHotspots: [Int: Set<String>] = [:]
    @State private var showSlideshowQuiz = false

    init(
        lessonId: Int,
        lessonTitle: String,
        allLessons: [LMSLesson] = [],
        courseId: Int = 0,
        moduleId: Int = 0,
        onBackToModule: (() -> Void)? = nil,
        onGoToLesson: ((LessonNavItem) -> Void)? = nil
    ) {
        self.lessonId    = lessonId
        self.lessonTitle = lessonTitle
        self.allLessons  = allLessons
        self.courseId    = courseId
        self.moduleId    = moduleId
        self.onBackToModule = onBackToModule
        self.onGoToLesson = onGoToLesson
        _vm = StateObject(wrappedValue: LessonDetailViewModel(lessonId: lessonId, moduleId: moduleId))
    }

    private var isJumpSignoffLesson: Bool {
        isJumpSignoffLessonTitle(vm.lesson?.title ?? lessonTitle)
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

    private var slideshowSlides: [LMSSlidePayload]? {
        guard let content = vm.lesson?.content else { return nil }
        return LMSSlideshowParser.parse(content)
    }

    private var plannerPayload: LMSPlannerPayload? {
        guard let content = vm.lesson?.content else { return nil }
        return LMSPlannerParser.parse(content)
    }

    private func backToModule() {
        if let onBackToModule { onBackToModule() } else { dismiss() }
    }

    private func goToLesson(_ lesson: LMSLesson) {
        let item = LessonNavItem(
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            courseId: courseId,
            moduleId: moduleId,
            allLessons: allLessons
        )
        if let onGoToLesson { onGoToLesson(item) }
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Top bar ──────────────────────────────────
                HStack(spacing: 12) {
                    Button { backToModule() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Module")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(colors.amber)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.lesson?.title ?? lessonTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(colors.text)
                            .lineLimit(1)
                        if let idx = currentIndex {
                            Text("Lesson \(idx + 1) of \(allLessons.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(colors.muted)
                        }
                    }
                    Spacer()
                    if vm.completed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(colors.green)
                            Text("Done").font(.system(size: 12, weight: .semibold)).foregroundColor(colors.green)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colors.navyMid)

                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.amber))
                    Spacer()
                } else if let lesson = vm.lesson {
                    let youtubeId = extractYouTubeId(from: lesson.content ?? "")

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {

                            Text(lesson.title)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(colors.text)

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
                                                    .foregroundColor(colors.text)
                                                Text("Opens in Safari for reliable playback")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(colors.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(colors.amber)
                                        }
                                        .padding(14)
                                        .background(colors.card)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
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
                                            .foregroundColor(colors.muted)
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle").font(.system(size: 12))
                                        Text("Tap fullscreen for best view. Rotate for landscape.")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(colors.muted)

                                    Button {
                                        vm.videoFinished = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: vm.videoFinished ? "checkmark.circle.fill" : "eye.fill")
                                            Text(vm.videoFinished ? "Video watched" : "I've watched the video")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(vm.videoFinished ? colors.green : colors.amber)
                                    }
                                    .disabled(vm.videoFinished)
                                }
                            }

                            // ── Slideshow (Landing Area, Malfunctions, etc.) ──
                            if let slides = slideshowSlides, vm.isSlideshowLesson {
                                LessonSlideshowView(
                                    slides: slides,
                                    slideIndex: $slideshowSlideIndex,
                                    visitedHotspots: $slideshowHotspots,
                                    onFinishedLastSlide: { vm.slideshowFinished = true }
                                )
                                if let qid = lesson.quizId, qid > 0, vm.slideshowFinished, !vm.completed {
                                    Button {
                                        showSlideshowQuiz = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "pencil.and.list.clipboard")
                                            Text("Take quiz to complete lesson")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(colors.primary)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // ── Flight planner (Tandem 2, Level 1, etc.) ──
                            if let planner = plannerPayload, vm.isPlannerLesson {
                                LessonPlannerView(planner: planner)
                            }

                            // ── HTML content (text lessons; skip slideshow/planner JSON) ───
                            let cleanText = lesson.content?
                                .replacingOccurrences(of: "<!--.*?-->", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                            if !cleanText.isEmpty, slideshowSlides == nil, plannerPayload == nil {
                                let htmlStyle = lessonHTMLStyle(colors: colors, scheme: mdzColorScheme)
                                HTMLLessonWebView(
                                    html: cleanText,
                                    textColorHex: htmlStyle.text,
                                    headingColorHex: htmlStyle.heading,
                                    linkColorHex: htmlStyle.link,
                                    imageBorderColor: htmlStyle.imageBorder,
                                    onImageTapped: { url in enlargedImageURL = url },
                                    onContentHeightChanged: { htmlContentHeight = max(200, $0) }
                                )
                                .frame(height: htmlContentHeight)
                            }

                            if isJumpSignoffLesson && moduleId > 0 {
                                if vm.lesson?.isLocked == true {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Jump sign-off locked", systemImage: "lock.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(colors.amber)
                                        Text(vm.lesson?.lockReason ?? "Waiting for instructor review approval.")
                                            .font(.system(size: 13))
                                            .foregroundColor(colors.muted)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(colors.card)
                                    .cornerRadius(12)
                                } else {
                                    JumpSignoffLessonSection(lessonId: lessonId, moduleId: moduleId)
                                }
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
                        Divider().background(colors.border)
                        VStack(spacing: 10) {

                            if lesson.requireAcknowledgement && !vm.completed {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Acknowledgement required")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(colors.text)
                                    Button {
                                        vm.acknowledged.toggle()
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: vm.acknowledged ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 20))
                                                .foregroundColor(vm.acknowledged ? colors.green : colors.muted)
                                            Text("I confirm I have read and understand the material in this lesson.")
                                                .font(.system(size: 13))
                                                .foregroundColor(colors.text)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(colors.card)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                            }

                            if vm.signoffSubmitted {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(colors.amber)
                                    Text("Sent to your instructor for review")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(colors.amber)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !isJumpSignoffLesson {
                            Button {
                                Task { await vm.markComplete(courseId: courseId) }
                            } label: {
                                HStack(spacing: 8) {
                                    if vm.isMarkingComplete {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                    } else if lesson.requireAcknowledgement && vm.canComplete && !vm.completed {
                                        Image(systemName: "paperplane.fill")
                                    } else {
                                        Image(systemName: vm.completed ? "checkmark.circle.fill" : "checkmark.circle")
                                    }
                                    Text(completeButtonLabel(lesson: lesson, youtubeId: youtubeId))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(vm.canComplete || vm.completed ? .white : colors.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    vm.completed ? colors.green :
                                    vm.canComplete ? colors.amber :
                                    colors.border.opacity(0.5)
                                )
                                .cornerRadius(10)
                            }
                            .disabled(!vm.canComplete && !vm.completed || vm.isMarkingComplete)
                            }

                            Button { backToModule() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.fill")
                                        .font(.system(size: 12))
                                    Text("Back to Module")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(colors.amber)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(colors.card)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            // Prev / Next
                            if !allLessons.isEmpty {
                                HStack(spacing: 12) {
                                    navButton(lesson: prevLesson, label: "Previous", icon: "chevron.left", isLeft: true)
                                    navButton(lesson: nextLesson, label: "Next", icon: "chevron.right", isLeft: false)
                                }
                            }
                        }
                        .padding(16)
                        .background(colors.navyMid)
                    }
                }
            }
        }
        .id(lessonId)
        .navigationBarHidden(true)
        .task { await vm.load() }
        .sheet(isPresented: $showSlideshowQuiz) {
            if let qid = vm.lesson?.quizId {
                NavigationStack {
                    QuizAttemptView(quizId: qid)
                }
            }
        }
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

    private func lessonHTMLStyle(colors: MDZColorSet, scheme: ColorScheme) -> (text: String, heading: String, link: String, imageBorder: String) {
        if scheme == .light {
            return ("#1A2830", "#1E2D38", "#C87810", "rgba(42,58,71,0.15)")
        }
        return ("#E8EDF5", "#FFFFFF", "#F39C12", "rgba(255,255,255,0.2)")
    }

    private func completeButtonLabel(lesson: LessonDetail, youtubeId: String?) -> String {
        if vm.completed {
            if lesson.requireAcknowledgement && vm.signoffSubmitted {
                return "Sent for Review"
            }
            return "Completed"
        }
        if lesson.requireAcknowledgement && !vm.acknowledged {
            return "Acknowledge to continue"
        }
        if vm.canComplete && lesson.requireAcknowledgement {
            return "Send for Review"
        }
        if vm.canComplete { return "Mark as Complete" }
        if vm.isSlideshowLesson {
            if let qid = lesson.quizId, qid > 0 {
                return vm.slideshowFinished ? "Take quiz to complete" : "View all slides to complete"
            }
            return "View all slides to complete"
        }
        if youtubeId != nil { return "Watch video to complete" }
        return "Scroll to the end to complete"
    }

    @ViewBuilder
    private func navButton(lesson: LMSLesson?, label: String, icon: String, isLeft: Bool) -> some View {
        if let lesson = lesson {
            Button {
                goToLesson(lesson)
            } label: {
                HStack(spacing: 6) {
                    if isLeft { Image(systemName: icon).font(.system(size: 12)) }
                    Text(label).font(.system(size: 13, weight: .semibold))
                    if !isLeft { Image(systemName: icon).font(.system(size: 12)) }
                }
                .foregroundColor(colors.amber)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(colors.card)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: 40)
        }
    }
}

// MARK: - Remote LMS image (AsyncImage can fail on large static assets)

private struct LMSRemoteImage: View {
    let url: URL
    var maxHeight: CGFloat? = nil
    var fillContainer: Bool = false

    @Environment(\.mdzColors) private var colors
    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: fillContainer ? .infinity : maxHeight
                    )
                    .background(fillContainer ? Color.clear : Color.white.opacity(0.95))
                    .cornerRadius(fillContainer ? 0 : 8)
            } else if failed {
                Text("Could not load image").foregroundColor(colors.danger)
            } else {
                ProgressView().tint(colors.amber)
                    .frame(maxWidth: .infinity, minHeight: fillContainer ? nil : (maxHeight ?? 120))
            }
        }
        .task(id: url) {
            uiImage = nil
            failed = false
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    failed = true
                    return
                }
                if let img = UIImage(data: data) {
                    uiImage = img
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}

// MARK: - Flight planner

private enum LMSPlannerListItem: Decodable {
    case text(String)
    case rich(LMSPlannerRichItem)

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(s)
            return
        }
        self = .rich(try LMSPlannerRichItem(from: decoder))
    }

    var displayText: String {
        switch self {
        case .text(let s): return s
        case .rich(let item): return item.text ?? ""
        }
    }
}

private struct LMSPlannerRichItem: Decodable {
    let text: String?
    let lessonId: Int?
    let lessonTitle: String?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case lessonTitle = "lesson_title"
    }
}

private struct LMSPlannerPracticeReview: Decodable {
    let left: [LMSPlannerListItem]
    let right: [LMSPlannerListItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        left = try c.decodeIfPresent([LMSPlannerListItem].self, forKey: .left) ?? []
        right = try c.decodeIfPresent([LMSPlannerListItem].self, forKey: .right) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case left, right
    }
}

private struct LMSPlannerMap: Decodable {
    let enabled: Bool?
    let mapImage: String?
    let mapImageWeb: String?
    let instructions: [String]?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case enabled, instructions, note
        case mapImage = "map_image"
        case mapImageWeb = "map_image_web"
    }
}

private struct LMSPlannerPayload: Decodable {
    let program: String?
    let jumpLabel: String
    let performanceObjectives: [LMSPlannerListItem]
    let freefallDiveFlow: [LMSPlannerListItem]
    let canopyDiveFlow: [LMSPlannerListItem]
    let readings: [LMSPlannerListItem]?
    let accessories: [String]?
    let accessoriesNote: String?
    let practiceReview: LMSPlannerPracticeReview?
    let practiceNote: String?
    let map: LMSPlannerMap?
    let showSignoff: Bool?
    let footer: String?

    enum CodingKeys: String, CodingKey {
        case program, readings, accessories, map, footer
        case jumpLabel = "jump_label"
        case performanceObjectives = "performance_objectives"
        case freefallDiveFlow = "freefall_dive_flow"
        case canopyDiveFlow = "canopy_dive_flow"
        case accessoriesNote = "accessories_note"
        case practiceReview = "practice_review"
        case practiceNote = "practice_note"
        case showSignoff = "show_signoff"
    }
}

private enum LMSPlannerParser {
    static func parse(_ raw: String) -> LMSPlannerPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(LMSPlannerPayload.self, from: data) else { return nil }
        guard !payload.jumpLabel.isEmpty,
              !payload.performanceObjectives.isEmpty,
              !payload.freefallDiveFlow.isEmpty,
              !payload.canopyDiveFlow.isEmpty else { return nil }
        return payload
    }
}

private struct LessonPlannerView: View {
    let planner: LMSPlannerPayload
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            plannerHeader
            objectivesTable
            if let readings = planner.readings, !readings.isEmpty {
                plannerSection(title: "Read") {
                    plannerList(readings)
                }
            }
            if let accessories = planner.accessories, !accessories.isEmpty {
                plannerSection(title: "Accessories") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], spacing: 8) {
                        ForEach(accessories, id: \.self) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "square")
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.muted)
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.text)
                            }
                        }
                    }
                    if let note = planner.accessoriesNote, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                            .padding(.top, 4)
                    }
                }
            }
            if hasPracticeReview {
                plannerSection(title: "Prior to jump: practice & review") {
                    HStack(alignment: .top, spacing: 16) {
                        if let left = planner.practiceReview?.left, !left.isEmpty {
                            plannerList(left)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let right = planner.practiceReview?.right, !right.isEmpty {
                            plannerList(right)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if let note = planner.practiceNote, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                            .padding(.top, 4)
                    }
                }
            }
            if planner.showSignoff != false {
                plannerSection(title: "Sign off") {
                    VStack(alignment: .leading, spacing: 12) {
                        plannerFieldLine(label: "Student signature")
                        plannerFieldLine(label: "Date")
                        HStack(spacing: 16) {
                            signoffChoice("Pass")
                            signoffChoice("Retake")
                        }
                        plannerFieldLine(label: "Instructor")
                        plannerFieldLine(label: "Date")
                    }
                }
            }
            if let map = planner.map, map.enabled != false {
                plannerMapSection(map)
            }
            Text(planner.footer ?? "Alaska Skydive Center ©")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var hasPracticeReview: Bool {
        let left = planner.practiceReview?.left ?? []
        let right = planner.practiceReview?.right ?? []
        return !left.isEmpty || !right.isEmpty
    }

    private var plannerHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(planner.program ?? "Alaska Skydiver Program")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
            Text(planner.jumpLabel)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(colors.text)
            HStack(spacing: 16) {
                plannerFieldLine(label: "Name")
                plannerFieldLine(label: "Date")
            }
        }
    }

    private var objectivesTable: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                plannerColumn(title: "Performance objectives", items: planner.performanceObjectives)
                Divider().background(colors.border)
                plannerColumn(title: "Freefall dive flow", items: planner.freefallDiveFlow)
                Divider().background(colors.border)
                plannerColumn(title: "Canopy dive flow", items: planner.canopyDiveFlow)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func plannerColumn(title: String, items: [LMSPlannerListItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(colors.amber)
                .padding(.bottom, 4)
            plannerList(items)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func plannerSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(colors.text)
            content()
        }
    }

    @ViewBuilder
    private func plannerList(_ items: [LMSPlannerListItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundColor(colors.amber)
                    Text(item.displayText)
                        .font(.system(size: 13))
                        .foregroundColor(colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func plannerFieldLine(label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colors.muted)
            Rectangle()
                .fill(colors.border)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func signoffChoice(_ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "square")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(colors.text)
        }
    }

    @ViewBuilder
    private func plannerMapSection(_ map: LMSPlannerMap) -> some View {
        plannerSection(title: "Drop zone map") {
            if let path = map.mapImageWeb ?? map.mapImage,
               let url = LMSSlideshowParser.absoluteURL(path) {
                LMSRemoteImage(url: url, maxHeight: 420)
            }
            if let steps = map.instructions, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(colors.amber)
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundColor(colors.text)
                        }
                    }
                }
            }
            if let note = map.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
        }
    }
}

// MARK: - Slideshow models & viewer

private struct LMSSlideshowPayload: Codable {
    let slides: [LMSSlideRaw]
}

private struct LMSSlideRaw: Codable {
    let type: String
    let title: String?
    let image: String?
    let intro: String?
    let layout: String?
    let imageFit: String?
    let bullets: [String]?
    let hotspotLead: String?
    let hotspots: [LMSSlideHotspot]?
    let imageWidth: Int?
    let imageHeight: Int?
    let calloutLineInset: Double?

    enum CodingKeys: String, CodingKey {
        case type, title, image, intro, layout, bullets, hotspots
        case imageFit = "image_fit"
        case hotspotLead = "hotspot_lead"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case calloutLineInset = "callout_line_inset"
    }
}

struct LMSSlidePayload: Identifiable {
    var id: Int { index }
    let index: Int
    let type: String
    let title: String?
    let image: String?
    let intro: String?
    let layout: String?
    let imageFit: String?
    let bullets: [String]?
    let hotspotLead: String?
    let hotspots: [LMSSlideHotspot]?
    let imageWidth: Int?
    let imageHeight: Int?
    let calloutLineInset: Double?

    var imageAspectRatio: CGFloat {
        if let w = imageWidth, let h = imageHeight, w > 0, h > 0 {
            return CGFloat(w) / CGFloat(h)
        }
        return 1024 / 1537
    }
}

struct LMSSlideHotspot: Codable, Identifiable {
    let id: String
    let x: Double
    let y: Double
    let title: String
    let lines: [String]?
    let lineTo: String?
    let side: String?
    let labelY: Double?
    let lineStyle: String?
    let elbowX: Double?

    enum CodingKeys: String, CodingKey {
        case id, x, y, title, lines, side
        case lineTo = "line_to"
        case labelY = "label_y"
        case lineStyle = "line_style"
        case elbowX = "elbow_x"
    }

    var marginSide: String { (lineTo ?? side ?? "right").lowercased() }
    var calloutY: Double { labelY ?? y }
}

enum LMSSlideshowParser {
    static func parse(_ raw: String) -> [LMSSlidePayload]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(LMSSlideshowPayload.self, from: data) else { return nil }
        return payload.slides.enumerated().map { idx, slide in
            LMSSlidePayload(
                index: idx, type: slide.type, title: slide.title, image: slide.image,
                intro: slide.intro, layout: slide.layout, imageFit: slide.imageFit,
                bullets: slide.bullets, hotspotLead: slide.hotspotLead, hotspots: slide.hotspots,
                imageWidth: slide.imageWidth, imageHeight: slide.imageHeight,
                calloutLineInset: slide.calloutLineInset
            )
        }
    }

    static func absoluteURL(_ path: String?) -> URL? {
        guard var path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        let staticFallbacks: [String: String] = [
            "/uploads/lms/asp/0eaa863a-landing-to-south-paq.jpg": "/static/lms/asp/landing-south-hotspot-base.jpg",
            "/uploads/lms/asp/a486c37f-landing-to-north-paq.jpg": "/static/lms/asp/landing-north-hotspot-base.jpg",
        ]
        if let fallback = staticFallbacks[path] { path = fallback }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        return URL(string: "\(base)\(path.hasPrefix("/") ? path : "/\(path)")")
    }
}

private struct LessonSlideshowView: View {
    let slides: [LMSSlidePayload]
    @Binding var slideIndex: Int
    @Binding var visitedHotspots: [Int: Set<String>]
    var onFinishedLastSlide: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var selectedHotspotId: String?

    private var current: LMSSlidePayload { slides[slideIndex] }
    private var isLast: Bool { slideIndex >= slides.count - 1 }

    private var hotspotComplete: Bool {
        guard current.type == "image_hotspot", let hotspots = current.hotspots, !hotspots.isEmpty else { return true }
        let visited = visitedHotspots[slideIndex] ?? []
        return hotspots.allSatisfy { visited.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = current.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(colors.amber)
            }
            if let intro = current.intro, !intro.isEmpty {
                Text(intro).font(.system(size: 14)).foregroundColor(colors.text)
            }
            slideBody(for: current)
            HStack {
                Button { if slideIndex > 0 { slideIndex -= 1 } } label: {
                    Label("Previous", systemImage: "chevron.left").font(.system(size: 14, weight: .semibold))
                }
                .disabled(slideIndex == 0)
                .foregroundColor(slideIndex == 0 ? colors.muted : colors.amber)
                Spacer()
                Text("Slide \(slideIndex + 1) of \(slides.count)")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(colors.muted)
                Spacer()
                Button { goNext() } label: {
                    Text(isLast ? "Done" : "Next").font(.system(size: 14, weight: .semibold))
                }
                .disabled(!hotspotComplete)
                .foregroundColor(hotspotComplete ? colors.amber : colors.muted)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .onChange(of: slideIndex) { _, _ in selectedHotspotId = nil }
    }

    private func goNext() {
        guard hotspotComplete else { return }
        if isLast { onFinishedLastSlide(); return }
        slideIndex += 1
    }

    @ViewBuilder
    private func slideBody(for slide: LMSSlidePayload) -> some View {
        switch slide.type {
        case "image_hotspot": hotspotSlide(slide)
        case "image":
            if let url = LMSSlideshowParser.absoluteURL(slide.image) {
                slideshowImage(url: url)
            }
        default:
            if let url = LMSSlideshowParser.absoluteURL(slide.image) { slideshowImage(url: url) }
            if let bullets = slide.bullets { bulletList(bullets) }
        }
    }

    @ViewBuilder
    private func hotspotSlide(_ slide: LMSSlidePayload) -> some View {
        let hotspots = slide.hotspots ?? []
        let visited = visitedHotspots[slideIndex] ?? []

        VStack(alignment: .leading, spacing: 10) {
            Text(slide.hotspotLead ?? "Tap each marker on the map.")
                .font(.system(size: 13)).foregroundColor(colors.muted)
            Text("\(visited.count) / \(hotspots.count) explored")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(visited.count == hotspots.count ? colors.green : colors.amber)

            if let url = LMSSlideshowParser.absoluteURL(slide.image) {
                HotspotMapInteractiveView(
                    slide: slide,
                    imageURL: url,
                    visited: visited,
                    onSelect: { hs in
                        var set = visitedHotspots[slideIndex] ?? []
                        set.insert(hs.id)
                        visitedHotspots[slideIndex] = set
                        selectedHotspotId = hs.id
                        if isLast, hotspots.allSatisfy({ (visitedHotspots[slideIndex] ?? []).contains($0.id) }) {
                            onFinishedLastSlide()
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func slideshowImage(url: URL) -> some View {
        LMSRemoteImage(url: url, maxHeight: 380)
    }

    @ViewBuilder
    private func bulletList(_ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundColor(colors.amber)
                    Text(bullet).font(.system(size: 14)).foregroundColor(colors.text)
                }
            }
        }
    }
}

// MARK: - Hotspot map (margin callouts like web slideshow)

private struct HotspotMapInteractiveView: View {
    let slide: LMSSlidePayload
    let imageURL: URL
    let visited: Set<String>
    let onSelect: (LMSSlideHotspot) -> Void

    @Environment(\.mdzColors) private var colors

    private var hotspots: [LMSSlideHotspot] { slide.hotspots ?? [] }
    private var lineInset: Double { slide.calloutLineInset ?? 7.0 }

    var body: some View {
        Color.clear
            .aspectRatio(slide.imageAspectRatio, contentMode: .fit)
            .overlay {
                LMSRemoteImage(url: imageURL, fillContainer: true)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    Canvas { context, canvasSize in
                        for hs in hotspots where visited.contains(hs.id) {
                            drawCalloutLine(hs, in: canvasSize, context: &context)
                        }
                    }
                    .allowsHitTesting(false)

                    ForEach(hotspots.filter { visited.contains($0.id) }) { hs in
                        hotspotMarginLabel(hs, size: size)
                    }

                    ForEach(hotspots) { hs in
                        Button {
                            onSelect(hs)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(visited.contains(hs.id) ? colors.green : Color.white)
                                    .frame(width: 26, height: 26)
                                Circle()
                                    .stroke(Color.black.opacity(0.5), lineWidth: 2)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(
                            x: size.width * CGFloat(hs.x / 100),
                            y: size.height * CGFloat(hs.y / 100)
                        )
                    }
                }
            }
    }

    private func marginXPercent(for hs: LMSSlideHotspot) -> Double {
        hs.marginSide == "left" ? lineInset : (100 - lineInset)
    }

    private func marginX(for hs: LMSSlideHotspot, width: CGFloat) -> CGFloat {
        width * CGFloat(marginXPercent(for: hs) / 100)
    }

    private func usesElbowLine(_ hs: LMSSlideHotspot) -> Bool {
        if hs.lineStyle == "straight" { return false }
        if hs.lineStyle == "elbow" { return true }
        return abs(hs.y - hs.calloutY) > 0.75
    }

    private func drawCalloutLine(_ hs: LMSSlideHotspot, in size: CGSize, context: inout GraphicsContext) {
        let dot = CGPoint(x: size.width * CGFloat(hs.x / 100), y: size.height * CGFloat(hs.y / 100))
        let labelY = size.height * CGFloat(hs.calloutY / 100)
        let marginX = marginX(for: hs, width: size.width)
        var path = Path()
        path.move(to: dot)
        if usesElbowLine(hs) {
            let elbowPct = hs.elbowX ?? ((hs.x + marginXPercent(for: hs)) / 2)
            let elbowX = size.width * CGFloat(elbowPct / 100)
            path.addLine(to: CGPoint(x: elbowX, y: labelY))
        }
        path.addLine(to: CGPoint(x: marginX, y: labelY))
        context.stroke(path, with: .color(.white.opacity(0.92)), lineWidth: 1.5)
    }

    @ViewBuilder
    private func hotspotMarginLabel(_ hs: LMSSlideHotspot, size: CGSize) -> some View {
        let labelY = size.height * CGFloat(hs.calloutY / 100)
        let mx = marginX(for: hs, width: size.width)
        let isLeft = hs.marginSide == "left"
        let labelWidth = size.width * 0.24
        let lineGap: CGFloat = 4

        VStack(alignment: isLeft ? .leading : .trailing, spacing: 0) {
            Text(hs.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(isLeft ? .leading : .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: labelWidth, alignment: isLeft ? .leading : .trailing)
                .background(Color.black.opacity(0.78))
                .cornerRadius(4)

            Spacer().frame(height: lineGap)

            if let lines = hs.lines, !lines.isEmpty {
                Text(lines.joined(separator: " "))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(isLeft ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(width: labelWidth, alignment: isLeft ? .leading : .trailing)
                    .background(Color.black.opacity(0.72))
                    .cornerRadius(4)
            }
        }
        .position(
            x: isLeft ? mx + labelWidth / 2 : mx - labelWidth / 2,
            y: labelY
        )
        .allowsHitTesting(false)
    }
}
