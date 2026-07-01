// Finger signature pad — SwiftUI Canvas + DragGesture (no PencilKit; works on all devices).
import SwiftUI
import UIKit
import MalfunctionDZCore

/// One continuous finger/stylus stroke as a series of points in pad coordinates.
typealias MDZSignatureStroke = [CGPoint]

struct MDZFingerSignaturePad: View {
    @Binding var strokes: [MDZSignatureStroke]
    var inkColor: Color = .black
    var lineWidth: CGFloat = 4
    var paperColor: Color = .white
    var onDrawingChanged: (() -> Void)?

    @State private var currentStroke: [CGPoint] = []

    private var renderedStrokes: [MDZSignatureStroke] {
        if currentStroke.isEmpty { return strokes }
        return strokes + [currentStroke]
    }

    var body: some View {
        Canvas { context, _ in
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            for stroke in renderedStrokes {
                guard !stroke.isEmpty else { continue }
                if stroke.count == 1, let p = stroke.first {
                    let dot = Path(ellipseIn: CGRect(x: p.x - lineWidth / 2, y: p.y - lineWidth / 2, width: lineWidth, height: lineWidth))
                    context.fill(dot, with: .color(inkColor))
                    continue
                }
                var path = Path()
                path.move(to: stroke[0])
                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(inkColor), style: style)
            }
        }
        .background(paperColor)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    currentStroke.append(value.location)
                    onDrawingChanged?()
                }
                .onEnded { _ in
                    if !currentStroke.isEmpty {
                        strokes.append(currentStroke)
                        currentStroke = []
                        onDrawingChanged?()
                    }
                }
        )
    }

    static func clear(_ strokes: inout [MDZSignatureStroke]) {
        strokes.removeAll()
    }

    static func hasInk(_ strokes: [MDZSignatureStroke]) -> Bool {
        strokes.contains { !$0.isEmpty }
    }
}

func signatureImageFromStrokes(
    _ strokes: [MDZSignatureStroke],
    ink: UIColor = .black,
    lineWidth: CGFloat = 4,
    padding: CGFloat = 24
) -> UIImage? {
    let points = strokes.flatMap { $0 }
    guard !points.isEmpty else { return nil }

    let minX = points.map(\.x).min()! - padding
    let minY = points.map(\.y).min()! - padding
    let maxX = points.map(\.x).max()! + padding
    let maxY = points.map(\.y).max()! + padding
    let width = max(maxX - minX, lineWidth * 2)
    let height = max(maxY - minY, lineWidth * 2)
    let size = CGSize(width: width, height: height)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))

        ink.setStroke()
        ctx.cgContext.setLineWidth(lineWidth)
        ctx.cgContext.setLineCap(.round)
        ctx.cgContext.setLineJoin(.round)

        for stroke in strokes where !stroke.isEmpty {
            ctx.cgContext.beginPath()
            let start = CGPoint(x: stroke[0].x - minX, y: stroke[0].y - minY)
            ctx.cgContext.move(to: start)
            if stroke.count == 1 {
                ctx.cgContext.addArc(center: start, radius: lineWidth / 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                ctx.cgContext.fillPath()
                continue
            }
            for point in stroke.dropFirst() {
                ctx.cgContext.addLine(to: CGPoint(x: point.x - minX, y: point.y - minY))
            }
            ctx.cgContext.strokePath()
        }
    }
}

enum MDZSignatureURL {
    static func absolute(_ path: String, cacheBuster: Int = 0) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        let p = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        var urlString = "\(base)\(p)"
        if cacheBuster > 0 {
            urlString += p.contains("?") ? "&v=\(cacheBuster)" : "?v=\(cacheBuster)"
        }
        return URL(string: urlString)
    }
}

struct MDZSignaturePreview: View {
    let localImage: UIImage?
    let remotePath: String
    let cacheBuster: Int
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current signature")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)

            Group {
                if let localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 90)
                } else if !remotePath.isEmpty {
                    MDZRemoteSignatureImage(path: remotePath, cacheBuster: cacheBuster)
                        .frame(maxHeight: 90)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
        }
    }
}

struct MDZRemoteSignatureImage: View {
    let path: String
    let cacheBuster: Int
    @Environment(\.mdzColors) private var colors
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Text("Could not load saved signature")
                    .font(.system(size: 11))
                    .foregroundColor(colors.danger)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .tint(colors.amber)
            }
        }
        .task(id: "\(path)-\(cacheBuster)") {
            await load()
        }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url = MDZSignatureURL.absolute(path, cacheBuster: cacheBuster) else {
            failed = true
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let img = UIImage(data: data) else {
                failed = true
                return
            }
            image = img
        } catch {
            failed = true
        }
    }
}
