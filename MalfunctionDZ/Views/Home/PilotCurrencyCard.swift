// File: ASC/Views/Home/PilotCurrencyCard.swift
import SwiftUI
import MalfunctionDZCore
import SafariServices

// MARK: - Models

struct PilotCurrencyItem: Identifiable, Decodable {
    let key: String
    let label: String
    let file: String?
    let date: String?
    let dateLabel: String
    let status: String
    var id: String { key }
    enum CodingKeys: String, CodingKey {
        case key, label, file, date, status
        case dateLabel = "date_label"
    }
    var statusColor: Color {
        switch status {
        case "current":       return .mdzGreen
        case "expiring_soon": return .mdzAmber
        case "expired":       return .mdzDanger
        default:              return .mdzMuted
        }
    }
    var statusIcon: String {
        switch status {
        case "current":       return "checkmark.circle.fill"
        case "expiring_soon": return "exclamationmark.circle.fill"
        default:              return "xmark.circle.fill"
        }
    }
    var statusLabel: String {
        switch status {
        case "current":       return "Current"
        case "expiring_soon": return "Expiring Soon"
        case "expired":       return "Expired"
        default:              return "Missing"
        }
    }
    var formattedDate: String? {
        guard let d = date, !d.isEmpty else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let parsed = f.date(from: d) else { return d }
        let out = DateFormatter(); out.dateStyle = .medium
        return out.string(from: parsed)
    }
}

struct PilotDocRow: Identifiable, Decodable {
    let docKey: String
    let label: String
    let tone: String
    let statusText: String?
    let icon: String?
    let dateText: String?
    let expiresText: String?
    let fileUrl: String?
    let uploadKey: String?
    let canUpload: Bool?
    let isWaiver: Bool?
    let isTextonly: Bool?
    let file: String?

    var id: String { docKey }

    enum CodingKeys: String, CodingKey {
        case label, tone, icon, file
        case docKey = "doc_key"
        case statusText = "status_text"
        case dateText = "date_text"
        case expiresText = "expires_text"
        case fileUrl = "file_url"
        case uploadKey = "upload_key"
        case canUpload = "can_upload"
        case isWaiver = "is_waiver"
        case isTextonly = "is_textonly"
    }

    var uploadDocumentKey: String { uploadKey ?? docKey }
    var hasFile: Bool { !(file ?? "").isEmpty || !(fileUrl ?? "").isEmpty }
    var allowsUpload: Bool { canUpload == true && docKey != "jump" && !docKey.hasPrefix("lms_") && isWaiver != true }
}

struct PilotSignoff: Identifiable, Decodable {
    let key: String
    let label: String
    let signed: Bool
    let signedAt: String?
    let signedByName: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, signed
        case signedAt = "signed_at"
        case signedByName = "signed_by_name"
    }
}

struct PilotAircraftAccess: Identifiable, Decodable {
    let id: Int
    let tailNumber: String

    enum CodingKeys: String, CodingKey {
        case id
        case tailNumber = "tail_number"
    }
}

struct PilotCurrencyProfile: Decodable {
    let userId: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let overallStatus: String
    let readyTone: String?
    let readyLabel: String?
    let airworthy: Bool?
    let items: [PilotCurrencyItem]
    let docRows: [PilotDocRow]?
    let signoffs: [PilotSignoff]?
    let aircraft: [PilotAircraftAccess]?

    enum CodingKeys: String, CodingKey {
        case items, username, airworthy, signoffs, aircraft
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
}

private struct ProfileResponse: Decodable {
    let ok: Bool
    let canEditDates: Bool?
    let profile: PilotCurrencyProfile?
    enum CodingKeys: String, CodingKey {
        case ok, profile
        case canEditDates = "can_edit_dates"
    }
}

private struct UploadResult: Decodable {
    let filename: String?
    let path: String?
}

private struct UploadResponse: Decodable {
    let ok: Bool
    let data: UploadResult?
    let filename: String?
    let path: String?
    let error: String?
}

// MARK: - ViewModel

@MainActor
class PilotCurrencyViewModel: ObservableObject {
    @Published var profile: PilotCurrencyProfile?
    @Published var canEditDates = false
    @Published var isLoading = false
    @Published var uploading: String?
    @Published var uploadError: String?
    @Published var uploadSuccess: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/pilots/profile.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(ProfileResponse.self, from: data),
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
              let url = URL(string: "\(kServerURL)/api/pilots/upload.php") else { return }
        let body: [String: String] = [
            "document_key": key,
            "image_base64": data.base64EncodedString(),
            "mime_type": mimeType,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONEncoder().encode(body)
        guard let (respData, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(UploadResponse.self, from: respData) else {
            uploadError = "Upload failed — network error"
            return
        }
        if resp.ok {
            uploadSuccess = "Uploaded successfully"
            await load()
        } else {
            uploadError = resp.error ?? "Upload failed"
        }
    }
}

// MARK: - Pilot Card (full)

struct PilotCurrencyCard: View {
    var compact = false

    @StateObject private var vm = PilotCurrencyViewModel()
    @State private var activeUploadKey: String?
    @State private var showDocumentScanner = false
    @State private var previewURL: URL?
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
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.primary)
                Text(compact ? "PILOT CURRENCY" : "PILOT CARD")
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
            Text("Loading pilot card…").font(.system(size: 12)).foregroundColor(colors.muted)
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
    private func compactBody(_ p: PilotCurrencyProfile) -> some View {
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
    }

