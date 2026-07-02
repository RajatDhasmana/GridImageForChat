
import SwiftUI
import AVFoundation
import AVKit

// MARK: - Video Text Item
//
// Mirrors the TextItem struct from ImageTextEditorView. If both files are in
// the same target, rename one (e.g. VideoTextItem) or extract a shared
// TextItem into its own file and delete the duplicate here.

struct VideoTextItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var position: CGPoint   // canvas-local points (relative to the fitted preview frame)
    var fontSize: CGFloat
    var color: Color

    init(id: UUID = UUID(), text: String = "", position: CGPoint,
         fontSize: CGFloat = 32, color: Color = .white) {
        self.id = id
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.color = color
    }
}

// MARK: - Public View

struct VideoTextEditorView: View {

    let videoURL: URL
    /// Called with the URL of the exported video (written to a temp file),
    /// or nil if the user cancelled or export failed.
    let onComplete: (URL?) -> Void

    var onCancel: (() -> Void)? = nil

    @StateObject private var model: VideoTextEditorModel

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

                    // Canvas: thumbnail + text overlays + vertical color bar
                    GeometryReader { canvasGeo in
                        let fitted = model.fittedFrame(in: canvasGeo.size)

                        ZStack {
                            thumbnailLayer(fitted: fitted)

                            // Text overlays
                            ForEach(model.textItems) { item in
                                VideoTextItemView(model: model, item: item, canvasFrame: fitted)
                            }

                            // Vertical hue bar, right edge, visible only when an item is selected
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

                    bottomControls
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }
            }
        }
        // Export progress overlay
        .overlay {
            if model.isExporting {
                exportingOverlay
            }
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

            // Play button badge in the centre of the thumbnail
            Image(systemName: "play.circle.fill")
                .font(.system(size: 60))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.45))
                .position(x: fitted.midX, y: fitted.midY)
                .allowsHitTesting(false)

        } else {
            // Thumbnail still loading
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: fitted.width, height: fitted.height)
                ProgressView()
                    .tint(.white)
            }
            .position(x: fitted.midX, y: fitted.midY)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                onCancel?()
            } label: {
                Text("Cancel")
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                model.exportVideo { url in
                    onComplete(url)
                }
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .disabled(model.isExporting)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        HStack(spacing: 28) {
            Button {
                model.addText()
            } label: {
                Label("Add Text", systemImage: "textformat")
                    .foregroundStyle(.white)
                    .font(.callout.weight(.medium))
            }

            if model.selectedID != nil {
                Button {
                    model.isEditingText = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .foregroundStyle(.white)
                        .font(.callout.weight(.medium))
                }

                Button(role: .destructive) {
                    model.removeSelectedText()
                } label: {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.white)
                        .font(.callout.weight(.medium))
                }
            }
        }
    }

    // MARK: Export progress overlay

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: model.exportProgress)
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Exporting…")
                    .foregroundStyle(.white)
                    .font(.callout.weight(.medium))
                Text("\(Int(model.exportProgress * 100))%")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }
        }
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
                    .fill(LinearGradient(colors: hueColors,
                                         startPoint: .top,
                                         endPoint: .bottom))

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
        let hue = min(max(y, 0), height) / height
        selectedColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
    }
}

// MARK: - Hidden keyboard input bridge (same pattern as image editor)

private struct VideoHiddenTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> UITextField {
        let f = UITextField()
        f.delegate = context.coordinator
        f.returnKeyType = .done
        f.isHidden = true
        return f
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Guard against UIKit↔SwiftUI feedback loop (AttributeGraph cycle).
        if uiView.text != text { uiView.text = text }
        if isActive, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        else if !isActive, uiView.isFirstResponder { uiView.resignFirstResponder() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: VideoHiddenTextInput
        init(_ parent: VideoHiddenTextInput) { self.parent = parent }
        func textFieldDidChangeSelection(_ tf: UITextField) { parent.text = tf.text ?? "" }
        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.isActive = false; return true }
    }
}

