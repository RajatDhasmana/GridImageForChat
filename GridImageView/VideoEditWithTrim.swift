//
//  VideoEditWithTrim.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 03/07/26.
//

import Foundation

//
//  VideoTextEditorView.swift
//
//  Usage:
//      VideoTextEditorView(videoURL: url) { resultURL in ... }
//
//  Requirements: SwiftUI, AVFoundation, AVKit (all system frameworks).
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - Video Text Item

struct VideoTextItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var position: CGPoint
    var fontSize: CGFloat
    var color: Color

    init(id: UUID = UUID(), text: String = "", position: CGPoint,
         fontSize: CGFloat = 32, color: Color = .white) {
        self.id = id; self.text = text; self.position = position
        self.fontSize = fontSize; self.color = color
    }
}

// MARK: - Public View

struct VideoTextEditorView: View {

    let videoURL: URL
    let onComplete: (URL?) -> Void
    var onCancel: (() -> Void)? = nil

    @StateObject private var model: VideoTextEditorModel
    @State private var isPlayingVideo = false

    init(videoURL: URL, onCancel: (() -> Void)? = nil, onComplete: @escaping (URL?) -> Void) {
        self.videoURL = videoURL
        self.onCancel = onCancel
        self.onComplete = onComplete
        _model = StateObject(wrappedValue: VideoTextEditorModel(videoURL: videoURL))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, max(geo.safeAreaInsets.top, 12))

                    Spacer(minLength: 0)

                    // ── Canvas ──────────────────────────────────────────────
                    GeometryReader { canvasGeo in
                        let fitted = model.fittedFrame(in: canvasGeo.size)

                        ZStack {
                            thumbnailLayer(fitted: fitted)

                            ForEach(model.textItems) { item in
                                VideoTextItemView(model: model, item: item, canvasFrame: fitted)
                            }

                            if model.selectedID != nil {
                                HStack {
                                    Spacer()
                                    VideoVerticalHueColorBar(selectedColor: model.selectedColorBinding)
                                        .frame(width: 36,
                                               height: min(canvasGeo.size.height * 0.7, 260))
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .onAppear { model.setupCanvas(in: fitted) }
                        .onChange(of: canvasGeo.size) { _, newSize in
                            model.rescaleCanvas(to: model.fittedFrame(in: newSize))
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)

                    // ── Trim strip ──────────────────────────────────────────
                    if model.videoDuration > 0 {
                        TrimView(model: model)
                            .frame(height: 72)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }

                    bottomControls
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }
            }
        }
        .overlay {
            if model.isExporting { exportingOverlay }
        }
        .background(
            VideoHiddenTextInput(text: model.selectedTextBinding,
                                 isActive: $model.isEditingText)
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Export Failed", isPresented: $model.showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.exportErrorMessage)
        }
        .fullScreenCover(isPresented: $isPlayingVideo) {
            VideoPlayerOverlay(url: videoURL, isPresented: $isPlayingVideo)
        }
    }

    // MARK: Thumbnail layer

    @ViewBuilder
    private func thumbnailLayer(fitted: CGRect) -> some View {
        if let thumb = model.thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .frame(width: fitted.width, height: fitted.height)
                .position(x: fitted.midX, y: fitted.midY)
                .onTapGesture {
                    model.isEditingText = false
                    model.selectedID = nil
                }

            Button {
                model.isEditingText = false
                model.selectedID = nil
                isPlayingVideo = true
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            .position(x: fitted.midX, y: fitted.midY)

        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: fitted.width, height: fitted.height)
                ProgressView().tint(.white)
            }
            .position(x: fitted.midX, y: fitted.midY)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { onCancel?() } label: {
                Text("Cancel").foregroundStyle(.white)
            }
            Spacer()
            Button {
                model.exportVideo { url in onComplete(url) }
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .disabled(model.isExporting)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        HStack(spacing: 28) {
            Button { model.addText() } label: {
                Label("Add Text", systemImage: "textformat")
                    .foregroundStyle(.white).font(.callout.weight(.medium))
            }
            if model.selectedID != nil {
                Button { model.isEditingText = true } label: {
                    Label("Edit", systemImage: "pencil")
                        .foregroundStyle(.white).font(.callout.weight(.medium))
                }
                Button(role: .destructive) { model.removeSelectedText() } label: {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.white).font(.callout.weight(.medium))
                }
            }
        }
    }

    // MARK: Export overlay

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: model.exportProgress)
                    .progressViewStyle(.circular).tint(.white).scaleEffect(1.4)
                Text("Exporting…").foregroundStyle(.white).font(.callout.weight(.medium))
                Text("\(Int(model.exportProgress * 100))%")
                    .foregroundStyle(.white.opacity(0.7)).font(.caption)
            }
        }
    }
}