    @ViewBuilder
    private func fullCardBody(_ p: PilotCurrencyProfile) -> some View {
        Text(p.resolvedName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(colors.text)

        HStack(spacing: 8) {
            statusPill(label: p.readyLabel ?? "Not ready", tone: p.readyTone ?? "missing")
            if p.airworthy == true {
                statusPill(label: "Airworthy", tone: "ok")
            } else {
                statusPill(label: "Pending final check", tone: "warn")
            }
        }
        .padding(.top, 2)

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
                    onPreview: { openPreview(row) }
                )
                if row.id != rows.last?.id {
                    Divider().background(colors.border).padding(.vertical, 6)
                }
            }
        }

        if let signoffs = p.signoffs, !signoffs.isEmpty {
            Divider().background(colors.border).padding(.top, 4)
            Text("OPERATIONAL SIGNOFFS")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1.2)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(signoffs) { signoff in
                    PilotSignoffRow(signoff: signoff)
                }
            }
        }

        if let aircraft = p.aircraft, !aircraft.isEmpty {
            Divider().background(colors.border).padding(.top, 4)
            HStack(spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.muted)
                Text("Aircraft access (\(aircraft.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colors.text)
            }
            .padding(.top, 4)
            FlowTailChips(tails: aircraft.map(\.tailNumber))
        }
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

// MARK: - Full card rows

struct PilotDocRowView: View {
    let row: PilotDocRow
    let isUploading: Bool
    let onUpload: () -> Void
    let onPreview: () -> Void
    var onOpenTraining: (() -> Void)? = nil
    @Environment(\.mdzColors) private var colors

    private var isTrainingRow: Bool {
        row.docKey == "jump" || row.docKey.hasPrefix("lms_")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: rowIcon)
                .foregroundColor(rowToneColor)
                .font(.system(size: 16))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.text)
                if isTrainingRow {
                    Text(row.statusText ?? "Not Started")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                } else if let date = row.dateText, date != "—" {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                    if let exp = row.expiresText, !exp.isEmpty {
                        Text("Exp \(exp)")
                            .font(.system(size: 10))
                            .foregroundColor(colors.muted)
                    }
                } else if let status = row.statusText {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }

            Spacer(minLength: 8)

            if isTrainingRow {
                if let onOpenTraining {
                    Button(action: onOpenTraining) {
                        actionLabel("Training", systemImage: "graduationcap.fill", filled: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Training")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(colors.muted)
                }
            } else if isUploading {
                ProgressView().tint(colors.primary).scaleEffect(0.75)
            } else if row.hasFile {
                Button(action: onPreview) {
                    actionLabel("Preview", systemImage: "doc.text.magnifyingglass", filled: false)
                }
                .buttonStyle(.plain)
            } else if row.allowsUpload {
                Button(action: onUpload) {
                    actionLabel("Upload", systemImage: "camera.fill", filled: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var rowIcon: String {
        switch row.tone {
        case "ok":      return "checkmark.circle.fill"
        case "warn":    return "exclamationmark.circle.fill"
        case "expired": return "xmark.circle.fill"
        default:        return "xmark.circle.fill"
        }
    }

    private var rowToneColor: Color {
        switch row.tone {
        case "ok":      return colors.green
        case "warn":    return colors.amber
        case "expired": return colors.danger
        default:        return colors.danger
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String, filled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 10))
            Text(title).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(filled ? .white : colors.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(filled ? colors.accent : colors.green.opacity(0.15))
        .cornerRadius(8)
    }
}

private struct PilotSignoffRow: View {
    let signoff: PilotSignoff
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack {
            Text(signoff.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.text)
            Spacer()
            Text(signoff.signed ? "Signed" : "Not signed")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(signoff.signed ? colors.green : colors.amber)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((signoff.signed ? colors.green : colors.amber).opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

private struct FlowTailChips: View {
    let tails: [String]
    @Environment(\.mdzColors) private var colors

    var body: some View {
        FlexibleChipLayout(spacing: 8) {
            ForEach(tails, id: \.self) { tail in
                Text(tail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colors.border.opacity(0.35))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FlexibleChipLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - iPhone compact row (staff home)

struct CurrencyRow: View {
    let item: PilotCurrencyItem
    let canEdit: Bool
    let isUploading: Bool
    let statusColor: Color
    let onUpload: (String) -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.system(size: 13, weight: .semibold)).foregroundColor(colors.text)
                if let date = item.formattedDate {
                    Text("\(item.dateLabel): \(date)").font(.system(size: 10)).foregroundColor(colors.muted)
                } else {
                    Text(item.statusLabel).font(.system(size: 10, weight: .medium)).foregroundColor(statusColor)
                }
            }
            Spacer()
            if isUploading {
                ProgressView().tint(colors.primary).scaleEffect(0.7).frame(width: 70)
            } else {
                Button { onUpload(item.key) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.file != nil ? "arrow.triangle.2.circlepath" : "camera.fill")
                            .font(.system(size: 10))
                        Text(item.file != nil ? "Replace" : "Upload")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(item.file != nil ? colors.primary : colors.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Pilot Card tab (ASC Pilots)

struct PilotCardRootView: View {
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    PilotCurrencyCard(compact: false)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
            .navigationTitle("Pilot Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
