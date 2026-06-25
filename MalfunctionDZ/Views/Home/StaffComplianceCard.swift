// File: MalfunctionDZ/Views/Home/StaffComplianceCard.swift
import SwiftUI
import MalfunctionDZCore
import SafariServices

// MARK: - Models

struct StaffComplianceProfile: Decodable {
    let userId: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let overallStatus: String
    let readyTone: String?
    let readyLabel: String?
    let roles: [String]?
    let items: [PilotCurrencyItem]
    let docRows: [PilotDocRow]?

    enum CodingKeys: String, CodingKey {
        case items, username, roles
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case overallStatus = "overall_status"
        case readyTone = "ready_tone"
        case readyLabel = "ready_label"
        case docRows = "doc_rows"
    }

    var resolvedName: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? username : name
    }

    var roleLabels: [String] {
        (roles ?? []).map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }
}

private struct StaffProfileResponse: Decodable {
    let ok: Bool
    let canEditDates: Bool?
    let profile: StaffComplianceProfile?
    enum CodingKeys: String, CodingKey {
        case ok, profile
        case canEditDates = "can_edit_dates"
    }
}

// MARK: - ViewModel

@MainActor
class StaffComplianceViewModel: ObservableObject {
    @Published var profile: StaffComplianceProfile?
    @Published var canEditDates = false
    @Published var isLoading = false
    @Published var uploading: String?
    @Published var uploadError: String?
    @Published var uploadSuccess: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/staff/profile.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(StaffProfileResponse.self, from: data),
              resp.ok else { return }
        profile = resp.profile
        canEditDates = resp.canEditDates ?? false
    }

    func uploadDocument(_ data: Data, mimeType: String, filename: String, forKey key: String) async {
        uploading = key
        uploadError = nil
        uploadSuccess = nil
        defer { uploading = nil }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/staff/upload.php") else {
            uploadError = "Not configured"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "document_key": key,
            "image_base64": data.base64EncodedString(),
            "mime_type": mimeType,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (respData, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
            uploadError = "Upload failed"
            return
        }
        if (json["ok"] as? Bool) == true {
            uploadSuccess = "Document uploaded"
            await load()
        } else {
            uploadError = (json["detail"] as? String) ?? (json["error"] as? String) ?? "Upload failed"
        }
    }
}

// MARK: - Staff Card

struct StaffComplianceCard: View {
    var compact = false

    @StateObject private var vm = StaffComplianceViewModel()
    @State private var activeUploadKey: String?
    @State private var showDocumentScanner = false
    @State private var previewURL: URL?
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if vm.isLoading {
                loadingRow
            } else if let p = vm.profile {
                if compact {
                    compactBody(p)
                } else {
                    fullCardBody(p)
                }
                feedbackRows
            }
        }
        .padding(isWide ? 20 : 14)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        .task { await vm.load() }
        .fullScreenCover(isPresented: $showDocumentScanner) {
            DocumentScannerSheet(
                onScanned: { data, mime, _ in
                    showDocumentScanner = false
                    guard let key = activeUploadKey else { return }
                    Task { await vm.uploadDocument(data, mimeType: mime, filename: "scan", forKey: key) }
                },
                onDismiss: { showDocumentScanner = false }
            )
        }
        .sheet(item: $previewURL) { url in
            SafariView(url: url)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.primary)
                Text(compact ? "STAFF COMPLIANCE" : "STAFF CARD")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.primary)
                    .tracking(1.5)
            }
            Spacer()
            if let p = vm.profile {
                statusPill(
                    label: p.readyLabel ?? (p.overallStatus == "ready" ? "Ready" : "Not Ready"),
                    tone: p.readyTone ?? (p.overallStatus == "ready" ? "ok" : "expired")
                )
            }
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().tint(colors.primary).scaleEffect(0.8)
            Text("Loading staff card…").font(.system(size: 12)).foregroundColor(colors.muted)
        }
    }

    @ViewBuilder
    private var feedbackRows: some View {
        if let err = vm.uploadError {
            Label(err, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(colors.danger)
        }
        if let ok = vm.uploadSuccess {
            Label(ok, systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(colors.green)
        }
    }

    @ViewBuilder
    private func compactBody(_ p: StaffComplianceProfile) -> some View {
        Text(p.resolvedName)
            .font(.system(size: isWide ? 17 : 15, weight: .bold))
            .foregroundColor(colors.text)
        Divider().background(colors.border)
        VStack(spacing: 0) {
            ForEach(p.items) { item in
                CurrencyRow(
                    item: item,
                    canEdit: vm.canEditDates,
                    isUploading: vm.uploading == item.key,
                    statusColor: statusColor(for: item.status)
                ) { key in
                    activeUploadKey = key
                    showDocumentScanner = true
                }
                if item.id != p.items.last?.id {
                    Divider().background(colors.border).padding(.vertical, 4)
                }
            }
        }
        if !p.items.isEmpty {
            complianceFooter
        }
    }

    @ViewBuilder
    private func fullCardBody(_ p: StaffComplianceProfile) -> some View {
        Text(p.resolvedName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(colors.text)

        statusPill(label: p.readyLabel ?? "Not ready", tone: p.readyTone ?? "missing")
            .padding(.top, 2)

        if !p.roleLabels.isEmpty {
            StaffRoleChips(labels: p.roleLabels)
                .padding(.top, 4)
        }

        Divider().background(colors.border)

        let rows = p.docRows ?? []
        VStack(spacing: 0) {
            ForEach(rows) { row in
                PilotDocRowView(
                    row: row,
                    isUploading: vm.uploading == row.uploadDocumentKey,
                    onUpload: {
                        activeUploadKey = row.uploadDocumentKey
                        showDocumentScanner = true
                    },
                    onPreview: { openPreview(row) },
                    onOpenTraining: { tabSelect.selected = 3 }
                )
                if row.id != rows.last?.id {
                    Divider().background(colors.border).padding(.vertical, 6)
                }
            }
        }

        complianceFooter
    }

    private var complianceFooter: some View {
        Text("All staff need a signed waiver, W-9 on file, and role training in Ground School.")
            .font(.system(size: 10))
            .foregroundColor(colors.muted)
            .padding(.top, 4)
    }

    private func openPreview(_ row: PilotDocRow) {
        guard let path = row.fileUrl, !path.isEmpty else { return }
        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        let full = path.hasPrefix("http") ? path : base + (path.hasPrefix("/") ? path : "/\(path)")
        previewURL = URL(string: full)
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "current":       return colors.green
        case "expiring_soon": return colors.amber
        case "expired":       return colors.danger
        default:              return colors.muted
        }
    }

    @ViewBuilder
    private func statusPill(label: String, tone: String) -> some View {
        let fg = pillColor(tone)
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(fg.opacity(0.15))
            .clipShape(Capsule())
    }

    private func pillColor(_ tone: String) -> Color {
        switch tone {
        case "ok":      return colors.green
        case "warn":    return colors.amber
        case "expired": return colors.danger
        default:        return colors.danger
        }
    }
}

private struct StaffRoleChips: View {
    let labels: [String]
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(colors.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(colors.border.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Staff Card tab

struct StaffCardRootView: View {
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    StaffComplianceCard(compact: false)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
            .navigationTitle("Staff Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