// MARK: - Trim View

/// A horizontal strip showing video frame thumbnails with draggable left/right
/// handles. Dragging a handle trims the start or end of the video.
private struct TrimView: View {
    @ObservedObject var model: VideoTextEditorModel

    // How much of the strip each handle's drag started from
    @State private var dragStartLeft:  CGFloat = 0
    @State private var dragStartRight: CGFloat = 0

    private let handleWidth: CGFloat = 14
    private let cornerRadius: CGFloat = 6
    private let minTrimGap: CGFloat = 0.05 // minimum 5% of duration between handles

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let leftX  = model.trimStart * W           // left handle leading edge
            let rightX = model.trimEnd   * W           // right handle trailing edge

            ZStack(alignment: .leading) {

                // ── Frame thumbnails ──────────────────────────────────────
                thumbnailStrip(width: W, height: H)
                    .cornerRadius(cornerRadius)

                // ── Outside-trim dimming ──────────────────────────────────
                // Left dim
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: leftX, height: H)

                // Right dim
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: W - rightX, height: H)
                    .offset(x: rightX)

                // ── Selected range border (top + bottom lines) ────────────
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: rightX - leftX, height: 3)
                    .offset(x: leftX)

                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: rightX - leftX, height: 3)
                    .offset(x: leftX, y: H - 3)

                // ── Left handle ───────────────────────────────────────────
                TrimHandle(side: .left)
                    .frame(width: handleWidth, height: H)
                    .offset(x: leftX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartLeft == 0 && value.translation.width == 0 {
                                    dragStartLeft = model.trimStart
                                }
                                let proposed = dragStartLeft + value.translation.width / W
                                model.trimStart = min(max(proposed, 0),
                                                      model.trimEnd - minTrimGap)
                            }
                            .onEnded { _ in dragStartLeft = 0 }
                    )

                // ── Right handle ──────────────────────────────────────────
                TrimHandle(side: .right)
                    .frame(width: handleWidth, height: H)
                    .offset(x: rightX - handleWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartRight == 0 && value.translation.width == 0 {
                                    dragStartRight = model.trimEnd
                                }
                                let proposed = dragStartRight + value.translation.width / W
                                model.trimEnd = max(min(proposed, 1),
                                                    model.trimStart + minTrimGap)
                            }
                            .onEnded { _ in dragStartRight = 0 }
                    )

                // ── Time labels ───────────────────────────────────────────
                HStack {
                    Text(timeString(model.trimStart * model.videoDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.leading, leftX + handleWidth + 2)
                    Spacer()
                    Text(timeString(model.trimEnd * model.videoDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.trailing, (W - rightX) + handleWidth + 2)
                }
                .frame(width: W)
                .allowsHitTesting(false)
            }
            .frame(width: W, height: H)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    // Horizontal row of thumbnails
    @ViewBuilder
    private func thumbnailStrip(width: CGFloat, height: CGFloat) -> some View {
        let count = model.stripThumbnails.count
        if count > 0 {
            HStack(spacing: 0) {
                ForEach(0 ..< count, id: \.self) { i in
                    if let img = model.stripThumbnails[i] {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width / CGFloat(count), height: height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: width / CGFloat(count), height: height)
                    }
                }
            }
        } else {
            Rectangle().fill(Color.white.opacity(0.06))
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = max(0, seconds)
        let m = Int(s) / 60
        let sec = Int(s) % 60
        let ms  = Int((s.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", m, sec, ms)
    }
}

// MARK: Trim handle shape

private struct TrimHandle: View {
    enum Side { case left, right }
    let side: Side

    var body: some View {
        ZStack {
            // Yellow background bar
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow)

            // Grip chevron
            Image(systemName: side == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
        }
        // Expand the hit area beyond the visible bar
        .contentShape(Rectangle().inset(by: -10))
    }
}

// MARK: - Draggable / zoomable text item view

private struct VideoTextItemView: View {
    @ObservedObject var model: VideoTextEditorModel
    let item: VideoTextItem
    let canvasFrame: CGRect

    private var isSelected: Bool { model.selectedID == item.id }

    var body: some View {
        Text(item.text.isEmpty ? "Tap to edit" : item.text)
            .font(.system(size: item.fontSize, weight: .bold))
            .foregroundStyle(item.color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(isSelected ? 0.18 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
            )
            .position(item.position)
            .gesture(dragGesture.simultaneously(with: zoomGesture))
            .onTapGesture { model.select(item.id) }
            .frame(width: canvasFrame.width, height: canvasFrame.height, alignment: .topLeading)
            .allowsHitTesting(true)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                model.select(item.id)
                if !model.isDragging { model.beginDrag(for: item.id) }
                model.drag(translation: value.translation,
                           bounds: CGRect(origin: .zero, size: canvasFrame.size))
            }
            .onEnded { _ in model.endDrag() }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                model.select(item.id)
                if !model.isZooming { model.beginZoom(for: item.id) }
                model.zoom(scale: scale)
            }
            .onEnded { _ in model.endZoom() }
    }
}

// MARK: - Vertical hue color bar

private struct VideoVerticalHueColorBar: View {
    @Binding var selectedColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: geo.size.width / 2)
                    .fill(LinearGradient(colors: hueColors, startPoint: .top, endPoint: .bottom))
                Circle()
                    .fill(selectedColor)
                    .frame(width: geo.size.width + 6, height: geo.size.width + 6)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: geo.size.width / 2, y: handleY(in: geo.size))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                updateColor(atY: value.location.y, height: geo.size.height)
            })
        }
    }

    private var hueColors: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 0.9, brightness: 1.0)
        }
    }

    private func handleY(in size: CGSize) -> CGFloat {
        var hue: CGFloat = 0
        UIColor(selectedColor).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue * size.height
    }

    private func updateColor(atY y: CGFloat, height: CGFloat) {
        guard height > 0 else { return }
        selectedColor = Color(hue: min(max(y, 0), height) / height, saturation: 0.9, brightness: 1.0)
    }
}

