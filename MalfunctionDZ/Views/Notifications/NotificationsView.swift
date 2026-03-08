// File: MalfunctionDZ/Views/Notifications/NotificationsView.swift
// Push notification history — view past status notes and announcements.
import SwiftUI

struct PushNotificationItem: Identifiable {
    let id: Int
    let type: String
    let title: String
    let body: String?
    let payload: [String: Any]?
    let createdAt: String
}

struct NotificationsView: View {
    @State private var items: [PushNotificationItem] = []
    @State private var loading = true
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if loading {
                ProgressView().tint(colors.primary).scaleEffect(1.2)
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 44))
                        .foregroundColor(colors.muted)
                    Text("No notifications yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.text)
                    Text("Status updates and announcements will appear here")
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            NotificationRow(item: item, isWide: isWide)
                        }
                    }
                    .padding(isWide ? 24 : 16)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .task { await loadNotifications() }
        .refreshable { await loadNotifications() }
    }

    private func loadNotifications() async {
        loading = true
        defer { loading = false }
        guard let url = URL(string: "\(kServerURL)/api/push/notifications.php?limit=50") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["ok"] as? Bool) == true,
                  let arr = json["notifications"] as? [[String: Any]] else { items = []; return }
            items = arr.compactMap { row -> PushNotificationItem? in
                guard let id = row["id"] as? Int else { return nil }
                let type = row["type"] as? String ?? "unknown"
                let title = row["title"] as? String ?? ""
                let body = row["body"] as? String
                let payload = row["payload"] as? [String: Any]
                let createdAt = row["created_at"] as? String ?? ""
                return PushNotificationItem(id: id, type: type, title: title, body: body, payload: payload, createdAt: createdAt)
            }
        } catch {
            items = []
        }
    }
}

struct NotificationRow: View {
    let item: PushNotificationItem
    var isWide: Bool = false
    @Environment(\.mdzColors) private var colors

    private var typeColor: Color {
        switch item.type {
        case "dz_status": return colors.accent
        case "new_shift", "shift_unfilled_week", "shift_day_before": return colors.primary
        case "calendar_event": return colors.amber
        default: return colors.muted
        }
    }

    private var formattedDate: String {
        guard !item.createdAt.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: item.createdAt) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: d)
        }
        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f2.date(from: String(item.createdAt.prefix(19))) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: d)
        }
        return item.createdAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(typeColor)
                    .tracking(0.8)
                Spacer()
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
            Text(item.title)
                .font(.system(size: isWide ? 16 : 15, weight: .semibold))
                .foregroundColor(colors.text)
            if let body = item.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: isWide ? 14 : 13))
                    .foregroundColor(colors.muted)
            }
            if let ann = item.payload?["announcement"] as? String, !ann.isEmpty {
                Text(ann)
                    .font(.system(size: isWide ? 14 : 13))
                    .foregroundColor(colors.text)
            }
        }
        .padding(isWide ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }
}
