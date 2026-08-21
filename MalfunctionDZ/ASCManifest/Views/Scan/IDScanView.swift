import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct IDScanView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss

    enum Subject {
        case user(Int)
        case tandem(Int)
    }

    let subject: Subject
    /// Called after a successful store (barcode or marked photo). `idChecked` mirrors API.
    var onCompleted: ((IDScanParsed?, Bool) -> Void)? = nil

    @State private var barcodeText = ""
    @State private var parsed: IDScanParsed?
    @State private var previewText: String?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isUploading = false
    @State private var showScanner = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var cameraMessage: String?

    init(userID: Int, onCompleted: ((IDScanParsed?, Bool) -> Void)? = nil) {
        self.subject = .user(userID)
        self.onCompleted = onCompleted
    }

    init(tandemStudentID: Int, onCompleted: ((IDScanParsed?, Bool) -> Void)? = nil) {
        self.subject = .tandem(tandemStudentID)
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Hold the back of the license in frame so the PDF417 barcode is readable.")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if showScanner && barcodeText.isEmpty && photoData == nil {
                    ZStack {
                        BarcodeScannerView(
                            onScan: { code in
                                barcodeText = code
                                showScanner = false
                                cameraMessage = nil
                                Task { await upload(markChecked: true, autoDismiss: true) }
                            },
                            onUnavailable: { message in
                                cameraMessage = message
                                showScanner = false
                            }
                        )
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if cameraMessage != nil {
                            Color.black.opacity(0.55)
                        }
                    }
                    .padding(.horizontal)
                }

                if let cameraMessage {
                    VStack(spacing: 10) {
                        Text(cameraMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button("Open Settings") { openSettings() }
                                .buttonStyle(.bordered)
                            Button("Retry camera") {
                                self.cameraMessage = nil
                                showScanner = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(NightOps.accent)
                        }
                    }
                    .padding(.horizontal)
                }

                Form {
                    Section("Manual barcode text") {
                        TextField("Paste PDF417 payload if camera fails", text: $barcodeText, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section("Or photo of license") {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose photo", systemImage: "photo")
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    photoData = data
                                    showScanner = false
                                }
                            }
                        }
                        if photoData != nil {
                            Text("Photo attached — submit to store it. Barcode decode works best from the back.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let parsed {
                        Section("Decoded") {
                            if let first = parsed.first_name, let last = parsed.last_name {
                                LabeledContent("Name", value: "\(first) \(last)")
                            }
                            if let dob = parsed.date_of_birth {
                                LabeledContent("DOB", value: dob)
                            }
                            if let lic = parsed.license_number {
                                LabeledContent("License #", value: lic)
                            }
                            if let state = parsed.state {
                                LabeledContent("State", value: state)
                            }
                        }
                    } else if let previewText, !previewText.isEmpty {
                        Section("Scan") {
                            Text(previewText)
                                .font(.footnote)
                        }
                    }

                    if let statusMessage {
                        Section {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if !showScanner {
                        Button("Scan again") {
                            barcodeText = ""
                            photoData = nil
                            selectedPhoto = nil
                            errorMessage = nil
                            statusMessage = nil
                            parsed = nil
                            previewText = nil
                            cameraMessage = nil
                            showScanner = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        Task { await upload(markChecked: true, autoDismiss: true) }
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(submitLabel)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NightOps.accent)
                    .disabled(isUploading || (barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoData == nil))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(NightOps.navy)
            .navigationTitle("Scan ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if AVCaptureDevice.authorizationStatus(for: .video) == .denied
                    || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                    cameraMessage =
                        "Camera access is required to scan a driver's license barcode. Enable Camera in Settings."
                    showScanner = false
                }
            }
        }
    }

    private var submitLabel: String {
        if !barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Submit barcode"
        }
        if photoData != nil {
            return "Upload photo"
        }
        return "Submit scan"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func upload(markChecked: Bool, autoDismiss: Bool) async {
        let trimmed = barcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || photoData != nil else {
            errorMessage = "Scan the barcode on the back of the license, or attach a photo."
            return
        }

        isUploading = true
        errorMessage = nil
        statusMessage = nil
        defer { isUploading = false }

        do {
            let response: IDScanResponse
            switch subject {
            case .user(let userID):
                response = try await session.apiClient.scanID(
                    userID: userID,
                    tandemStudentID: nil,
                    barcodeText: trimmed,
                    imageData: photoData,
                    markChecked: markChecked
                )
            case .tandem(let tandemID):
                response = try await session.apiClient.scanID(
                    userID: nil,
                    tandemStudentID: tandemID,
                    barcodeText: trimmed,
                    imageData: photoData,
                    markChecked: markChecked
                )
            }

            parsed = response.parsed
            previewText = response.preview
            if response.ok {
                let checked = response.id_checked ?? markChecked
                statusMessage = checked
                    ? "ID scanned and marked checked."
                    : "Scan saved."
                onCompleted?(response.parsed, checked)
                if autoDismiss {
                    dismiss()
                }
            } else {
                errorMessage = response.error
                    ?? "Could not read the barcode. Use the back of the license, fill the frame, and try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