// MARK: - Full-screen video player overlay

private struct VideoPlayerOverlay: View {
    let url: URL
    @Binding var isPresented: Bool
    @StateObject private var holder: PlayerHolder

    init(url: URL, isPresented: Binding<Bool>) {
        self.url = url
        self._isPresented = isPresented
        _holder = StateObject(wrappedValue: PlayerHolder(url: url))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: holder.player).ignoresSafeArea()
            Button {
                holder.player.pause()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(16)
            }
        }
        .onAppear   { holder.player.play() }
        .onDisappear { holder.player.pause() }
    }

    final class PlayerHolder: ObservableObject {
        let player: AVPlayer
        init(url: URL) { player = AVPlayer(url: url) }
    }
}

// MARK: - Hidden keyboard input bridge

private struct VideoHiddenTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> UITextField {
        let f = UITextField(); f.delegate = context.coordinator
        f.returnKeyType = .done; f.isHidden = true; return f
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if isActive, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        else if !isActive, uiView.isFirstResponder { uiView.resignFirstResponder() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: VideoHiddenTextInput
        init(_ p: VideoHiddenTextInput) { parent = p }
        func textFieldDidChangeSelection(_ tf: UITextField) { parent.text = tf.text ?? "" }
        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.isActive = false; return true }
    }
}

// MARK: - Model

@MainActor
final class VideoTextEditorModel: ObservableObject {

    let videoURL: URL

    @Published var thumbnail: UIImage?
    @Published var stripThumbnails: [UIImage?] = []   // for the trim strip
    @Published var videoDuration: Double = 0

