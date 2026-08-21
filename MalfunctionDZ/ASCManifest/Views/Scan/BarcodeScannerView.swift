import AVFoundation
import SwiftUI
import UIKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onUnavailable: ((String) -> Void)?

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onUnavailable = onUnavailable
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.onScan = onScan
        uiViewController.onUnavailable = onUnavailable
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onUnavailable: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didNotifyUnavailable = false
    private var hasEmittedScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.fail(
                            "Camera access is required to scan a driver's license barcode. Enable Camera in Settings."
                        )
                    }
                }
            }
        case .denied, .restricted:
            fail(
                "Camera access is required to scan a driver's license barcode. Enable Camera in Settings."
            )
        @unknown default:
            fail("Camera is unavailable on this device.")
        }
    }

    private func configureSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video) else {
            fail("No camera available on this device.")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                fail("Could not start the camera for barcode scanning.")
                return
            }
            session.addInput(input)
        } catch {
            fail("Could not start the camera for barcode scanning.")
            return
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            fail("Could not start the barcode scanner.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        let supported: [AVMetadataObject.ObjectType] = [.pdf417, .code128, .qr]
        output.metadataObjectTypes = supported.filter { output.availableMetadataObjectTypes.contains($0) }
        if !output.metadataObjectTypes.contains(.pdf417) {
            fail("This device cannot read PDF417 ID barcodes.")
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        captureSession = session
        previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func fail(_ message: String) {
        guard !didNotifyUnavailable else { return }
        didNotifyUnavailable = true
        onUnavailable?(message)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasEmittedScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue, !value.isEmpty else { return }
        hasEmittedScan = true
        captureSession?.stopRunning()
        onScan?(value)
    }
}