// MARK: - Model

@MainActor
final class VideoTextEditorModel: ObservableObject {

    let videoURL: URL

    @Published var thumbnail: UIImage?
    @Published var textItems: [VideoTextItem] = []
    @Published var selectedID: UUID?
    @Published var isEditingText = false
    @Published var isDragging = false
    @Published var isZooming = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var showExportError = false
    @Published var exportErrorMessage = ""

    private(set) var canvasFrame: CGRect = .zero
    private var videoSize: CGSize = .zero   // post-transform display size (what the user sees)

    private var dragStartPos: CGPoint = .zero
    private var fontSizeAtZoomStart: CGFloat = 32
    private var activeGestureID: UUID?

    private let minFontSize: CGFloat = 12
    private let maxFontSize: CGFloat = 160

    private var exportTask: Task<Void, Never>?

    init(videoURL: URL) {
        self.videoURL = videoURL
        Task { await loadThumbnailAndVideoSize() }
    }

    // MARK: Thumbnail + video size

    private func loadThumbnailAndVideoSize() async {
        let asset = AVURLAsset(url: videoURL)

        // Get natural video size from the first video track
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let size = (try? await track.load(.naturalSize)) ?? .zero
            let transform = (try? await track.load(.preferredTransform)) ?? .identity
            // Apply transform to get the display (rotated) size
            let transformed = size.applying(transform)
            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        // Generate thumbnail at 0.0 s
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let time = CMTime(seconds: 0, preferredTimescale: 600)
        if let cgImage = try? await generator.image(at: time).image {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }

    // MARK: Canvas layout (aspect-fit, same as image editor)

    func fittedFrame(in containerSize: CGSize) -> CGRect {
        let srcSize = videoSize.width > 0 ? videoSize : CGSize(width: 16, height: 9)
        guard containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let aspect = srcSize.width / srcSize.height
        let containerAspect = containerSize.width / containerSize.height
        var size = containerSize
        if aspect > containerAspect {
            size.height = containerSize.width / aspect
        } else {
            size.width = containerSize.height * aspect
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                              y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    func setupCanvas(in frame: CGRect) {
        canvasFrame = frame
    }

    func rescaleCanvas(to newFrame: CGRect) {
        let old = canvasFrame
        guard old.width > 0, old.height > 0 else { canvasFrame = newFrame; return }
        let sx = newFrame.width / old.width
        let sy = newFrame.height / old.height
        for i in textItems.indices {
            textItems[i].position.x *= sx
            textItems[i].position.y *= sy
            textItems[i].fontSize *= (sx + sy) / 2
        }
        canvasFrame = newFrame
    }

    // MARK: Bindings for selected item

    var selectedTextBinding: Binding<String> {
        Binding(
            get: { [weak self] in
                guard let self, let id = selectedID,
                      let item = textItems.first(where: { $0.id == id }) else { return "" }
                return item.text
            },
            set: { [weak self] val in
                guard let self, let id = selectedID else { return }
                updateItem(id) { $0.text = val }
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
                updateItem(id) { $0.color = val }
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
        textItems.append(item)
        selectedID = item.id
        isEditingText = true
    }

    func select(_ id: UUID) {
        guard selectedID != id else { return }
        selectedID = id
    }

    func removeSelectedText() {
        guard let id = selectedID else { return }
        textItems.removeAll { $0.id == id }
        selectedID = nil
        isEditingText = false
    }

    // MARK: Drag

    func beginDrag(for id: UUID) {
        activeGestureID = id
        dragStartPos = textItems.first(where: { $0.id == id })?.position ?? .zero
        isDragging = true
    }

    func drag(translation: CGSize, bounds: CGRect) {
        guard let id = activeGestureID else { return }
        let proposed = CGPoint(x: dragStartPos.x + translation.width,
                                y: dragStartPos.y + translation.height)
        let clamped = CGPoint(x: min(max(proposed.x, bounds.minX), bounds.maxX),
                               y: min(max(proposed.y, bounds.minY), bounds.maxY))
        updateItem(id) { $0.position = clamped }
    }

    func endDrag() {
        isDragging = false
        activeGestureID = nil
    }

    // MARK: Zoom

    func beginZoom(for id: UUID) {
        activeGestureID = id
        fontSizeAtZoomStart = textItems.first(where: { $0.id == id })?.fontSize ?? 32
        isZooming = true
    }

    func zoom(scale: CGFloat) {
        guard let id = activeGestureID else { return }
        let clamped = min(max(fontSizeAtZoomStart * scale, minFontSize), maxFontSize)
        updateItem(id) { $0.fontSize = clamped }
    }

    func endZoom() {
        isZooming = false
        activeGestureID = nil
    }

    // MARK: Export

    /// Burns all text items into every frame of the video using
    /// AVVideoCompositionCoreAnimationTool and exports to a temp .mov file.
    func exportVideo(completion: @escaping (URL?) -> Void) {
        let items = textItems.filter { !$0.text.isEmpty }
        guard !items.isEmpty else {
            // Nothing to burn in — hand back the original URL unchanged.
            completion(videoURL)
            return
        }

        exportTask = Task {
            isExporting = true
            exportProgress = 0

            do {
                let url = try await VideoTextCompositor.export(
                    videoURL: videoURL,
                    textItems: items,
                    canvasFrame: canvasFrame,
                    videoSize: videoSize,
                    progressHandler: { [weak self] p in
                        Task { @MainActor in self?.exportProgress = p }
                    }
                )
                isExporting = false
                completion(url)
            } catch {
                isExporting = false
                exportErrorMessage = error.localizedDescription
                showExportError = true
                completion(nil)
            }
        }
    }
}

// MARK: - Video compositor (frame-by-frame AVAssetReader + AVAssetWriter)
//
// Instead of AVVideoCompositionCoreAnimationTool (which crashes on rotated
// videos due to renderSize / CA coordinate system mismatches), we read every
// decoded video frame as a CVPixelBuffer, draw it into a CGContext, draw the
// text on top with Core Graphics, then write the composited pixel buffer to a
// new file with AVAssetWriter. Audio is copied untouched via a separate
// AVAssetReaderTrackOutput. This approach is rotation-safe and crash-free.

enum VideoTextCompositor {

    static func export(
        videoURL: URL,
        textItems: [VideoTextItem],
        canvasFrame: CGRect,     // on-screen display rect of the video (SwiftUI points)
        videoSize: CGSize,       // display size (post-transform, what the user sees)
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        
        try await Self.exportSync(
            videoURL: videoURL,
            textItems: textItems,
            canvasFrame: canvasFrame,
            videoSize: videoSize,
            progressHandler: progressHandler
        )

        // Run the entire pipeline off the main thread.
//        return try await Task.detached(priority: .userInitiated) {
//            try Self.exportSync(
//                videoURL: videoURL,
//                textItems: textItems,
//                canvasFrame: canvasFrame,
//                videoSize: videoSize,
//                progressHandler: progressHandler
//            )
//        }.value
    }

    // MARK: Synchronous pipeline (runs on a background thread via Task.detached)

    private static func exportSync(
        videoURL: URL,
        textItems: [VideoTextItem],
        canvasFrame: CGRect,
        videoSize: CGSize,
        progressHandler: (Double) -> Void
    ) async throws -> URL {

        let asset = AVURLAsset(url: videoURL)

        // ── 1. Probe the video track synchronously ─────────────────────────────

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw CompositorError.noVideoTrack
        }

        let naturalSize  = videoTrack.naturalSize                // pre-rotation, e.g. 1920×1080
        let transform    = videoTrack.preferredTransform         // rotation metadata
        let nominalFR    = videoTrack.nominalFrameRate
        let duration     = asset.duration

        // The display size is the post-rotation size (what the thumbnail shows).
        // We use it to map canvas-point positions → display-pixel → output-pixel.
        let outputSize   = videoSize   // e.g. 1080×1920 for a portrait recording

        // ── 2. Set up AVAssetReader ────────────────────────────────────────────

        let reader = try AVAssetReader(asset: asset)

        // Decode video frames into kCVPixelFormatType_32BGRA so we can wrap
        // them in a CGContext directly without any pixel-format conversion.
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        // Audio: copy the compressed samples verbatim (nil outputSettings = passthrough).
        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let ao = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            ao.alwaysCopiesSampleData = false
            reader.add(ao)
            audioOutput = ao
        }

        guard reader.startReading() else {
            throw reader.error ?? CompositorError.readerFailed
        }

        // ── 3. Set up AVAssetWriter ────────────────────────────────────────────

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("video_text_\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // Output video settings: H.264, same display size as the source.
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey:  Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height)
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        // Carry over the source transform so players rotate the output correctly.
        // Since our CGContext already draws in display (post-rotation) coordinates,
        // we clear the transform on the writer input — the output pixels are already
        // in the right orientation.
        videoInput.transform = .identity

        // PixelBufferAdaptor: bridges CGContext output → AVAssetWriterInput.
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(outputSize.width),
                kCVPixelBufferHeightKey as String: Int(outputSize.height)
            ]
        )
        writer.add(videoInput)

        // Audio passthrough input (no re-encoding).
        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            ai.expectsMediaDataInRealTime = false
            writer.add(ai)
            audioInput = ai
        }

        guard writer.startWriting() else {
            throw writer.error ?? CompositorError.writerFailed
        }
        writer.startSession(atSourceTime: .zero)

        // ── 4. Pre-build text attributes (scaled to output pixel space) ────────

        // Scale from canvas display-points → output pixels.
        let scaleX = canvasFrame.width  > 0 ? outputSize.width  / canvasFrame.width  : 1
        let scaleY = canvasFrame.height > 0 ? outputSize.height / canvasFrame.height : 1
        let avgScale = (scaleX + scaleY) / 2

        struct DrawItem {
            let text: NSAttributedString
            let center: CGPoint      // in output-pixel space (top-left origin)
        }

        let drawItems: [DrawItem] = textItems.compactMap { item in
            guard !item.text.isEmpty else { return nil }
            let fontSize = item.fontSize * avgScale
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor(item.color)
            ]
            let cx = item.position.x * scaleX
            let cy = item.position.y * scaleY
            return DrawItem(
                text: NSAttributedString(string: item.text, attributes: attrs),
                center: CGPoint(x: cx, y: cy)
            )
        }

