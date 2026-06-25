import SwiftUI
import VisionKit
import PDFKit

// MARK: - Document camera (VisionKit)

struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void
    var onCancel: () -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error.localizedDescription)
        }
    }
}

enum PilotDocumentScanPayload {
    static func dataAndMime(from images: [UIImage]) -> (Data, String, String)? {
        guard let first = images.first else { return nil }
        if images.count == 1, let jpeg = first.jpegData(compressionQuality: 0.88) {
            return (jpeg, "image/jpeg", "scan.jpg")
        }
        let doc = PDFDocument()
        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            doc.insert(page, at: index)
        }
        guard let pdf = doc.dataRepresentation() else { return nil }
        return (pdf, "application/pdf", "scan.pdf")
    }
}

struct DocumentScannerSheet: View {
    let onScanned: (Data, String, String) -> Void
    let onDismiss: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        Group {
            if VNDocumentCameraViewController.isSupported {
                DocumentScannerView(
                    onComplete: { images in
                        if let payload = PilotDocumentScanPayload.dataAndMime(from: images) {
                            onScanned(payload.0, payload.1, payload.2)
                        } else {
                            errorMessage = "Could not process scanned pages."
                        }
                    },
                    onCancel: onDismiss,
                    onError: { message in
                        errorMessage = message
                    }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                    Text("Document scanning is not available on this device.")
                        .multilineTextAlignment(.center)
                    Button("Close", action: onDismiss)
                }
                .padding(24)
            }
        }
        .alert("Scan failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil; onDismiss() } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
                onDismiss()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
