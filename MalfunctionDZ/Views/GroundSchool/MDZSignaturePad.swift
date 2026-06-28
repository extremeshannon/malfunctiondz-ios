// UIKit signature pad — PKCanvasView owned by a view controller (reliable finger/stylus input).
import SwiftUI
import PencilKit

final class MDZSignaturePadViewController: UIViewController, PKCanvasViewDelegate {
    let canvasView = PKCanvasView()
    var inkColor: UIColor = .black
    var lineWidth: CGFloat = 5
    var paperColor: UIColor = .white
    var onDrawingChanged: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = paperColor
        canvasView.delegate = self
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = paperColor
        canvasView.isOpaque = paperColor != .clear
        canvasView.isScrollEnabled = false
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.isUserInteractionEnabled = true
        applyTool()

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
        _ = canvasView.becomeFirstResponder()
    }

    func applyTool() {
        canvasView.tool = PKInkingTool(.pen, color: inkColor, width: lineWidth)
    }

    func clearDrawing() {
        canvasView.drawing = PKDrawing()
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onDrawingChanged?()
    }
}

struct MDZSignaturePadScreen: UIViewControllerRepresentable {
    var inkColor: UIColor = .black
    var lineWidth: CGFloat = 5
    var paperColor: UIColor = .white
    var onDrawingChanged: (() -> Void)?
    var onPadReady: ((MDZSignaturePadViewController) -> Void)?

    func makeUIViewController(context: Context) -> MDZSignaturePadViewController {
        let vc = MDZSignaturePadViewController()
        vc.inkColor = inkColor
        vc.lineWidth = lineWidth
        vc.paperColor = paperColor
        vc.onDrawingChanged = onDrawingChanged
        context.coordinator.pad = vc
        DispatchQueue.main.async { onPadReady?(vc) }
        return vc
    }

    func updateUIViewController(_ vc: MDZSignaturePadViewController, context: Context) {
        context.coordinator.pad = vc
        vc.inkColor = inkColor
        vc.lineWidth = lineWidth
        vc.paperColor = paperColor
        vc.onDrawingChanged = onDrawingChanged
        vc.view.backgroundColor = paperColor
        vc.applyTool()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var pad: MDZSignaturePadViewController?
    }
}

func signatureImageFromPad(_ pad: MDZSignaturePadViewController?) -> UIImage? {
    guard let pad else { return nil }
    let rect = pad.canvasView.drawing.bounds
    guard !rect.isEmpty else { return nil }
    let padded = rect.insetBy(dx: -24, dy: -16)
    return pad.canvasView.drawing.image(from: padded, scale: 2)
}
