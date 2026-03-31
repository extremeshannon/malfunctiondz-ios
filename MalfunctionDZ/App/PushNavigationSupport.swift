import SwiftUI
import MalfunctionDZCore

extension Notification.Name {
    static let dzStatusDidUpdateFromPush = Notification.Name("dzStatusDidUpdateFromPush")
}

// MARK: - Push navigation (notification tap → show content)
struct PendingPushTap: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let body: String
    let announcement: String?
    let payload: [String: Any]?
}

@MainActor
final class PushNavigationTarget: ObservableObject {
    static let shared = PushNavigationTarget()
    @Published var pendingTap: PendingPushTap?
    func handleTap(type: String, title: String, body: String, payload: [String: Any]) {
        let announcement = payload["announcement"] as? String
        pendingTap = PendingPushTap(type: type, title: title, body: body, announcement: announcement, payload: payload)
    }
    func dismiss() { pendingTap = nil }
}

// MARK: - Notification detail sheet (shown when user taps push)
struct NotificationDetailSheet: View {
    let tap: PendingPushTap
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tap.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(colors.text)
                        if !tap.body.isEmpty {
                            Text(tap.body)
                                .font(.system(size: 15))
                                .foregroundColor(colors.text)
                        }
                        if let ann = tap.announcement, !ann.isEmpty {
                            Text(ann)
                                .font(.system(size: 15))
                                .foregroundColor(colors.muted)
                                .padding(.top, 8)
                        }
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundColor(colors.accent)
                }
            }
        }
    }
}