    // Trim: normalised 0-1 fractions of the total duration
    @Published var trimStart: CGFloat = 0
    @Published var trimEnd:   CGFloat = 1

    @Published var textItems: [VideoTextItem] = []
    @Published var selectedID: UUID?
    @Published var isEditingText = false
    @Published var isDragging    = false
    @Published var isZooming     = false
    @Published var isExporting   = false
    @Published var exportProgress: Double = 0
    @Published var showExportError   = false
    @Published var exportErrorMessage = ""

    private(set) var canvasFrame: CGRect = .zero
    private var videoSize: CGSize = .zero

    private var dragStartPos: CGPoint = .zero
    private var fontSizeAtZoomStart: CGFloat = 32
    private var activeGestureID: UUID?

    private let minFontSize: CGFloat = 12
    private let maxFontSize: CGFloat = 160

    private var exportTask: Task<Void, Never>?

    init(videoURL: URL) {
        self.videoURL = videoURL
        Task { await loadMetadata() }
    }

    // MARK: Load metadata + thumbnails

    private func loadMetadata() async {
        let asset = AVURLAsset(url: videoURL)

        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let size  = (try? await track.load(.naturalSize)) ?? .zero
            let xform = (try? await track.load(.preferredTransform)) ?? .identity
            let t = size.applying(xform)
            videoSize = CGSize(width: abs(t.width), height: abs(t.height))
        }

        let dur = try? await asset.load(.duration)
        videoDuration = dur.map { CMTimeGetSeconds($0) } ?? 0

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        // Preview thumbnail (first frame)
        let t0 = CMTime(seconds: 0, preferredTimescale: 600)
        if let cg = try? await generator.image(at: t0).image {
            thumbnail = UIImage(cgImage: cg)
        }