        // ── 5. Frame-by-frame compositing ─────────────────────────────────────
        //
        // For each decoded video frame:
        //   a. Apply preferredTransform in a CGContext to rotate/flip the raw
        //      (natural-orientation) pixel data into display orientation.
        //   b. Draw text on top in display-coordinate space.
        //   c. Extract the composited CGContext as a CVPixelBuffer.
        //   d. Append to the writer via the adaptor.

        let durationSeconds = CMTimeGetSeconds(duration)

        // Reusable pixel buffer pool to avoid per-frame allocation.
        var pixelBufferPool: CVPixelBufferPool?
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey  as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height)
        ]
        CVPixelBufferPoolCreate(nil, nil, poolAttrs as CFDictionary, &pixelBufferPool)

        var frameCount = 0
        let totalFrames = max(1, Int(durationSeconds * Double(nominalFR)))

        while reader.status == .reading {
            guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else { break }

            guard let srcPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                CMSampleBufferInvalidate(sampleBuffer)
                continue
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // a. Lock the source pixel buffer for reading.
            CVPixelBufferLockBaseAddress(srcPixelBuffer, .readOnly)

            let srcWidth  = CVPixelBufferGetWidth(srcPixelBuffer)
            let srcHeight = CVPixelBufferGetHeight(srcPixelBuffer)

            // b. Create an output-sized pixel buffer from the pool.
            var dstPixelBuffer: CVPixelBuffer?
            if let pool = pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstPixelBuffer)
            } else {
                CVPixelBufferCreate(
                    nil,
                    Int(outputSize.width), Int(outputSize.height),
                    kCVPixelFormatType_32BGRA, nil,
                    &dstPixelBuffer
                )
            }

            guard let dst = dstPixelBuffer else {
                CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
                CMSampleBufferInvalidate(sampleBuffer)
                continue
            }

            CVPixelBufferLockBaseAddress(dst, [])

            // c. Create a CGContext backed by the destination pixel buffer.
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(dst),
                width:  Int(outputSize.width),
                height: Int(outputSize.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(dst),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                           | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                CVPixelBufferUnlockBaseAddress(dst, [])
                CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
                CMSampleBufferInvalidate(sampleBuffer)
                continue
            }

            // d. Draw the source frame into the output context.
            //
            //    CGContext has a bottom-left origin (Y increases upward).
            //    AVFoundation's preferredTransform is designed for that same
            //    coordinate system — it rotates + translates the natural frame
            //    so it lands correctly in CG space without any extra flipping.
            //    We just apply it directly.

            ctx.saveGState()
            ctx.concatenate(transform)
            ctx.draw(
                makeImage(from: srcPixelBuffer,
                          width: srcWidth, height: srcHeight,
                          colorSpace: colorSpace)!,
                in: CGRect(x: 0, y: 0,
                           width: CGFloat(srcWidth),
                           height: CGFloat(srcHeight))
            )
            ctx.restoreGState()

            // e. Draw text on top.
            //
            //    NSAttributedString.draw() is a UIKit API that uses a
            //    top-left origin (Y increases downward). Our CGContext has
            //    bottom-left origin, so we flip Y and translate to match.
            //    Text positions (drawItem.center) come from the SwiftUI canvas
            //    which also uses top-left origin, so after the flip they map
            //    directly into the correct location.
            ctx.saveGState()
            ctx.translateBy(x: 0, y: outputSize.height)
            ctx.scaleBy(x: 1, y: -1)

            for drawItem in drawItems {
                let textSize = drawItem.text.size()
                let origin = CGPoint(
                    x: drawItem.center.x - textSize.width  / 2,
                    y: drawItem.center.y - textSize.height / 2
                )
                UIGraphicsPushContext(ctx)
                drawItem.text.draw(at: origin)
                UIGraphicsPopContext()
            }

            ctx.restoreGState()

            CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
            CMSampleBufferInvalidate(sampleBuffer)

            CVPixelBufferUnlockBaseAddress(dst, [])

            // f. Wait until the writer input is ready, then append the frame.
            while !videoInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            adaptor.append(dst, withPresentationTime: presentationTime)

            frameCount += 1
            progressHandler(min(Double(frameCount) / Double(totalFrames) * 0.9, 0.9))
        }

        // ── 6. Copy audio samples ──────────────────────────────────────────────

        if let ao = audioOutput, let ai = audioInput {
            while reader.status == .reading {
                guard let sample = ao.copyNextSampleBuffer() else { break }
                while !ai.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.005)
                }
                ai.append(sample)
                CMSampleBufferInvalidate(sample)
            }
            ai.markAsFinished()
        }

        videoInput.markAsFinished()

        // ── 7. Finish writing ──────────────────────────────────────────────────

        await writer.finishWriting()
        progressHandler(1.0)

        if writer.status == .failed {
            throw writer.error ?? CompositorError.writerFailed
        }

        return outputURL
    }

    // MARK: Helpers

    /// Wraps a locked CVPixelBuffer's bytes in a CGImage without copying.
    private static func makeImage(
        from buffer: CVPixelBuffer,
        width: Int, height: Int,
        colorSpace: CGColorSpace
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
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: Errors

    enum CompositorError: LocalizedError {
        case noVideoTrack
        case readerFailed
        case writerFailed

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:  return "The video file has no video track."
            case .readerFailed:  return "Could not read video frames."
            case .writerFailed:  return "Could not write output video."
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
