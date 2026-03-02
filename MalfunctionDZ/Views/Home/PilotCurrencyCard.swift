// File: ASC/Views/Home/PilotCurrencyCard.swift
// iPad: Wide layout shows all currency columns in a table-style row.
import SwiftUI
import PhotosUI

// MARK: - Models (unchanged)
struct PilotCurrencyItem: Identifiable, Decodable {
    let key: String; let label: String; let file: String?
    let date: String?; let dateLabel: String; let status: String
    var id: String { key }
    enum CodingKeys: String, CodingKey {
        case key, label, file, date, status; case dateLabel = "date_label"
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

struct PilotCurrencyProfile: Decodable {
    let userId: Int; let username: String; let firstName: String?; let lastName: String?
    let overallStatus: String; let items: [PilotCurrencyItem]
    enum CodingKeys: String, CodingKey {
        case items, username
        case userId = "user_id"; case firstName = "first_name"
        case lastName = "last_name"; case overallStatus = "overall_status"
    }
}

private struct ProfileResponse: Decodable {
    let ok: Bool; let canEditDates: Bool?; let profile: PilotCurrencyProfile?
    enum CodingKeys: String, CodingKey { case ok, profile; case canEditDates = "can_edit_dates" }
}
private struct UploadResult: Decodable { let filename: String?; let path: String? }

// MARK: - ViewModel (unchanged)
@MainActor
class PilotCurrencyViewModel: ObservableObject {
    @Published var profile:       PilotCurrencyProfile?
    @Published var canEditDates:  Bool    = false
    @Published var isLoading:     Bool    = false
    @Published var uploading:     String? = nil
    @Published var uploadError:   String? = nil
    @Published var uploadSuccess: String? = nil

    func load() async {
        isLoading = true; defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/pilots/profile.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(ProfileResponse.self, from: data), resp.ok else { return }
        profile = resp.profile; canEditDates = resp.canEditDates ?? false
    }

    func uploadImage(_ imageData: Data, mimeType: String, forKey key: String) async {
        uploading = key; uploadError = nil; uploadSuccess = nil; defer { uploading = nil }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/pilots/upload.php") else { return }
        let body: [String: String] = ["document_key": key, "image_base64": imageData.base64EncodedString(), "mime_type": mimeType]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONEncoder().encode(body)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(MobileResponse<UploadResult>.self, from: data) else {
            uploadError = "Upload failed — network error"; return
        }
        if resp.ok { uploadSuccess = "Uploaded successfully"; await load() }
        else { uploadError = resp.error ?? "Upload failed" }
    }
}

// MARK: - PilotCurrencyCard
struct PilotCurrencyCard: View {
    @StateObject private var vm = PilotCurrencyViewModel()
    @State private var activeUploadKey: String?
    @State private var showImagePicker  = false
    @State private var pickerItem:      PhotosPickerItem?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 11, weight: .black)).foregroundColor(.mdzBlue)
                    Text("PILOT CURRENCY")
                        .font(.system(size: 11, weight: .black)).foregroundColor(.mdzBlue).tracking(1.5)
                }
                Spacer()
                if let p = vm.profile {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(p.overallStatus == "ready" ? Color.mdzGreen : Color.mdzDanger)
                            .frame(width: 7, height: 7)
                        Text(p.overallStatus == "ready" ? "Ready" : "Not Ready")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(p.overallStatus == "ready" ? .mdzGreen : .mdzDanger)
                    }
                }
            }

            if vm.isLoading {
                HStack {
                    ProgressView().tint(.mdzBlue).scaleEffect(0.8)
                    Text("Loading currency…").font(.system(size: 12)).foregroundColor(.mdzMuted)
                }
            } else if let p = vm.profile {
                let name = [p.firstName, p.lastName].compactMap { $0 }.joined(separator: " ")
                if !name.isEmpty {
                    Text(name).font(.system(size: isWide ? 17 : 15, weight: .bold)).foregroundColor(.mdzText)
                }

                Divider().background(Color.mdzBorder)

                if isWide {
                    // ── iPad: table header row ──────────────────────
                    HStack {
                        Text("DOCUMENT").font(.system(size: 9, weight: .black)).foregroundColor(.mdzMuted).tracking(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text("STATUS").font(.system(size: 9, weight: .black)).foregroundColor(.mdzMuted).tracking(1).frame(width: 110)
                        Text("DATE").font(.system(size: 9, weight: .black)).foregroundColor(.mdzMuted).tracking(1).frame(width: 140)
                        Text("ACTION").font(.system(size: 9, weight: .black)).foregroundColor(.mdzMuted).tracking(1).frame(width: 90)
                    }
                    .padding(.horizontal, 4)

                    Divider().background(Color.mdzBorder)

                    VStack(spacing: 0) {
                        ForEach(p.items) { item in
                            WideCurrencyRow(
                                item:        item,
                                isUploading: vm.uploading == item.key
                            ) { key in
                                activeUploadKey = key; showImagePicker = true
                            }
                            if item.id != p.items.last?.id {
                                Divider().background(Color.mdzBorder)
                            }
                        }
                    }
                } else {
                    // ── iPhone: compact rows ────────────────────────
                    VStack(spacing: 0) {
                        ForEach(p.items) { item in
                            CurrencyRow(
                                item:        item,
                                canEdit:     vm.canEditDates,
                                isUploading: vm.uploading == item.key
                            ) { key in activeUploadKey = key; showImagePicker = true }
                            if item.id != p.items.last?.id {
                                Divider().background(Color.mdzBorder).padding(.vertical, 4)
                            }
                        }
                    }
                }

                if let err = vm.uploadError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundColor(.mdzDanger)
                }
                if let ok = vm.uploadSuccess {
                    Label(ok, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundColor(.mdzGreen)
                }
            }
        }
        .padding(isWide ? 20 : 14)
        .background(Color.mdzCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
        .task { await vm.load() }
        .photosPicker(isPresented: $showImagePicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { newItem in
            guard let key = activeUploadKey, let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await vm.uploadImage(data, mimeType: "image/jpeg", forKey: key)
                }
                pickerItem = nil
            }
        }
    }
}