        // Strip thumbnails — 12 evenly spaced frames
        await loadStripThumbnails(asset: asset, count: 12)
    }

    private func loadStripThumbnails(asset: AVAsset, count: Int) async {
        guard videoDuration > 0 else { return }

        // Pre-fill with nils so the strip shows placeholders immediately
        stripThumbnails = Array(repeating: nil, count: count)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)   // small — just for the strip
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.1, preferredTimescale: 600)

        let times: [CMTime] = (0 ..< count).map { i in
            let fraction = Double(i) / Double(count - 1)
            return CMTime(seconds: fraction * videoDuration, preferredTimescale: 600)
        }

        for (i, time) in times.enumerated() {
            if let cg = try? await generator.image(at: time).image {
                stripThumbnails[i] = UIImage(cgImage: cg)
            }
        }
    }

    // MARK: Canvas layout

    func fittedFrame(in containerSize: CGSize) -> CGRect {
        let src = videoSize.width > 0 ? videoSize : CGSize(width: 16, height: 9)
        guard containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let aspect = src.width / src.height
        var size = containerSize
        if aspect > containerSize.width / containerSize.height {
            size.height = containerSize.width / aspect
        } else {
            size.width = containerSize.height * aspect
        }
        let origin = CGPoint(x: (containerSize.width  - size.width)  / 2,
                              y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    func setupCanvas(in frame: CGRect) { canvasFrame = frame }

    func rescaleCanvas(to newFrame: CGRect) {
        let old = canvasFrame
        guard old.width > 0, old.height > 0 else { canvasFrame = newFrame; return }
        let sx = newFrame.width / old.width, sy = newFrame.height / old.height
        for i in textItems.indices {
            textItems[i].position.x *= sx; textItems[i].position.y *= sy
            textItems[i].fontSize   *= (sx + sy) / 2
        }
        canvasFrame = newFrame
    }

    // MARK: Bindings

    var selectedTextBinding: Binding<String> {
        Binding(
            get: { [weak self] in
                guard let self, let id = selectedID,
                      let item = textItems.first(where: { $0.id == id }) else { return "" }
                return item.text
            },
            set: { [weak self] val in
                guard let self, let id = selectedID else { return }
                self.updateItem(id) { $0.text = val }
            }
        )
    }

    var selectedColorBinding: Binding<Color> {
        Binding(
            get: { [weak self] in
                guard let self, let id = selectedID,
                      let item = textItems.first(where: { $0.id == id }) else { return .white }
                return item.color
            },
            set: { [weak self] val in
                guard let self, let id = selectedID else { return }
                self.updateItem(id) { $0.color = val }
            }
        )
    }

    private func updateItem(_ id: UUID, _ mutate: (inout VideoTextItem) -> Void) {
        guard let i = textItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&textItems[i])
    }

    // MARK: Text lifecycle

    func addText() {
        let offset = CGFloat(textItems.count % 5) * 18
        let pos = CGPoint(x: canvasFrame.width / 2 + offset - 36,
                           y: canvasFrame.height / 2 + offset - 36)
        let item = VideoTextItem(text: "", position: pos)
        textItems.append(item); selectedID = item.id; isEditingText = true
    }

    func select(_ id: UUID) { guard selectedID != id else { return }; selectedID = id }

    func removeSelectedText() {
        guard let id = selectedID else { return }
        textItems.removeAll { $0.id == id }
        selectedID = nil; isEditingText = false
    }

    // MARK: Drag / Zoom

    func beginDrag(for id: UUID) {
        activeGestureID = id
        dragStartPos = textItems.first(where: { $0.id == id })?.position ?? .zero
        isDragging = true
    }

    func drag(translation: CGSize, bounds: CGRect) {
        guard let id = activeGestureID else { return }
        let p = CGPoint(x: dragStartPos.x + translation.width,
                         y: dragStartPos.y + translation.height)
        updateItem(id) { $0.position = CGPoint(
            x: min(max(p.x, bounds.minX), bounds.maxX),
            y: min(max(p.y, bounds.minY), bounds.maxY))
        }
    }

    func endDrag() { isDragging = false; activeGestureID = nil }

    func beginZoom(for id: UUID) {
        activeGestureID = id
        fontSizeAtZoomStart = textItems.first(where: { $0.id == id })?.fontSize ?? 32
        isZooming = true
    }

    func zoom(scale: CGFloat) {
        guard let id = activeGestureID else { return }
        updateItem(id) { $0.fontSize = min(max(fontSizeAtZoomStart * scale, minFontSize), maxFontSize) }
    }

    func endZoom() { isZooming = false; activeGestureID = nil }

    // MARK: Export

    func exportVideo(completion: @escaping (URL?) -> Void) {
        let items    = textItems.filter { !$0.text.isEmpty }
        let trimRange = CMTimeRange(
            start:    CMTime(seconds: trimStart * videoDuration, preferredTimescale: 600),
            duration: CMTime(seconds: (trimEnd - trimStart) * videoDuration, preferredTimescale: 600)
        )

        // If no changes at all, return original
        let isFullDuration = trimStart <= 0.001 && trimEnd >= 0.999
        if items.isEmpty && isFullDuration {
            completion(videoURL); return
        }

        exportTask = Task {
            isExporting = true; exportProgress = 0
            do {
                let url = try await VideoTextCompositor.export(
                    videoURL: videoURL,
                    textItems: items,
                    canvasFrame: canvasFrame,
                    videoSize: videoSize,
                    trimRange: trimRange,
                    progressHandler: { [weak self] p in
                        Task { @MainActor in self?.exportProgress = p }
                    }
                )
                isExporting = false; completion(url)
            } catch {
                isExporting = false
                exportErrorMessage = error.localizedDescription
                showExportError = true; completion(nil)
            }
        }
    }
}

// MARK: - Video compositor

enum VideoTextCompositor {

    static func export(
        videoURL: URL,
        textItems: [VideoTextItem],
        canvasFrame: CGRect,
        videoSize: CGSize,
        trimRange: CMTimeRange,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        
        try await Self.exportSync(
            videoURL: videoURL, textItems: textItems,
            canvasFrame: canvasFrame, videoSize: videoSize,
            trimRange: trimRange, progressHandler: progressHandler
        )
//        return try await Task.detached(priority: .userInitiated) {
//            try Self.exportSync(
//                videoURL: videoURL, textItems: textItems,
//                canvasFrame: canvasFrame, videoSize: videoSize,
//                trimRange: trimRange, progressHandler: progressHandler
//            )
//        }.value
    }

    private static func exportSync(
        videoURL: URL,
        textItems: [VideoTextItem],
        canvasFrame: CGRect,
        videoSize: CGSize,
        trimRange: CMTimeRange,
        progressHandler: (Double) -> Void
    ) async throws -> URL {

        let asset = AVURLAsset(url: videoURL)

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw CompositorError.noVideoTrack
        }

        let naturalSize = videoTrack.naturalSize
        let transform   = videoTrack.preferredTransform
        let nominalFR   = videoTrack.nominalFrameRate
        let outputSize  = videoSize

        // ── Reader (trimmed time range) ────────────────────────────────────────

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = trimRange   // <-- this is what trims the video

        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let ao = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            ao.alwaysCopiesSampleData = false
            reader.add(ao); audioOutput = ao
        }

        guard reader.startReading() else {
            throw reader.error ?? CompositorError.readerFailed
        }

        // ── Writer ─────────────────────────────────────────────────────────────

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("video_text_\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(outputSize.width),
                AVVideoHeightKey: Int(outputSize.height)
            ]
        )
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = .identity

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(outputSize.width),
                kCVPixelBufferHeightKey as String: Int(outputSize.height)
            ]
        )
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            ai.expectsMediaDataInRealTime = false
            writer.add(ai); audioInput = ai
        }

        guard writer.startWriting() else {
            throw writer.error ?? CompositorError.writerFailed
        }
        // Start the writer session at zero — we re-stamp each frame's
        // presentation time relative to the trim start so the output
        // always starts at t=0 regardless of where in the source we trimmed.
        writer.startSession(atSourceTime: .zero)

        // ── Pre-build draw items ───────────────────────────────────────────────

        let scaleX = canvasFrame.width  > 0 ? outputSize.width  / canvasFrame.width  : 1
        let scaleY = canvasFrame.height > 0 ? outputSize.height / canvasFrame.height : 1
        let avgScale = (scaleX + scaleY) / 2

        struct DrawItem {
            let text: NSAttributedString
            let center: CGPoint
        }

        let drawItems: [DrawItem] = textItems.compactMap { item in
            guard !item.text.isEmpty else { return nil }
            let fontSize = item.fontSize * avgScale
            return DrawItem(
                text: NSAttributedString(string: item.text, attributes: [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: UIColor(item.color)
                ]),
                center: CGPoint(x: item.position.x * scaleX,
                                y: item.position.y * scaleY)
            )
        }

        // ── Frame loop ─────────────────────────────────────────────────────────

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var poolRef: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey  as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height)
        ] as CFDictionary, &poolRef)

        let trimStartSeconds = CMTimeGetSeconds(trimRange.start)
        let trimDuration     = CMTimeGetSeconds(trimRange.duration)
        let totalFrames      = max(1, Int(trimDuration * Double(nominalFR)))
        var frameCount       = 0

        while reader.status == .reading {
            guard let sample = videoOutput.copyNextSampleBuffer() else { break }

            guard let srcBuf = CMSampleBufferGetImageBuffer(sample) else {
                CMSampleBufferInvalidate(sample); continue
            }

            // Re-stamp PTS relative to trim start so output starts at t=0
            let originalPTS = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            let newPTS      = CMTime(seconds: originalPTS - trimStartSeconds,
                                     preferredTimescale: 600)
            CMSampleBufferInvalidate(sample)

            CVPixelBufferLockBaseAddress(srcBuf, .readOnly)
            let srcW = CVPixelBufferGetWidth(srcBuf)
            let srcH = CVPixelBufferGetHeight(srcBuf)

            var dstBuf: CVPixelBuffer?
            if let pool = poolRef { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstBuf) }
            else { CVPixelBufferCreate(nil, Int(outputSize.width), Int(outputSize.height),
                                       kCVPixelFormatType_32BGRA, nil, &dstBuf) }

            guard let dst = dstBuf else {
                CVPixelBufferUnlockBaseAddress(srcBuf, .readOnly); continue
            }
            CVPixelBufferLockBaseAddress(dst, [])

            if let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(dst),
                width: Int(outputSize.width), height: Int(outputSize.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(dst),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                           | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                // Draw video frame
                ctx.saveGState()
                ctx.concatenate(transform)
                if let img = makeImage(from: srcBuf, width: srcW, height: srcH, colorSpace: colorSpace) {
                    ctx.draw(img, in: CGRect(x: 0, y: 0, width: CGFloat(srcW), height: CGFloat(srcH)))
                }
                ctx.restoreGState()

                // Draw text
                if !drawItems.isEmpty {
                    ctx.saveGState()
                    ctx.translateBy(x: 0, y: outputSize.height)
                    ctx.scaleBy(x: 1, y: -1)
                    for di in drawItems {
                        let sz = di.text.size()
                        UIGraphicsPushContext(ctx)
                        di.text.draw(at: CGPoint(x: di.center.x - sz.width  / 2,
                                                  y: di.center.y - sz.height / 2))
                        UIGraphicsPopContext()
                    }
                    ctx.restoreGState()
                }
            }

            CVPixelBufferUnlockBaseAddress(srcBuf, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])

            while !videoInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            adaptor.append(dst, withPresentationTime: newPTS)

            frameCount += 1
            progressHandler(min(Double(frameCount) / Double(totalFrames) * 0.9, 0.9))
        }

        // ── Audio (re-stamped to match trim) ───────────────────────────────────

        if let ao = audioOutput, let ai = audioInput {
            while reader.status == .reading {
                guard let sample = ao.copyNextSampleBuffer() else { break }
                while !ai.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                // Re-stamp audio PTS relative to trim start
                if let reStamped = restamp(sample, offsetSeconds: -trimStartSeconds) {
                    ai.append(reStamped)
                } else {
                    ai.append(sample)
                }
                CMSampleBufferInvalidate(sample)
            }
            ai.markAsFinished()
        }

        videoInput.markAsFinished()

        await writer.finishWriting()
        progressHandler(1.0)

        if writer.status == .failed { throw writer.error ?? CompositorError.writerFailed }
        return outputURL
    }

    // MARK: Helpers

    private static func makeImage(
        from buffer: CVPixelBuffer, width: Int, height: Int, colorSpace: CGColorSpace
    ) -> CGImage? {
        guard let provider = CGDataProvider(
            dataInfo: nil,
            data: CVPixelBufferGetBaseAddress(buffer)!,
            size: CVPixelBufferGetBytesPerRow(buffer) * height,
            releaseData: { _, _, _ in }
        ) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue:
                CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Shifts a CMSampleBuffer's PTS/DTS by `offsetSeconds`.
    private static func restamp(_ sample: CMSampleBuffer, offsetSeconds: Double) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(sample, at: 0, timingInfoOut: &timingInfo) == noErr
        else { return nil }
        let offset = CMTime(seconds: offsetSeconds, preferredTimescale: 600)
        timingInfo.presentationTimeStamp = CMTimeAdd(timingInfo.presentationTimeStamp, offset)
        if CMTIME_IS_VALID(timingInfo.decodeTimeStamp) {
            timingInfo.decodeTimeStamp = CMTimeAdd(timingInfo.decodeTimeStamp, offset)
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleBufferOut: &out)
        return out
    }

    enum CompositorError: LocalizedError {
        case noVideoTrack, readerFailed, writerFailed
        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "The video file has no video track."
            case .readerFailed: return "Could not read video frames."
            case .writerFailed: return "Could not write output video."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VideoTextEditorPreviewHost()
}

struct VideoTextEditorPreviewHost: View {
    
    @State var resultUrl: URL?
    var body: some View {
        // Point this at any .mp4/.mov in your bundle for previewing.
        
        if let resultUrl {
            VideoPlayer(player: AVPlayer(url: resultUrl))
                .ignoresSafeArea()
        }
        else if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
            VideoTextEditorView(videoURL: url) { result in
                print("Exported to:", result?.path ?? "nil")
                resultUrl = result
            }
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                Text("Add a sample.mp4 to your bundle to preview")
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}