// MARK: - iPad wide row (document | status pill | date | upload)
struct WideCurrencyRow: View {
    let item:        PilotCurrencyItem
    let isUploading: Bool
    let onUpload:    (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Document name
            HStack(spacing: 8) {
                Image(systemName: item.statusIcon)
                    .foregroundColor(item.statusColor)
                    .font(.system(size: 15))
                Text(item.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mdzText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status pill
            Text(item.statusLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(item.statusColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(item.statusColor.opacity(0.15))
                .clipShape(Capsule())
                .frame(width: 110)

            // Date
            Group {
                if let date = item.formattedDate {
                    Text("\(item.dateLabel): \(date)")
                        .font(.system(size: 12)).foregroundColor(.mdzMuted)
                } else {
                    Text("—").font(.system(size: 12)).foregroundColor(.mdzMuted)
                }
            }
            .frame(width: 140, alignment: .leading)

            // Upload button
            if isUploading {
                ProgressView().tint(.mdzBlue).scaleEffect(0.8).frame(width: 90)
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
                    .background(item.file != nil ? Color.mdzNavyLift : Color.mdzRed)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .frame(width: 90)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

// MARK: - iPhone compact row (unchanged)
struct CurrencyRow: View {
    let item:        PilotCurrencyItem
    let canEdit:     Bool
    let isUploading: Bool
    let onUpload:    (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.statusIcon)
                .foregroundColor(item.statusColor)
                .font(.system(size: 16)).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.system(size: 13, weight: .semibold)).foregroundColor(.mdzText)
                if let date = item.formattedDate {
                    Text("\(item.dateLabel): \(date)").font(.system(size: 10)).foregroundColor(.mdzMuted)
                } else {
                    Text(item.statusLabel).font(.system(size: 10, weight: .medium)).foregroundColor(item.statusColor)
                }
            }
            Spacer()
            if isUploading {
                ProgressView().tint(.mdzBlue).scaleEffect(0.7).frame(width: 70)
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
                    .background(item.file != nil ? Color.mdzNavyLift : Color.mdzRed)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}
