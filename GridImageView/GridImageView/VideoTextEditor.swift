////////
////////  VideoTextEditor.swift
////////  GridImageView
////////
////////  Created by Rajat Dhasmana on 02/07/26.
////////
//////
//////import Foundation
////////
////////  VideoTextEditorView.swift
////////
////////  A SwiftUI view that takes a video URL, displays a thumbnail with a play
////////  indicator, lets the user add multiple draggable/zoomable/colorable text
////////  overlays, and on Done exports a new video with every text item burned
////////  into every frame using AVFoundation's Core Animation compositor.
////////
////////  Usage:
////////
////////      VideoTextEditorView(videoURL: url) { resultURL in
////////          // resultURL: URL?  (nil on failure or cancel)
////////      }
////////
////////  Requirements: SwiftUI, AVFoundation, CoreImage (all system frameworks).
////////  Info.plist: no special keys required for local file URLs.
////////
//////
//////import SwiftUI
//////import AVFoundation
//////
//////// MARK: - Video Text Item
////////
//////// Mirrors the TextItem struct from ImageTextEditorView. If both files are in
//////// the same target, rename one (e.g. VideoTextItem) or extract a shared
//////// TextItem into its own file and delete the duplicate here.
//////
//////struct VideoTextItem: Identifiable, Equatable {
//////    let id: UUID
//////    var text: String
//////    var position: CGPoint   // canvas-local points (relative to the fitted preview frame)
//////    var fontSize: CGFloat
//////    var color: Color
//////
//////    init(id: UUID = UUID(), text: String = "", position: CGPoint,
//////         fontSize: CGFloat = 32, color: Color = .white) {
//////        self.id = id
//////        self.text = text
//////        self.position = position
//////        self.fontSize = fontSize
//////        self.color = color
//////    }
//////}
//////
//////// MARK: - Public View
//////
//////struct VideoTextEditorView: View {
//////
//////    let videoURL: URL
//////    /// Called with the URL of the exported video (written to a temp file),
//////    /// or nil if the user cancelled or export failed.
//////    let onComplete: (URL?) -> Void
//////
//////    var onCancel: (() -> Void)? = nil
//////
//////    @StateObject private var model: VideoTextEditorModel
//////
//////    init(videoURL: URL, onCancel: (() -> Void)? = nil, onComplete: @escaping (URL?) -> Void) {
//////        self.videoURL = videoURL
//////        self.onCancel = onCancel
//////        self.onComplete = onComplete
//////        _model = StateObject(wrappedValue: VideoTextEditorModel(videoURL: videoURL))
//////    }
//////
//////    var body: some View {
//////        GeometryReader { geo in
//////            ZStack {
//////                Color.black.ignoresSafeArea()
//////
//////                VStack(spacing: 0) {
//////                    topBar
//////                        .padding(.top, max(geo.safeAreaInsets.top, 12))
//////
//////                    Spacer(minLength: 0)
//////
//////                    // Canvas: thumbnail + text overlays + vertical color bar
//////                    GeometryReader { canvasGeo in
//////                        let fitted = model.fittedFrame(in: canvasGeo.size)
//////
//////                        ZStack {
//////                            thumbnailLayer(fitted: fitted)
//////
//////                            // Text overlays
//////                            ForEach(model.textItems) { item in
//////                                VideoTextItemView(model: model, item: item, canvasFrame: fitted)
//////                            }
//////
//////                            // Vertical hue bar, right edge, visible only when an item is selected
//////                            if model.selectedID != nil {
//////                                HStack {
//////                                    Spacer()
//////                                    VideoVerticalHueColorBar(selectedColor: model.selectedColorBinding)
//////                                        .frame(width: 36,
//////                                               height: min(canvasGeo.size.height * 0.7, 260))
//////                                        .padding(.trailing, 8)
//////                                }
//////                            }
//////                        }
//////                        .onAppear { model.setupCanvas(in: fitted) }
//////                        .onChange(of: canvasGeo.size) { _, newSize in
//////                            model.rescaleCanvas(to: model.fittedFrame(in: newSize))
//////                        }
//////                    }
//////                    .padding(.horizontal, 12)
//////
//////                    Spacer(minLength: 0)
//////
//////                    bottomControls
//////                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
//////                }
//////            }
//////        }
//////        // Export progress overlay
//////        .overlay {
//////            if model.isExporting {
//////                exportingOverlay
//////            }
//////        }
//////        .background(
//////            VideoHiddenTextInput(text: model.selectedTextBinding,
//////                                 isActive: $model.isEditingText)
//////        )
//////        .ignoresSafeArea(.keyboard, edges: .bottom)
//////        .alert("Export Failed", isPresented: $model.showExportError) {
//////            Button("OK", role: .cancel) {}
//////        } message: {
//////            Text(model.exportErrorMessage)
//////        }
//////    }
//////
//////    // MARK: Thumbnail layer
//////
//////    @ViewBuilder
//////    private func thumbnailLayer(fitted: CGRect) -> some View {
//////        if let thumb = model.thumbnail {
//////            Image(uiImage: thumb)
//////                .resizable()
//////                .frame(width: fitted.width, height: fitted.height)
//////                .position(x: fitted.midX, y: fitted.midY)
//////                .onTapGesture {
//////                    model.isEditingText = false
//////                    model.selectedID = nil
//////                }
//////
//////            // Play button badge in the centre of the thumbnail
//////            Image(systemName: "play.circle.fill")
//////                .font(.system(size: 60))
//////                .symbolRenderingMode(.palette)
//////                .foregroundStyle(.white, .black.opacity(0.45))
//////                .position(x: fitted.midX, y: fitted.midY)
//////                .allowsHitTesting(false)
//////
//////        } else {
//////            // Thumbnail still loading
//////            ZStack {
//////                RoundedRectangle(cornerRadius: 8)
//////                    .fill(Color.white.opacity(0.08))
//////                    .frame(width: fitted.width, height: fitted.height)
//////                ProgressView()
//////                    .tint(.white)
//////            }
//////            .position(x: fitted.midX, y: fitted.midY)
//////        }
//////    }
//////
//////    // MARK: Top bar
//////
//////    private var topBar: some View {
//////        HStack {
//////            Button {
//////                onCancel?()
//////            } label: {
//////                Text("Cancel")
//////                    .foregroundStyle(.white)
//////            }
//////
//////            Spacer()
//////
//////            Button {
//////                model.exportVideo { url in
//////                    onComplete(url)
//////                }
//////            } label: {
//////                Text("Done")
//////                    .fontWeight(.semibold)
//////                    .foregroundStyle(.black)
//////                    .padding(.horizontal, 18)
//////                    .padding(.vertical, 8)
//////                    .background(Color.white, in: Capsule())
//////            }
//////            .disabled(model.isExporting)
//////        }
//////        .padding(.horizontal, 20)
//////    }
//////
//////    // MARK: Bottom controls
//////
//////    private var bottomControls: some View {
//////        HStack(spacing: 28) {
//////            Button {
//////                model.addText()
//////            } label: {
//////                Label("Add Text", systemImage: "textformat")
//////                    .foregroundStyle(.white)
//////                    .font(.callout.weight(.medium))
//////            }
//////
//////            if model.selectedID != nil {
//////                Button {
//////                    model.isEditingText = true
//////                } label: {
//////                    Label("Edit", systemImage: "pencil")
//////                        .foregroundStyle(.white)
//////                        .font(.callout.weight(.medium))
//////                }
//////
//////                Button(role: .destructive) {
//////                    model.removeSelectedText()
//////                } label: {
//////                    Label("Remove", systemImage: "trash")
//////                        .foregroundStyle(.white)
//////                        .font(.callout.weight(.medium))
//////                }
//////            }
//////        }
//////    }
//////
//////    // MARK: Export progress overlay
//////
//////    private var exportingOverlay: some View {
//////        ZStack {
//////            Color.black.opacity(0.6).ignoresSafeArea()
//////            VStack(spacing: 16) {
//////                ProgressView(value: model.exportProgress)
//////                    .progressViewStyle(.circular)
//////                    .tint(.white)
//////                    .scaleEffect(1.4)
//////                Text("Exporting…")
//////                    .foregroundStyle(.white)
//////                    .font(.callout.weight(.medium))
//////                Text("\(Int(model.exportProgress * 100))%")
//////                    .foregroundStyle(.white.opacity(0.7))
//////                    .font(.caption)
//////            }
//////        }
//////    }
//////}
//////
//////// MARK: - Draggable / zoomable text item view
//////
//////private struct VideoTextItemView: View {
//////    @ObservedObject var model: VideoTextEditorModel
//////    let item: VideoTextItem
//////    let canvasFrame: CGRect
//////
//////    private var isSelected: Bool { model.selectedID == item.id }
//////
//////    var body: some View {
//////        Text(item.text.isEmpty ? "Tap to edit" : item.text)
//////            .font(.system(size: item.fontSize, weight: .bold))
//////            .foregroundStyle(item.color)
//////            .padding(.horizontal, 10)
//////            .padding(.vertical, 6)
//////            .background(
//////                RoundedRectangle(cornerRadius: 6)
//////                    .fill(Color.black.opacity(isSelected ? 0.18 : 0))
//////            )
//////            .overlay(
//////                RoundedRectangle(cornerRadius: 6)
//////                    .strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
//////            )
//////            .position(item.position)
//////            .gesture(dragGesture.simultaneously(with: zoomGesture))
//////            .onTapGesture { model.select(item.id) }
//////            .frame(width: canvasFrame.width, height: canvasFrame.height, alignment: .topLeading)
//////            .allowsHitTesting(true)
//////    }
//////
//////    private var dragGesture: some Gesture {
//////        DragGesture(minimumDistance: 0)
//////            .onChanged { value in
//////                model.select(item.id)
//////                if !model.isDragging { model.beginDrag(for: item.id) }
//////                model.drag(translation: value.translation,
//////                           bounds: CGRect(origin: .zero, size: canvasFrame.size))
//////            }
//////            .onEnded { _ in model.endDrag() }
//////    }
//////
//////    private var zoomGesture: some Gesture {
//////        MagnificationGesture()
//////            .onChanged { scale in
//////                model.select(item.id)
//////                if !model.isZooming { model.beginZoom(for: item.id) }
//////                model.zoom(scale: scale)
//////            }
//////            .onEnded { _ in model.endZoom() }
//////    }
//////}
//////
//////// MARK: - Vertical hue color bar
//////
//////private struct VideoVerticalHueColorBar: View {
//////    @Binding var selectedColor: Color
//////
//////    var body: some View {
//////        GeometryReader { geo in
//////            ZStack(alignment: .top) {
//////                RoundedRectangle(cornerRadius: geo.size.width / 2)
//////                    .fill(LinearGradient(colors: hueColors,
//////                                         startPoint: .top,
//////                                         endPoint: .bottom))
//////
//////                Circle()
//////                    .fill(selectedColor)
//////                    .frame(width: geo.size.width + 6, height: geo.size.width + 6)
//////                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
//////                    .shadow(color: .black.opacity(0.3), radius: 2)
//////                    .position(x: geo.size.width / 2, y: handleY(in: geo.size))
//////            }
//////            .contentShape(Rectangle())
//////            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
//////                updateColor(atY: value.location.y, height: geo.size.height)
//////            })
//////        }
//////    }
//////
//////    private var hueColors: [Color] {
//////        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
//////            Color(hue: $0, saturation: 0.9, brightness: 1.0)
//////        }
//////    }
//////
//////    private func handleY(in size: CGSize) -> CGFloat {
//////        var hue: CGFloat = 0
//////        UIColor(selectedColor).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
//////        return hue * size.height
//////    }
//////
//////    private func updateColor(atY y: CGFloat, height: CGFloat) {
//////        guard height > 0 else { return }
//////        let hue = min(max(y, 0), height) / height
//////        selectedColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
//////    }
//////}
//////
//////// MARK: - Hidden keyboard input bridge (same pattern as image editor)
//////
//////private struct VideoHiddenTextInput: UIViewRepresentable {
//////    @Binding var text: String
//////    @Binding var isActive: Bool
//////
//////    func makeUIView(context: Context) -> UITextField {
//////        let f = UITextField()
//////        f.delegate = context.coordinator
//////        f.returnKeyType = .done
//////        f.isHidden = true
//////        return f
//////    }
//////
//////    func updateUIView(_ uiView: UITextField, context: Context) {
//////        // Guard against UIKit↔SwiftUI feedback loop (AttributeGraph cycle).
//////        if uiView.text != text { uiView.text = text }
//////        if isActive, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
//////        else if !isActive, uiView.isFirstResponder { uiView.resignFirstResponder() }
//////    }
//////
//////    func makeCoordinator() -> Coordinator { Coordinator(self) }
//////
//////    final class Coordinator: NSObject, UITextFieldDelegate {
//////        let parent: VideoHiddenTextInput
//////        init(_ parent: VideoHiddenTextInput) { self.parent = parent }
//////        func textFieldDidChangeSelection(_ tf: UITextField) { parent.text = tf.text ?? "" }
//////        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.isActive = false; return true }
//////    }
//////}
//////
//////// MARK: - Model
//////
//////@MainActor
//////final class VideoTextEditorModel: ObservableObject {
//////
//////    let videoURL: URL
//////
//////    @Published var thumbnail: UIImage?
//////    @Published var textItems: [VideoTextItem] = []
//////    @Published var selectedID: UUID?
//////    @Published var isEditingText = false
//////    @Published var isDragging = false
//////    @Published var isZooming = false
//////    @Published var isExporting = false
//////    @Published var exportProgress: Double = 0
//////    @Published var showExportError = false
//////    @Published var exportErrorMessage = ""
//////
//////    private(set) var canvasFrame: CGRect = .zero
//////    private var videoSize: CGSize = .zero  // native pixel dimensions of the video track
//////
//////    private var dragStartPos: CGPoint = .zero
//////    private var fontSizeAtZoomStart: CGFloat = 32
//////    private var activeGestureID: UUID?
//////
//////    private let minFontSize: CGFloat = 12
//////    private let maxFontSize: CGFloat = 160
//////
//////    private var exportTask: Task<Void, Never>?
//////
//////    init(videoURL: URL) {
//////        self.videoURL = videoURL
//////        Task { await loadThumbnailAndVideoSize() }
//////    }
//////
//////    // MARK: Thumbnail + video size
//////
//////    private func loadThumbnailAndVideoSize() async {
//////        let asset = AVURLAsset(url: videoURL)
//////
//////        // Get natural video size from the first video track
//////        if let track = try? await asset.loadTracks(withMediaType: .video).first {
//////            let size = (try? await track.load(.naturalSize)) ?? .zero
//////            let transform = (try? await track.load(.preferredTransform)) ?? .identity
//////            // Apply transform to get the display (rotated) size
//////            let transformed = size.applying(transform)
//////            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
//////        }
//////
//////        // Generate thumbnail at 0.0 s
//////        let generator = AVAssetImageGenerator(asset: asset)
//////        generator.appliesPreferredTrackTransform = true
//////        generator.maximumSize = CGSize(width: 1024, height: 1024)
//////
//////        let time = CMTime(seconds: 0, preferredTimescale: 600)
//////        if let cgImage = try? await generator.image(at: time).image {
//////            thumbnail = UIImage(cgImage: cgImage)
//////        }
//////    }
//////
//////    // MARK: Canvas layout (aspect-fit, same as image editor)
//////
//////    func fittedFrame(in containerSize: CGSize) -> CGRect {
//////        let srcSize = videoSize.width > 0 ? videoSize : CGSize(width: 16, height: 9)
//////        guard containerSize.width > 0, containerSize.height > 0 else {
//////            return CGRect(origin: .zero, size: containerSize)
//////        }
//////        let aspect = srcSize.width / srcSize.height
//////        let containerAspect = containerSize.width / containerSize.height
//////        var size = containerSize
//////        if aspect > containerAspect {
//////            size.height = containerSize.width / aspect
//////        } else {
//////            size.width = containerSize.height * aspect
//////        }
//////        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
//////                              y: (containerSize.height - size.height) / 2)
//////        return CGRect(origin: origin, size: size)
//////    }
//////
//////    func setupCanvas(in frame: CGRect) {
//////        canvasFrame = frame
//////    }
//////
//////    func rescaleCanvas(to newFrame: CGRect) {
//////        let old = canvasFrame
//////        guard old.width > 0, old.height > 0 else { canvasFrame = newFrame; return }
//////        let sx = newFrame.width / old.width
//////        let sy = newFrame.height / old.height
//////        for i in textItems.indices {
//////            textItems[i].position.x *= sx
//////            textItems[i].position.y *= sy
//////            textItems[i].fontSize *= (sx + sy) / 2
//////        }
//////        canvasFrame = newFrame
//////    }
//////
//////    // MARK: Bindings for selected item
//////
//////    var selectedTextBinding: Binding<String> {
//////        Binding(
//////            get: { [weak self] in
//////                guard let self, let id = selectedID,
//////                      let item = textItems.first(where: { $0.id == id }) else { return "" }
//////                return item.text
//////            },
//////            set: { [weak self] val in
//////                guard let self, let id = selectedID else { return }
//////                updateItem(id) { $0.text = val }
//////            }
//////        )
//////    }
//////
//////    var selectedColorBinding: Binding<Color> {
//////        Binding(
//////            get: { [weak self] in
//////                guard let self, let id = selectedID,
//////                      let item = textItems.first(where: { $0.id == id }) else { return .white }
//////                return item.color
//////            },
//////            set: { [weak self] val in
//////                guard let self, let id = selectedID else { return }
//////                updateItem(id) { $0.color = val }
//////            }
//////        )
//////    }
//////
//////    private func updateItem(_ id: UUID, _ mutate: (inout VideoTextItem) -> Void) {
//////        guard let i = textItems.firstIndex(where: { $0.id == id }) else { return }
//////        mutate(&textItems[i])
//////    }
//////
//////    // MARK: Text lifecycle
//////
//////    func addText() {
//////        let offset = CGFloat(textItems.count % 5) * 18
//////        let pos = CGPoint(x: canvasFrame.width / 2 + offset - 36,
//////                           y: canvasFrame.height / 2 + offset - 36)
//////        let item = VideoTextItem(text: "", position: pos)
//////        textItems.append(item)
//////        selectedID = item.id
//////        isEditingText = true
//////    }
//////
//////    func select(_ id: UUID) {
//////        guard selectedID != id else { return }
//////        selectedID = id
//////    }
//////
//////    func removeSelectedText() {
//////        guard let id = selectedID else { return }
//////        textItems.removeAll { $0.id == id }
//////        selectedID = nil
//////        isEditingText = false
//////    }
//////
//////    // MARK: Drag
//////
//////    func beginDrag(for id: UUID) {
//////        activeGestureID = id
//////        dragStartPos = textItems.first(where: { $0.id == id })?.position ?? .zero
//////        isDragging = true
//////    }
//////
//////    func drag(translation: CGSize, bounds: CGRect) {
//////        guard let id = activeGestureID else { return }
//////        let proposed = CGPoint(x: dragStartPos.x + translation.width,
//////                                y: dragStartPos.y + translation.height)
//////        let clamped = CGPoint(x: min(max(proposed.x, bounds.minX), bounds.maxX),
//////                               y: min(max(proposed.y, bounds.minY), bounds.maxY))
//////        updateItem(id) { $0.position = clamped }
//////    }
//////
//////    func endDrag() {
//////        isDragging = false
//////        activeGestureID = nil
//////    }
//////
//////    // MARK: Zoom
//////
//////    func beginZoom(for id: UUID) {
//////        activeGestureID = id
//////        fontSizeAtZoomStart = textItems.first(where: { $0.id == id })?.fontSize ?? 32
//////        isZooming = true
//////    }
//////
//////    func zoom(scale: CGFloat) {
//////        guard let id = activeGestureID else { return }
//////        let clamped = min(max(fontSizeAtZoomStart * scale, minFontSize), maxFontSize)
//////        updateItem(id) { $0.fontSize = clamped }
//////    }
//////
//////    func endZoom() {
//////        isZooming = false
//////        activeGestureID = nil
//////    }
//////
//////    // MARK: Export
//////
//////    /// Burns all text items into every frame of the video using
//////    /// AVVideoCompositionCoreAnimationTool and exports to a temp .mov file.
//////    func exportVideo(completion: @escaping (URL?) -> Void) {
//////        let items = textItems.filter { !$0.text.isEmpty }
//////        guard !items.isEmpty else {
//////            // Nothing to burn in — hand back the original URL unchanged.
//////            completion(videoURL)
//////            return
//////        }
//////
//////        exportTask = Task {
//////            isExporting = true
//////            exportProgress = 0
//////
//////            do {
//////                let url = try await VideoTextCompositor.export(
//////                    videoURL: videoURL,
//////                    textItems: items,
//////                    canvasFrame: canvasFrame,
//////                    videoSize: videoSize,
//////                    progressHandler: { [weak self] p in
//////                        Task { @MainActor in self?.exportProgress = p }
//////                    }
//////                )
//////                isExporting = false
//////                completion(url)
//////            } catch {
//////                isExporting = false
//////                exportErrorMessage = error.localizedDescription
//////                showExportError = true
//////                completion(nil)
//////            }
//////        }
//////    }
//////}
//////
//////// MARK: - Video compositor (AVFoundation pipeline)
//////
//////enum VideoTextCompositor {
//////
//////    /// Exports the video at `videoURL` with `textItems` burned into every frame.
//////    /// Returns the URL of the exported file (written to the OS temp directory).
//////    static func export(
//////        videoURL: URL,
//////        textItems: [VideoTextItem],
//////        canvasFrame: CGRect,             // on-screen display rect of the video (points)
//////        videoSize: CGSize,               // native pixel dimensions of the video track
//////        progressHandler: @escaping (Double) -> Void
//////    ) async throws -> URL {
//////
//////        let asset = AVURLAsset(url: videoURL)
//////
//////        // ── 1. Build the composition ───────────────────────────────────────────
//////
//////        let composition = AVMutableComposition()
//////
//////        guard
//////            let videoTrack = try await asset.loadTracks(withMediaType: .video).first
//////            
//////        else {
//////            throw CompositorError.noVideoTrack
//////        }
//////
//////        let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
//////        let duration = try await asset.load(.duration)
//////
//////        let compVideoTrack = composition.addMutableTrack(
//////            withMediaType: .video,
//////            preferredTrackID: kCMPersistentTrackID_Invalid
//////        )!
//////        try compVideoTrack.insertTimeRange(
//////            CMTimeRange(start: .zero, duration: duration),
//////            of: videoTrack,
//////            at: .zero
//////        )
//////
//////        if let audioTrack {
//////            let compAudioTrack = composition.addMutableTrack(
//////                withMediaType: .audio,
//////                preferredTrackID: kCMPersistentTrackID_Invalid
//////            )!
//////            try? compAudioTrack.insertTimeRange(
//////                CMTimeRange(start: .zero, duration: duration),
//////                of: audioTrack,
//////                at: .zero
//////            )
//////        }
//////
//////        // ── 2. Build the Core Animation layer tree ─────────────────────────────
//////        //
//////        // AVVideoCompositionCoreAnimationTool expects:
//////        //   parentLayer
//////        //     ├── videoLayer   (AVFoundation draws each decoded frame here)
//////        //     └── overlayLayer (our CATextLayers go here, composited on top)
//////        //
//////        // All sizes are in VIDEO PIXEL space.
//////
//////        let videoRect = CGRect(origin: .zero, size: videoSize)
//////
//////        let parentLayer = CALayer()
//////        parentLayer.frame = videoRect
//////        parentLayer.isGeometryFlipped = true   // CA → video coordinate system
//////
//////        let videoLayer = CALayer()
//////        videoLayer.frame = videoRect
//////        parentLayer.addSublayer(videoLayer)
//////
//////        let overlayLayer = CALayer()
//////        overlayLayer.frame = videoRect
//////        parentLayer.addSublayer(overlayLayer)
//////
//////        // Scale factors from the on-screen canvas (display points) to video pixels
//////        let scaleX = canvasFrame.width  > 0 ? videoSize.width  / canvasFrame.width  : 1
//////        let scaleY = canvasFrame.height > 0 ? videoSize.height / canvasFrame.height : 1
//////
//////        for item in textItems {
//////            let textLayer = CATextLayer()
//////            textLayer.string = item.text
//////            textLayer.font = CTFontCreateWithName("Helvetica-Bold" as CFString,
//////                                                  item.fontSize * (scaleX + scaleY) / 2, nil)
//////            textLayer.fontSize = item.fontSize * (scaleX + scaleY) / 2
//////            textLayer.foregroundColor = UIColor(item.color).cgColor
//////            textLayer.alignmentMode = .center
//////            textLayer.contentsScale = UIScreen.main.scale
//////            textLayer.isWrapped = false
//////
//////            // Size the layer generously (it clips to what's drawn).
//////            let scaledFont = item.fontSize * (scaleX + scaleY) / 2
//////            let estimatedWidth  = CGFloat(item.text.count) * scaledFont * 0.65 + scaledFont
//////            let estimatedHeight = scaledFont * 1.4
//////
//////            // item.position is the CENTRE of the text in canvas points.
//////            // We convert to video pixels and offset by half the estimated size
//////            // so the layer is centred on that point.
//////            let cx = item.position.x * scaleX
//////            let cy = item.position.y * scaleY
//////            textLayer.frame = CGRect(
//////                x: cx - estimatedWidth  / 2,
//////                y: cy - estimatedHeight / 2,
//////                width: estimatedWidth,
//////                height: estimatedHeight
//////            )
//////
//////            overlayLayer.addSublayer(textLayer)
//////        }
//////
//////        // ── 3. Wire up the video composition ──────────────────────────────────
//////
//////        let videoComposition = AVMutableVideoComposition()
//////        videoComposition.renderSize = videoSize
//////        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
//////        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
//////            postProcessingAsVideoLayer: videoLayer,
//////            in: parentLayer
//////        )
//////
//////        let instruction = AVMutableVideoCompositionInstruction()
//////        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
//////
//////        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
//////
//////        // Apply the source track's preferred transform so rotated videos
//////        // (e.g. portrait recordings) display correctly.
//////        let preferredTransform = try await videoTrack.load(.preferredTransform)
//////        layerInstruction.setTransform(preferredTransform, at: .zero)
//////
//////        instruction.layerInstructions = [layerInstruction]
//////        videoComposition.instructions = [instruction]
//////
//////        // ── 4. Export ─────────────────────────────────────────────────────────
//////
//////        let outputURL = FileManager.default.temporaryDirectory
//////            .appendingPathComponent("video_text_\(UUID().uuidString).mov")
//////
//////        // Remove any stale file at that path (shouldn't happen with UUID, but be safe).
//////        try? FileManager.default.removeItem(at: outputURL)
//////
//////        guard let session = AVAssetExportSession(asset: composition,
//////                                                  presetName: AVAssetExportPresetHighestQuality)
//////        else {
//////            throw CompositorError.exportSessionCreationFailed
//////        }
//////
//////        session.outputURL = outputURL
//////        session.outputFileType = .mov
//////        session.videoComposition = videoComposition
//////        session.shouldOptimizeForNetworkUse = true
//////
//////        // Poll progress while export runs
//////        let progressPoller = Task {
//////            while !Task.isCancelled {
//////                progressHandler(Double(session.progress))
//////                try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
//////            }
//////        }
//////
//////        await session.export()
//////        progressPoller.cancel()
//////        progressHandler(1.0)
//////
//////        switch session.status {
//////        case .completed:
//////            return outputURL
//////        case .failed:
//////            throw session.error ?? CompositorError.exportFailed
//////        case .cancelled:
//////            throw CompositorError.exportCancelled
//////        default:
//////            throw CompositorError.exportFailed
//////        }
//////    }
//////
//////    enum CompositorError: LocalizedError {
//////        case noVideoTrack
//////        case exportSessionCreationFailed
//////        case exportFailed
//////        case exportCancelled
//////
//////        var errorDescription: String? {
//////            switch self {
//////            case .noVideoTrack:              return "The video file has no video track."
//////            case .exportSessionCreationFailed: return "Could not create export session."
//////            case .exportFailed:              return "Export failed."
//////            case .exportCancelled:           return "Export was cancelled."
//////            }
//////        }
//////    }
//////}
//////
//////// MARK: - Preview
//////
//////#Preview {
//////    VideoTextEditorPreviewHost()
//////}
//////
//////struct VideoTextEditorPreviewHost: View {
//////    var body: some View {
//////        // Point this at any .mp4/.mov in your bundle for previewing.
//////        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
//////            VideoTextEditorView(videoURL: url) { result in
//////                print("Exported to:", result?.path ?? "nil")
//////            }
//////        } else {
//////            ZStack {
//////                Color.black.ignoresSafeArea()
//////                Text("Add a sample.mp4 to your bundle to preview")
//////                    .foregroundStyle(.white)
//////                    .multilineTextAlignment(.center)
//////                    .padding()
//////            }
//////        }
//////    }
//////}
////
////
////
////
////
//////
//////  VideoTextEditorView.swift
//////
//////  A SwiftUI view that takes a video URL, displays a thumbnail with a play
//////  indicator, lets the user add multiple draggable/zoomable/colorable text
//////  overlays, and on Done exports a new video with every text item burned
//////  into every frame using AVFoundation's Core Animation compositor.
//////
//////  Usage:
//////
//////      VideoTextEditorView(videoURL: url) { resultURL in
//////          // resultURL: URL?  (nil on failure or cancel)
//////      }
//////
//////  Requirements: SwiftUI, AVFoundation, CoreImage (all system frameworks).
//////  Info.plist: no special keys required for local file URLs.
//////
////
////import SwiftUI
////import AVFoundation
////
////// MARK: - Video Text Item
//////
////// Mirrors the TextItem struct from ImageTextEditorView. If both files are in
////// the same target, rename one (e.g. VideoTextItem) or extract a shared
////// TextItem into its own file and delete the duplicate here.
////
////struct VideoTextItem: Identifiable, Equatable {
////    let id: UUID
////    var text: String
////    var position: CGPoint   // canvas-local points (relative to the fitted preview frame)
////    var fontSize: CGFloat
////    var color: Color
////
////    init(id: UUID = UUID(), text: String = "", position: CGPoint,
////         fontSize: CGFloat = 32, color: Color = .white) {
////        self.id = id
////        self.text = text
////        self.position = position
////        self.fontSize = fontSize
////        self.color = color
////    }
////}
////
////// MARK: - Public View
////
////struct VideoTextEditorView: View {
////
////    let videoURL: URL
////    /// Called with the URL of the exported video (written to a temp file),
////    /// or nil if the user cancelled or export failed.
////    let onComplete: (URL?) -> Void
////
////    var onCancel: (() -> Void)? = nil
////
////    @StateObject private var model: VideoTextEditorModel
////
////    init(videoURL: URL, onCancel: (() -> Void)? = nil, onComplete: @escaping (URL?) -> Void) {
////        self.videoURL = videoURL
////        self.onCancel = onCancel
////        self.onComplete = onComplete
////        _model = StateObject(wrappedValue: VideoTextEditorModel(videoURL: videoURL))
////    }
////
////    var body: some View {
////        GeometryReader { geo in
////            ZStack {
////                Color.black.ignoresSafeArea()
////
////                VStack(spacing: 0) {
////                    topBar
////                        .padding(.top, max(geo.safeAreaInsets.top, 12))
////
////                    Spacer(minLength: 0)
////
////                    // Canvas: thumbnail + text overlays + vertical color bar
////                    GeometryReader { canvasGeo in
////                        let fitted = model.fittedFrame(in: canvasGeo.size)
////
////                        ZStack {
////                            thumbnailLayer(fitted: fitted)
////
////                            // Text overlays
////                            ForEach(model.textItems) { item in
////                                VideoTextItemView(model: model, item: item, canvasFrame: fitted)
////                            }
////
////                            // Vertical hue bar, right edge, visible only when an item is selected
////                            if model.selectedID != nil {
////                                HStack {
////                                    Spacer()
////                                    VideoVerticalHueColorBar(selectedColor: model.selectedColorBinding)
////                                        .frame(width: 36,
////                                               height: min(canvasGeo.size.height * 0.7, 260))
////                                        .padding(.trailing, 8)
////                                }
////                            }
////                        }
////                        .onAppear { model.setupCanvas(in: fitted) }
////                        .onChange(of: canvasGeo.size) { _, newSize in
////                            model.rescaleCanvas(to: model.fittedFrame(in: newSize))
////                        }
////                    }
////                    .padding(.horizontal, 12)
////
////                    Spacer(minLength: 0)
////
////                    bottomControls
////                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
////                }
////            }
////        }
////        // Export progress overlay
////        .overlay {
////            if model.isExporting {
////                exportingOverlay
////            }
////        }
////        .background(
////            VideoHiddenTextInput(text: model.selectedTextBinding,
////                                 isActive: $model.isEditingText)
////        )
////        .ignoresSafeArea(.keyboard, edges: .bottom)
////        .alert("Export Failed", isPresented: $model.showExportError) {
////            Button("OK", role: .cancel) {}
////        } message: {
////            Text(model.exportErrorMessage)
////        }
////    }
////
////    // MARK: Thumbnail layer
////
////    @ViewBuilder
////    private func thumbnailLayer(fitted: CGRect) -> some View {
////        if let thumb = model.thumbnail {
////            Image(uiImage: thumb)
////                .resizable()
////                .frame(width: fitted.width, height: fitted.height)
////                .position(x: fitted.midX, y: fitted.midY)
////                .onTapGesture {
////                    model.isEditingText = false
////                    model.selectedID = nil
////                }
////
////            // Play button badge in the centre of the thumbnail
////            Image(systemName: "play.circle.fill")
////                .font(.system(size: 60))
////                .symbolRenderingMode(.palette)
////                .foregroundStyle(.white, .black.opacity(0.45))
////                .position(x: fitted.midX, y: fitted.midY)
////                .allowsHitTesting(false)
////
////        } else {
////            // Thumbnail still loading
////            ZStack {
////                RoundedRectangle(cornerRadius: 8)
////                    .fill(Color.white.opacity(0.08))
////                    .frame(width: fitted.width, height: fitted.height)
////                ProgressView()
////                    .tint(.white)
////            }
////            .position(x: fitted.midX, y: fitted.midY)
////        }
////    }
////
////    // MARK: Top bar
////
////    private var topBar: some View {
////        HStack {
////            Button {
////                onCancel?()
////            } label: {
////                Text("Cancel")
////                    .foregroundStyle(.white)
////            }
////
////            Spacer()
////
////            Button {
////                model.exportVideo { url in
////                    onComplete(url)
////                }
////            } label: {
////                Text("Done")
////                    .fontWeight(.semibold)
////                    .foregroundStyle(.black)
////                    .padding(.horizontal, 18)
////                    .padding(.vertical, 8)
////                    .background(Color.white, in: Capsule())
////            }
////            .disabled(model.isExporting)
////        }
////        .padding(.horizontal, 20)
////    }
////
////    // MARK: Bottom controls
////
////    private var bottomControls: some View {
////        HStack(spacing: 28) {
////            Button {
////                model.addText()
////            } label: {
////                Label("Add Text", systemImage: "textformat")
////                    .foregroundStyle(.white)
////                    .font(.callout.weight(.medium))
////            }
////
////            if model.selectedID != nil {
////                Button {
////                    model.isEditingText = true
////                } label: {
////                    Label("Edit", systemImage: "pencil")
////                        .foregroundStyle(.white)
////                        .font(.callout.weight(.medium))
////                }
////
////                Button(role: .destructive) {
////                    model.removeSelectedText()
////                } label: {
////                    Label("Remove", systemImage: "trash")
////                        .foregroundStyle(.white)
////                        .font(.callout.weight(.medium))
////                }
////            }
////        }
////    }
////
////    // MARK: Export progress overlay
////
////    private var exportingOverlay: some View {
////        ZStack {
////            Color.black.opacity(0.6).ignoresSafeArea()
////            VStack(spacing: 16) {
////                ProgressView(value: model.exportProgress)
////                    .progressViewStyle(.circular)
////                    .tint(.white)
////                    .scaleEffect(1.4)
////                Text("Exporting…")
////                    .foregroundStyle(.white)
////                    .font(.callout.weight(.medium))
////                Text("\(Int(model.exportProgress * 100))%")
////                    .foregroundStyle(.white.opacity(0.7))
////                    .font(.caption)
////            }
////        }
////    }
////}
////
////// MARK: - Draggable / zoomable text item view
////
////private struct VideoTextItemView: View {
////    @ObservedObject var model: VideoTextEditorModel
////    let item: VideoTextItem
////    let canvasFrame: CGRect
////
////    private var isSelected: Bool { model.selectedID == item.id }
////
////    var body: some View {
////        Text(item.text.isEmpty ? "Tap to edit" : item.text)
////            .font(.system(size: item.fontSize, weight: .bold))
////            .foregroundStyle(item.color)
////            .padding(.horizontal, 10)
////            .padding(.vertical, 6)
////            .background(
////                RoundedRectangle(cornerRadius: 6)
////                    .fill(Color.black.opacity(isSelected ? 0.18 : 0))
////            )
////            .overlay(
////                RoundedRectangle(cornerRadius: 6)
////                    .strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
////            )
////            .position(item.position)
////            .gesture(dragGesture.simultaneously(with: zoomGesture))
////            .onTapGesture { model.select(item.id) }
////            .frame(width: canvasFrame.width, height: canvasFrame.height, alignment: .topLeading)
////            .allowsHitTesting(true)
////    }
////
////    private var dragGesture: some Gesture {
////        DragGesture(minimumDistance: 0)
////            .onChanged { value in
////                model.select(item.id)
////                if !model.isDragging { model.beginDrag(for: item.id) }
////                model.drag(translation: value.translation,
////                           bounds: CGRect(origin: .zero, size: canvasFrame.size))
////            }
////            .onEnded { _ in model.endDrag() }
////    }
////
////    private var zoomGesture: some Gesture {
////        MagnificationGesture()
////            .onChanged { scale in
////                model.select(item.id)
////                if !model.isZooming { model.beginZoom(for: item.id) }
////                model.zoom(scale: scale)
////            }
////            .onEnded { _ in model.endZoom() }
////    }
////}
////
////// MARK: - Vertical hue color bar
////
////private struct VideoVerticalHueColorBar: View {
////    @Binding var selectedColor: Color
////
////    var body: some View {
////        GeometryReader { geo in
////            ZStack(alignment: .top) {
////                RoundedRectangle(cornerRadius: geo.size.width / 2)
////                    .fill(LinearGradient(colors: hueColors,
////                                         startPoint: .top,
////                                         endPoint: .bottom))
////
////                Circle()
////                    .fill(selectedColor)
////                    .frame(width: geo.size.width + 6, height: geo.size.width + 6)
////                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
////                    .shadow(color: .black.opacity(0.3), radius: 2)
////                    .position(x: geo.size.width / 2, y: handleY(in: geo.size))
////            }
////            .contentShape(Rectangle())
////            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
////                updateColor(atY: value.location.y, height: geo.size.height)
////            })
////        }
////    }
////
////    private var hueColors: [Color] {
////        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
////            Color(hue: $0, saturation: 0.9, brightness: 1.0)
////        }
////    }
////
////    private func handleY(in size: CGSize) -> CGFloat {
////        var hue: CGFloat = 0
////        UIColor(selectedColor).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
////        return hue * size.height
////    }
////
////    private func updateColor(atY y: CGFloat, height: CGFloat) {
////        guard height > 0 else { return }
////        let hue = min(max(y, 0), height) / height
////        selectedColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
////    }
////}
////
////// MARK: - Hidden keyboard input bridge (same pattern as image editor)
////
////private struct VideoHiddenTextInput: UIViewRepresentable {
////    @Binding var text: String
////    @Binding var isActive: Bool
////
////    func makeUIView(context: Context) -> UITextField {
////        let f = UITextField()
////        f.delegate = context.coordinator
////        f.returnKeyType = .done
////        f.isHidden = true
////        return f
////    }
////
////    func updateUIView(_ uiView: UITextField, context: Context) {
////        // Guard against UIKit↔SwiftUI feedback loop (AttributeGraph cycle).
////        if uiView.text != text { uiView.text = text }
////        if isActive, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
////        else if !isActive, uiView.isFirstResponder { uiView.resignFirstResponder() }
////    }
////
////    func makeCoordinator() -> Coordinator { Coordinator(self) }
////
////    final class Coordinator: NSObject, UITextFieldDelegate {
////        let parent: VideoHiddenTextInput
////        init(_ parent: VideoHiddenTextInput) { self.parent = parent }
////        func textFieldDidChangeSelection(_ tf: UITextField) { parent.text = tf.text ?? "" }
////        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.isActive = false; return true }
////    }
////}
////
////// MARK: - Model
////
////@MainActor
////final class VideoTextEditorModel: ObservableObject {
////
////    let videoURL: URL
////
////    @Published var thumbnail: UIImage?
////    @Published var textItems: [VideoTextItem] = []
////    @Published var selectedID: UUID?
////    @Published var isEditingText = false
////    @Published var isDragging = false
////    @Published var isZooming = false
////    @Published var isExporting = false
////    @Published var exportProgress: Double = 0
////    @Published var showExportError = false
////    @Published var exportErrorMessage = ""
////
////    private(set) var canvasFrame: CGRect = .zero
////    private var videoSize: CGSize = .zero   // post-transform display size (what the user sees)
////
////    private var dragStartPos: CGPoint = .zero
////    private var fontSizeAtZoomStart: CGFloat = 32
////    private var activeGestureID: UUID?
////
////    private let minFontSize: CGFloat = 12
////    private let maxFontSize: CGFloat = 160
////
////    private var exportTask: Task<Void, Never>?
////
////    init(videoURL: URL) {
////        self.videoURL = videoURL
////        Task { await loadThumbnailAndVideoSize() }
////    }
////
////    // MARK: Thumbnail + video size
////
////    private func loadThumbnailAndVideoSize() async {
////        let asset = AVURLAsset(url: videoURL)
////
////        // Get natural video size from the first video track
////        if let track = try? await asset.loadTracks(withMediaType: .video).first {
////            let size = (try? await track.load(.naturalSize)) ?? .zero
////            let transform = (try? await track.load(.preferredTransform)) ?? .identity
////            // Apply transform to get the display (rotated) size
////            let transformed = size.applying(transform)
////            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
////        }
////
////        // Generate thumbnail at 0.0 s
////        let generator = AVAssetImageGenerator(asset: asset)
////        generator.appliesPreferredTrackTransform = true
////        generator.maximumSize = CGSize(width: 1024, height: 1024)
////
////        let time = CMTime(seconds: 0, preferredTimescale: 600)
////        if let cgImage = try? await generator.image(at: time).image {
////            thumbnail = UIImage(cgImage: cgImage)
////        }
////    }
////
////    // MARK: Canvas layout (aspect-fit, same as image editor)
////
////    func fittedFrame(in containerSize: CGSize) -> CGRect {
////        let srcSize = videoSize.width > 0 ? videoSize : CGSize(width: 16, height: 9)
////        guard containerSize.width > 0, containerSize.height > 0 else {
////            return CGRect(origin: .zero, size: containerSize)
////        }
////        let aspect = srcSize.width / srcSize.height
////        let containerAspect = containerSize.width / containerSize.height
////        var size = containerSize
////        if aspect > containerAspect {
////            size.height = containerSize.width / aspect
////        } else {
////            size.width = containerSize.height * aspect
////        }
////        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
////                              y: (containerSize.height - size.height) / 2)
////        return CGRect(origin: origin, size: size)
////    }
////
////    func setupCanvas(in frame: CGRect) {
////        canvasFrame = frame
////    }
////
////    func rescaleCanvas(to newFrame: CGRect) {
////        let old = canvasFrame
////        guard old.width > 0, old.height > 0 else { canvasFrame = newFrame; return }
////        let sx = newFrame.width / old.width
////        let sy = newFrame.height / old.height
////        for i in textItems.indices {
////            textItems[i].position.x *= sx
////            textItems[i].position.y *= sy
////            textItems[i].fontSize *= (sx + sy) / 2
////        }
////        canvasFrame = newFrame
////    }
////
////    // MARK: Bindings for selected item
////
////    var selectedTextBinding: Binding<String> {
////        Binding(
////            get: { [weak self] in
////                guard let self, let id = selectedID,
////                      let item = textItems.first(where: { $0.id == id }) else { return "" }
////                return item.text
////            },
////            set: { [weak self] val in
////                guard let self, let id = selectedID else { return }
////                updateItem(id) { $0.text = val }
////            }
////        )
////    }
////
////    var selectedColorBinding: Binding<Color> {
////        Binding(
////            get: { [weak self] in
////                guard let self, let id = selectedID,
////                      let item = textItems.first(where: { $0.id == id }) else { return .white }
////                return item.color
////            },
////            set: { [weak self] val in
////                guard let self, let id = selectedID else { return }
////                updateItem(id) { $0.color = val }
////            }
////        )
////    }
////
////    private func updateItem(_ id: UUID, _ mutate: (inout VideoTextItem) -> Void) {
////        guard let i = textItems.firstIndex(where: { $0.id == id }) else { return }
////        mutate(&textItems[i])
////    }
////
////    // MARK: Text lifecycle
////
////    func addText() {
////        let offset = CGFloat(textItems.count % 5) * 18
////        let pos = CGPoint(x: canvasFrame.width / 2 + offset - 36,
////                           y: canvasFrame.height / 2 + offset - 36)
////        let item = VideoTextItem(text: "", position: pos)
////        textItems.append(item)
////        selectedID = item.id
////        isEditingText = true
////    }
////
////    func select(_ id: UUID) {
////        guard selectedID != id else { return }
////        selectedID = id
////    }
////
////    func removeSelectedText() {
////        guard let id = selectedID else { return }
////        textItems.removeAll { $0.id == id }
////        selectedID = nil
////        isEditingText = false
////    }
////
////    // MARK: Drag
////
////    func beginDrag(for id: UUID) {
////        activeGestureID = id
////        dragStartPos = textItems.first(where: { $0.id == id })?.position ?? .zero
////        isDragging = true
////    }
////
////    func drag(translation: CGSize, bounds: CGRect) {
////        guard let id = activeGestureID else { return }
////        let proposed = CGPoint(x: dragStartPos.x + translation.width,
////                                y: dragStartPos.y + translation.height)
////        let clamped = CGPoint(x: min(max(proposed.x, bounds.minX), bounds.maxX),
////                               y: min(max(proposed.y, bounds.minY), bounds.maxY))
////        updateItem(id) { $0.position = clamped }
////    }
////
////    func endDrag() {
////        isDragging = false
////        activeGestureID = nil
////    }
////
////    // MARK: Zoom
////
////    func beginZoom(for id: UUID) {
////        activeGestureID = id
////        fontSizeAtZoomStart = textItems.first(where: { $0.id == id })?.fontSize ?? 32
////        isZooming = true
////    }
////
////    func zoom(scale: CGFloat) {
////        guard let id = activeGestureID else { return }
////        let clamped = min(max(fontSizeAtZoomStart * scale, minFontSize), maxFontSize)
////        updateItem(id) { $0.fontSize = clamped }
////    }
////
////    func endZoom() {
////        isZooming = false
////        activeGestureID = nil
////    }
////
////    // MARK: Export
////
////    /// Burns all text items into every frame of the video using
////    /// AVVideoCompositionCoreAnimationTool and exports to a temp .mov file.
////    func exportVideo(completion: @escaping (URL?) -> Void) {
////        let items = textItems.filter { !$0.text.isEmpty }
////        guard !items.isEmpty else {
////            // Nothing to burn in — hand back the original URL unchanged.
////            completion(videoURL)
////            return
////        }
////
////        exportTask = Task {
////            isExporting = true
////            exportProgress = 0
////
////            do {
////                let url = try await VideoTextCompositor.export(
////                    videoURL: videoURL,
////                    textItems: items,
////                    canvasFrame: canvasFrame,
////                    videoSize: videoSize,
////                    progressHandler: { [weak self] p in
////                        Task { @MainActor in self?.exportProgress = p }
////                    }
////                )
////                isExporting = false
////                completion(url)
////            } catch {
////                isExporting = false
////                exportErrorMessage = error.localizedDescription
////                showExportError = true
////                completion(nil)
////            }
////        }
////    }
////}
////
//////// MARK: - Video compositor (AVFoundation pipeline)
//////
//////enum VideoTextCompositor {
//////
//////    /// Exports the video at `videoURL` with `textItems` burned into every frame.
//////    /// Returns the URL of the exported file (written to the OS temp directory).
//////    static func export(
//////        videoURL: URL,
//////        textItems: [VideoTextItem],
//////        canvasFrame: CGRect,
//////        videoSize: CGSize,               // display size (post-transform, what the user sees)
//////        progressHandler: @escaping (Double) -> Void
//////    ) async throws -> URL {
//////
//////        let asset = AVURLAsset(url: videoURL)
//////
//////        // ── 1. Load track metadata ─────────────────────────────────────────────
//////
//////        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
//////            throw CompositorError.noVideoTrack
//////        }
//////
//////        let duration        = try await asset.load(.duration)
//////        let naturalSize     = try await videoTrack.load(.naturalSize)      // pre-rotation
//////        let preferredTransform = try await videoTrack.load(.preferredTransform)
//////        let nominalFR       = try await videoTrack.load(.nominalFrameRate)
//////
//////        // The "render size" for AVVideoComposition MUST be the natural (pre-rotation)
//////        // dimensions. The preferredTransform is applied inside the layer instruction
//////        // to handle rotation — it must NOT also be reflected in renderSize, or the
//////        // compositor will size the frame buffer incorrectly and crash / produce
//////        // garbled output with portrait phone videos.
//////        let renderSize = naturalSize  // e.g. 1920×1080 even for a portrait recording
//////
//////        // The display size is what the user actually sees (post-rotation), e.g. 1080×1920.
//////        // We use this to map canvas-point positions → render-space pixels below.
//////        let displaySize = videoSize   // passed in from the model (post-transform)
//////
//////        // ── 2. Build the mutable composition ──────────────────────────────────
//////
//////        let composition = AVMutableComposition()
//////
//////        let compVideoTrack = composition.addMutableTrack(
//////            withMediaType: .video,
//////            preferredTrackID: kCMPersistentTrackID_Invalid
//////        )!
//////        try compVideoTrack.insertTimeRange(
//////            CMTimeRange(start: .zero, duration: duration),
//////            of: videoTrack, at: .zero
//////        )
//////
//////        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
//////        if let audioTrack = audioTracks.first {
//////            let compAudioTrack = composition.addMutableTrack(
//////                withMediaType: .audio,
//////                preferredTrackID: kCMPersistentTrackID_Invalid
//////            )!
//////            try? compAudioTrack.insertTimeRange(
//////                CMTimeRange(start: .zero, duration: duration),
//////                of: audioTrack, at: .zero
//////            )
//////        }
//////
//////        // ── 3. Build the Core Animation layer tree ────────────────────────────
//////        //
//////        // Rule: EVERYTHING in the CA layer tree is sized to `renderSize`
//////        // (natural/pre-rotation dimensions). AVFoundation composites in that
//////        // space. The preferredTransform in the layer instruction handles
//////        // rotation *within* that render buffer.
//////        //
//////        // isGeometryFlipped must be true on BOTH parentLayer and videoLayer —
//////        // AVFoundation's compositor expects a flipped coordinate system (origin
//////        // at bottom-left) that matches Core Video pixel buffers. If only the
//////        // parent is flipped, the compositor crashes or produces upside-down output.
//////
//////        let renderRect = CGRect(origin: .zero, size: renderSize)
//////
//////        let parentLayer = CALayer()
//////        parentLayer.frame = renderRect
//////        parentLayer.isGeometryFlipped = true
//////
//////        let videoLayer = CALayer()
//////        videoLayer.frame = renderRect
//////        videoLayer.isGeometryFlipped = true
//////        parentLayer.addSublayer(videoLayer)
//////
//////        let overlayLayer = CALayer()
//////        overlayLayer.frame = renderRect
//////        parentLayer.addSublayer(overlayLayer)
//////
//////        // ── 4. Map text positions into render (natural) space ─────────────────
//////        //
//////        // The user positioned text relative to `canvasFrame`, which shows the
//////        // video in its *display* orientation (post-rotation). We need to map
//////        // those display-space positions into the pre-rotation render space.
//////        //
//////        // Strategy: convert canvas point → normalised display position (0-1)
//////        // → display pixel → render pixel by applying the *inverse* of the
//////        // display-to-render rotation.
//////        //
//////        // We derive the rotation angle from the preferredTransform's 'b'
//////        // component (sin of the rotation). This handles all four orientations
//////        // recorded by iPhone: 0°, 90°, 180°, 270°.
//////
//////        let angle = atan2(preferredTransform.b, preferredTransform.a)  // radians
//////
//////        for item in textItems {
//////            // 1. Canvas point → normalised display coordinate (0-1 range)
//////            let normX = canvasFrame.width  > 0 ? item.position.x / canvasFrame.width  : 0.5
//////            let normY = canvasFrame.height > 0 ? item.position.y / canvasFrame.height : 0.5
//////
//////            // 2. Normalised display → display pixel
//////            let displayX = normX * displaySize.width
//////            let displayY = normY * displaySize.height
//////
//////            // 3. Display pixel → render pixel (undo rotation)
//////            //    Rotate the point around the centre of the render buffer by -angle.
//////            let renderCX = renderSize.width  / 2
//////            let renderCY = renderSize.height / 2
//////
//////            // Map display pixel into render-centred coordinates
//////            // (account for possible axis swap when display is rotated 90/270)
//////            let isTransposed = abs(angle) > .pi / 4 && abs(angle) < 3 * .pi / 4
//////                             || abs(angle) > 5 * .pi / 4
//////
//////            var renderX: CGFloat
//////            var renderY: CGFloat
//////
//////            if isTransposed {
//////                // 90° or 270°: display W↔H are swapped relative to render W↔H
//////                let relX = displayX - displaySize.width  / 2
//////                let relY = displayY - displaySize.height / 2
//////                // Rotate back by -angle around origin then re-centre in render space
//////                renderX = renderCX + relX * cos(-angle) - relY * sin(-angle)
//////                renderY = renderCY + relX * sin(-angle) + relY * cos(-angle)
//////            } else {
//////                // 0° or 180°
//////                let relX = displayX - displaySize.width  / 2
//////                let relY = displayY - displaySize.height / 2
//////                renderX = renderCX + relX * cos(-angle) - relY * sin(-angle)
//////                renderY = renderCY + relX * sin(-angle) + relY * cos(-angle)
//////            }
//////
//////            // 4. Build the CATextLayer in render space
//////            let scaleX = renderSize.width  / displaySize.width
//////            let scaleY = renderSize.height / displaySize.height
//////            let avgScale = isTransposed ? (renderSize.width / displaySize.height
//////                                         + renderSize.height / displaySize.width) / 2
//////                                        : (scaleX + scaleY) / 2
//////
//////            let scaledFontSize = item.fontSize * avgScale
//////
//////            let textLayer = CATextLayer()
//////            textLayer.string         = item.text
//////            textLayer.fontSize       = scaledFontSize
//////            textLayer.font           = CTFontCreateWithName(
//////                "Helvetica-Bold" as CFString, scaledFontSize, nil
//////            )
//////            textLayer.foregroundColor = UIColor(item.color).cgColor
//////            textLayer.alignmentMode  = .center
//////            textLayer.contentsScale  = 1.0   // render space uses pixel units, not points
//////            textLayer.isWrapped      = false
//////
//////            // Generous bounding box centred on the mapped render position.
//////            let estW = CGFloat(item.text.count) * scaledFontSize * 0.7 + scaledFontSize * 2
//////            let estH = scaledFontSize * 1.6
//////
//////            textLayer.frame = CGRect(
//////                x: renderX - estW / 2,
//////                y: renderY - estH / 2,
//////                width: estW,
//////                height: estH
//////            )
//////
//////            overlayLayer.addSublayer(textLayer)
//////        }
//////
//////        // ── 5. Wire up the video composition ──────────────────────────────────
//////
//////        let videoComposition = AVMutableVideoComposition()
//////        videoComposition.renderSize   = renderSize
//////        videoComposition.frameDuration = CMTime(
//////            value: 1,
//////            timescale: CMTimeScale(max(nominalFR, 1))
//////        )
//////        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
//////            postProcessingAsVideoLayer: videoLayer,
//////            in: parentLayer
//////        )
//////
//////        let instruction = AVMutableVideoCompositionInstruction()
//////        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
//////
//////        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
//////            assetTrack: compVideoTrack
//////        )
//////        // Apply preferredTransform so the decoded frame is rotated into the
//////        // correct display orientation within the (natural-sized) render buffer.
//////        layerInstruction.setTransform(preferredTransform, at: .zero)
//////
//////        instruction.layerInstructions = [layerInstruction]
//////        videoComposition.instructions = [instruction]
//////
//////        // ── 6. Export ─────────────────────────────────────────────────────────
//////
//////        let outputURL = FileManager.default.temporaryDirectory
//////            .appendingPathComponent("video_text_\(UUID().uuidString).mov")
//////        try? FileManager.default.removeItem(at: outputURL)
//////
//////        guard let session = AVAssetExportSession(
//////            asset: composition,
//////            presetName: AVAssetExportPresetHighestQuality
//////        ) else {
//////            throw CompositorError.exportSessionCreationFailed
//////        }
//////
//////        session.outputURL          = outputURL
//////        session.outputFileType     = .mov
//////        session.videoComposition   = videoComposition
//////        session.shouldOptimizeForNetworkUse = true
//////
//////        // Poll export progress every 100 ms
//////        let poller = Task {
//////            while !Task.isCancelled {
//////                progressHandler(Double(session.progress))
//////                try? await Task.sleep(nanoseconds: 100_000_000)
//////            }
//////        }
//////
//////        await session.export()
//////        poller.cancel()
//////        progressHandler(1.0)
//////
//////        switch session.status {
//////        case .completed:  return outputURL
//////        case .failed:     throw session.error ?? CompositorError.exportFailed
//////        case .cancelled:  throw CompositorError.exportCancelled
//////        default:          throw CompositorError.exportFailed
//////        }
//////    }
//////
//////    enum CompositorError: LocalizedError {
//////        case noVideoTrack
//////        case exportSessionCreationFailed
//////        case exportFailed
//////        case exportCancelled
//////
//////        var errorDescription: String? {
//////            switch self {
//////            case .noVideoTrack:                return "The video file has no video track."
//////            case .exportSessionCreationFailed: return "Could not create export session."
//////            case .exportFailed:                return "Export failed."
//////            case .exportCancelled:             return "Export was cancelled."
//////            }
//////        }
//////    }
//////}
//////
//////// MARK: - Preview
//////
//////#Preview {
//////    VideoTextEditorPreviewHost()
//////}
//////
////struct VideoTextEditorPreviewHost: View {
////    var body: some View {
////        // Point this at any .mp4/.mov in your bundle for previewing.
////        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
////            VideoTextEditorView(videoURL: url) { result in
////                print("Exported to:", result?.path ?? "nil")
////            }
////        } else {
////            ZStack {
////                Color.black.ignoresSafeArea()
////                Text("Add a sample.mp4 to your bundle to preview")
////                    .foregroundStyle(.white)
////                    .multilineTextAlignment(.center)
////                    .padding()
////            }
////        }
////    }
////}
////
//
//
//
////
////  VideoTextEditorView.swift
////
////  A SwiftUI view that takes a video URL, displays a thumbnail with a play
////  indicator, lets the user add multiple draggable/zoomable/colorable text
////  overlays, and on Done exports a new video with every text item burned
////  into every frame using AVFoundation's Core Animation compositor.
////
////  Usage:
////
////      VideoTextEditorView(videoURL: url) { resultURL in
////          // resultURL: URL?  (nil on failure or cancel)
////      }
////
////  Requirements: SwiftUI, AVFoundation, CoreImage (all system frameworks).
////  Info.plist: no special keys required for local file URLs.
////
//
//import SwiftUI
//import AVFoundation
//import _AVKit_SwiftUI
//
//// MARK: - Video Text Item
////
//// Mirrors the TextItem struct from ImageTextEditorView. If both files are in
//// the same target, rename one (e.g. VideoTextItem) or extract a shared
//// TextItem into its own file and delete the duplicate here.
//
//struct VideoTextItem: Identifiable, Equatable {
//    let id: UUID
//    var text: String
//    var position: CGPoint   // canvas-local points (relative to the fitted preview frame)
//    var fontSize: CGFloat
//    var color: Color
//
//    init(id: UUID = UUID(), text: String = "", position: CGPoint,
//         fontSize: CGFloat = 32, color: Color = .white) {
//        self.id = id
//        self.text = text
//        self.position = position
//        self.fontSize = fontSize
//        self.color = color
//    }
//}
//
//// MARK: - Public View
//
//struct VideoTextEditorView: View {
//
//    let videoURL: URL
//    /// Called with the URL of the exported video (written to a temp file),
//    /// or nil if the user cancelled or export failed.
//    let onComplete: (URL?) -> Void
//
//    var onCancel: (() -> Void)? = nil
//
//    @StateObject private var model: VideoTextEditorModel
//
//    init(videoURL: URL, onCancel: (() -> Void)? = nil, onComplete: @escaping (URL?) -> Void) {
//        self.videoURL = videoURL
//        self.onCancel = onCancel
//        self.onComplete = onComplete
//        _model = StateObject(wrappedValue: VideoTextEditorModel(videoURL: videoURL))
//    }
//
//    var body: some View {
//        GeometryReader { geo in
//            ZStack {
//                Color.black.ignoresSafeArea()
//
//                VStack(spacing: 0) {
//                    topBar
//                        .padding(.top, max(geo.safeAreaInsets.top, 12))
//
//                    Spacer(minLength: 0)
//
//                    // Canvas: thumbnail + text overlays + vertical color bar
//                    GeometryReader { canvasGeo in
//                        let fitted = model.fittedFrame(in: canvasGeo.size)
//
//                        ZStack {
//                            thumbnailLayer(fitted: fitted)
//
//                            // Text overlays
//                            ForEach(model.textItems) { item in
//                                VideoTextItemView(model: model, item: item, canvasFrame: fitted)
//                            }
//
//                            // Vertical hue bar, right edge, visible only when an item is selected
//                            if model.selectedID != nil {
//                                HStack {
//                                    Spacer()
//                                    VideoVerticalHueColorBar(selectedColor: model.selectedColorBinding)
//                                        .frame(width: 36,
//                                               height: min(canvasGeo.size.height * 0.7, 260))
//                                        .padding(.trailing, 8)
//                                }
//                            }
//                        }
//                        .onAppear { model.setupCanvas(in: fitted) }
//                        .onChange(of: canvasGeo.size) { _, newSize in
//                            model.rescaleCanvas(to: model.fittedFrame(in: newSize))
//                        }
//                    }
//                    .padding(.horizontal, 12)
//
//                    Spacer(minLength: 0)
//
//                    bottomControls
//                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
//                }
//            }
//        }
//        // Export progress overlay
//        .overlay {
//            if model.isExporting {
//                exportingOverlay
//            }
//        }
//        .background(
//            VideoHiddenTextInput(text: model.selectedTextBinding,
//                                 isActive: $model.isEditingText)
//        )
//        .ignoresSafeArea(.keyboard, edges: .bottom)
//        .alert("Export Failed", isPresented: $model.showExportError) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(model.exportErrorMessage)
//        }
//    }
//
//    // MARK: Thumbnail layer
//
//    @ViewBuilder
//    private func thumbnailLayer(fitted: CGRect) -> some View {
//        if let thumb = model.thumbnail {
//            Image(uiImage: thumb)
//                .resizable()
//                .frame(width: fitted.width, height: fitted.height)
//                .position(x: fitted.midX, y: fitted.midY)
//                .onTapGesture {
//                    model.isEditingText = false
//                    model.selectedID = nil
//                }
//
//            // Play button badge in the centre of the thumbnail
//            Image(systemName: "play.circle.fill")
//                .font(.system(size: 60))
//                .symbolRenderingMode(.palette)
//                .foregroundStyle(.white, .black.opacity(0.45))
//                .position(x: fitted.midX, y: fitted.midY)
//                .allowsHitTesting(false)
//
//        } else {
//            // Thumbnail still loading
//            ZStack {
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color.white.opacity(0.08))
//                    .frame(width: fitted.width, height: fitted.height)
//                ProgressView()
//                    .tint(.white)
//            }
//            .position(x: fitted.midX, y: fitted.midY)
//        }
//    }
//
//    // MARK: Top bar
//
//    private var topBar: some View {
//        HStack {
//            Button {
//                onCancel?()
//            } label: {
//                Text("Cancel")
//                    .foregroundStyle(.white)
//            }
//
//            Spacer()
//
//            Button {
//                model.exportVideo { url in
//                    onComplete(url)
//                }
//            } label: {
//                Text("Done")
//                    .fontWeight(.semibold)
//                    .foregroundStyle(.black)
//                    .padding(.horizontal, 18)
//                    .padding(.vertical, 8)
//                    .background(Color.white, in: Capsule())
//            }
//            .disabled(model.isExporting)
//        }
//        .padding(.horizontal, 20)
//    }
//
//    // MARK: Bottom controls
//
//    private var bottomControls: some View {
//        HStack(spacing: 28) {
//            Button {
//                model.addText()
//            } label: {
//                Label("Add Text", systemImage: "textformat")
//                    .foregroundStyle(.white)
//                    .font(.callout.weight(.medium))
//            }
//
//            if model.selectedID != nil {
//                Button {
//                    model.isEditingText = true
//                } label: {
//                    Label("Edit", systemImage: "pencil")
//                        .foregroundStyle(.white)
//                        .font(.callout.weight(.medium))
//                }
//
//                Button(role: .destructive) {
//                    model.removeSelectedText()
//                } label: {
//                    Label("Remove", systemImage: "trash")
//                        .foregroundStyle(.white)
//                        .font(.callout.weight(.medium))
//                }
//            }
//        }
//    }
//
//    // MARK: Export progress overlay
//
//    private var exportingOverlay: some View {
//        ZStack {
//            Color.black.opacity(0.6).ignoresSafeArea()
//            VStack(spacing: 16) {
//                ProgressView(value: model.exportProgress)
//                    .progressViewStyle(.circular)
//                    .tint(.white)
//                    .scaleEffect(1.4)
//                Text("Exporting…")
//                    .foregroundStyle(.white)
//                    .font(.callout.weight(.medium))
//                Text("\(Int(model.exportProgress * 100))%")
//                    .foregroundStyle(.white.opacity(0.7))
//                    .font(.caption)
//            }
//        }
//    }
//}
//
//// MARK: - Draggable / zoomable text item view
//
//private struct VideoTextItemView: View {
//    @ObservedObject var model: VideoTextEditorModel
//    let item: VideoTextItem
//    let canvasFrame: CGRect
//
//    private var isSelected: Bool { model.selectedID == item.id }
//
//    var body: some View {
//        Text(item.text.isEmpty ? "Tap to edit" : item.text)
//            .font(.system(size: item.fontSize, weight: .bold))
//            .foregroundStyle(item.color)
//            .padding(.horizontal, 10)
//            .padding(.vertical, 6)
//            .background(
//                RoundedRectangle(cornerRadius: 6)
//                    .fill(Color.black.opacity(isSelected ? 0.18 : 0))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 6)
//                    .strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
//            )
//            .position(item.position)
//            .gesture(dragGesture.simultaneously(with: zoomGesture))
//            .onTapGesture { model.select(item.id) }
//            .frame(width: canvasFrame.width, height: canvasFrame.height, alignment: .topLeading)
//            .allowsHitTesting(true)
//    }
//
//    private var dragGesture: some Gesture {
//        DragGesture(minimumDistance: 0)
//            .onChanged { value in
//                model.select(item.id)
//                if !model.isDragging { model.beginDrag(for: item.id) }
//                model.drag(translation: value.translation,
//                           bounds: CGRect(origin: .zero, size: canvasFrame.size))
//            }
//            .onEnded { _ in model.endDrag() }
//    }
//
//    private var zoomGesture: some Gesture {
//        MagnificationGesture()
//            .onChanged { scale in
//                model.select(item.id)
//                if !model.isZooming { model.beginZoom(for: item.id) }
//                model.zoom(scale: scale)
//            }
//            .onEnded { _ in model.endZoom() }
//    }
//}
//
//// MARK: - Vertical hue color bar
//
//private struct VideoVerticalHueColorBar: View {
//    @Binding var selectedColor: Color
//
//    var body: some View {
//        GeometryReader { geo in
//            ZStack(alignment: .top) {
//                RoundedRectangle(cornerRadius: geo.size.width / 2)
//                    .fill(LinearGradient(colors: hueColors,
//                                         startPoint: .top,
//                                         endPoint: .bottom))
//
//                Circle()
//                    .fill(selectedColor)
//                    .frame(width: geo.size.width + 6, height: geo.size.width + 6)
//                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
//                    .shadow(color: .black.opacity(0.3), radius: 2)
//                    .position(x: geo.size.width / 2, y: handleY(in: geo.size))
//            }
//            .contentShape(Rectangle())
//            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
//                updateColor(atY: value.location.y, height: geo.size.height)
//            })
//        }
//    }
//
//    private var hueColors: [Color] {
//        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
//            Color(hue: $0, saturation: 0.9, brightness: 1.0)
//        }
//    }
//
//    private func handleY(in size: CGSize) -> CGFloat {
//        var hue: CGFloat = 0
//        UIColor(selectedColor).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
//        return hue * size.height
//    }
//
//    private func updateColor(atY y: CGFloat, height: CGFloat) {
//        guard height > 0 else { return }
//        let hue = min(max(y, 0), height) / height
//        selectedColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
//    }
//}
//
//// MARK: - Hidden keyboard input bridge (same pattern as image editor)
//
//private struct VideoHiddenTextInput: UIViewRepresentable {
//    @Binding var text: String
//    @Binding var isActive: Bool
//
//    func makeUIView(context: Context) -> UITextField {
//        let f = UITextField()
//        f.delegate = context.coordinator
//        f.returnKeyType = .done
//        f.isHidden = true
//        return f
//    }
//
//    func updateUIView(_ uiView: UITextField, context: Context) {
//        // Guard against UIKit↔SwiftUI feedback loop (AttributeGraph cycle).
//        if uiView.text != text { uiView.text = text }
//        if isActive, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
//        else if !isActive, uiView.isFirstResponder { uiView.resignFirstResponder() }
//    }
//
//    func makeCoordinator() -> Coordinator { Coordinator(self) }
//
//    final class Coordinator: NSObject, UITextFieldDelegate {
//        let parent: VideoHiddenTextInput
//        init(_ parent: VideoHiddenTextInput) { self.parent = parent }
//        func textFieldDidChangeSelection(_ tf: UITextField) { parent.text = tf.text ?? "" }
//        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.isActive = false; return true }
//    }
//}
//
//// MARK: - Model
//
//@MainActor
//final class VideoTextEditorModel: ObservableObject {
//
//    let videoURL: URL
//
//    @Published var thumbnail: UIImage?
//    @Published var textItems: [VideoTextItem] = []
//    @Published var selectedID: UUID?
//    @Published var isEditingText = false
//    @Published var isDragging = false
//    @Published var isZooming = false
//    @Published var isExporting = false
//    @Published var exportProgress: Double = 0
//    @Published var showExportError = false
//    @Published var exportErrorMessage = ""
//
//    private(set) var canvasFrame: CGRect = .zero
//    private var videoSize: CGSize = .zero   // post-transform display size (what the user sees)
//
//    private var dragStartPos: CGPoint = .zero
//    private var fontSizeAtZoomStart: CGFloat = 32
//    private var activeGestureID: UUID?
//
//    private let minFontSize: CGFloat = 12
//    private let maxFontSize: CGFloat = 160
//
//    private var exportTask: Task<Void, Never>?
//
//    init(videoURL: URL) {
//        self.videoURL = videoURL
//        Task { await loadThumbnailAndVideoSize() }
//    }
//
//    // MARK: Thumbnail + video size
//
//    private func loadThumbnailAndVideoSize() async {
//        let asset = AVURLAsset(url: videoURL)
//
//        // Get natural video size from the first video track
//        if let track = try? await asset.loadTracks(withMediaType: .video).first {
//            let size = (try? await track.load(.naturalSize)) ?? .zero
//            let transform = (try? await track.load(.preferredTransform)) ?? .identity
//            // Apply transform to get the display (rotated) size
//            let transformed = size.applying(transform)
//            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
//        }
//
//        // Generate thumbnail at 0.0 s
//        let generator = AVAssetImageGenerator(asset: asset)
//        generator.appliesPreferredTrackTransform = true
//        generator.maximumSize = CGSize(width: 1024, height: 1024)
//
//        let time = CMTime(seconds: 0, preferredTimescale: 600)
//        if let cgImage = try? await generator.image(at: time).image {
//            thumbnail = UIImage(cgImage: cgImage)
//        }
//    }
//
//    // MARK: Canvas layout (aspect-fit, same as image editor)
//
//    func fittedFrame(in containerSize: CGSize) -> CGRect {
//        let srcSize = videoSize.width > 0 ? videoSize : CGSize(width: 16, height: 9)
//        guard containerSize.width > 0, containerSize.height > 0 else {
//            return CGRect(origin: .zero, size: containerSize)
//        }
//        let aspect = srcSize.width / srcSize.height
//        let containerAspect = containerSize.width / containerSize.height
//        var size = containerSize
//        if aspect > containerAspect {
//            size.height = containerSize.width / aspect
//        } else {
//            size.width = containerSize.height * aspect
//        }
//        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
//                              y: (containerSize.height - size.height) / 2)
//        return CGRect(origin: origin, size: size)
//    }
//
//    func setupCanvas(in frame: CGRect) {
//        canvasFrame = frame
//    }
//
//    func rescaleCanvas(to newFrame: CGRect) {
//        let old = canvasFrame
//        guard old.width > 0, old.height > 0 else { canvasFrame = newFrame; return }
//        let sx = newFrame.width / old.width
//        let sy = newFrame.height / old.height
//        for i in textItems.indices {
//            textItems[i].position.x *= sx
//            textItems[i].position.y *= sy
//            textItems[i].fontSize *= (sx + sy) / 2
//        }
//        canvasFrame = newFrame
//    }
//
//    // MARK: Bindings for selected item
//
//    var selectedTextBinding: Binding<String> {
//        Binding(
//            get: { [weak self] in
//                guard let self, let id = selectedID,
//                      let item = textItems.first(where: { $0.id == id }) else { return "" }
//                return item.text
//            },
//            set: { [weak self] val in
//                guard let self, let id = selectedID else { return }
//                updateItem(id) { $0.text = val }
//            }
//        )
//    }
//
//    var selectedColorBinding: Binding<Color> {
//        Binding(
//            get: { [weak self] in
//                guard let self, let id = selectedID,
//                      let item = textItems.first(where: { $0.id == id }) else { return .white }
//                return item.color
//            },
//            set: { [weak self] val in
//                guard let self, let id = selectedID else { return }
//                updateItem(id) { $0.color = val }
//            }
//        )
//    }
//
//    private func updateItem(_ id: UUID, _ mutate: (inout VideoTextItem) -> Void) {
//        guard let i = textItems.firstIndex(where: { $0.id == id }) else { return }
//        mutate(&textItems[i])
//    }
//
//    // MARK: Text lifecycle
//
//    func addText() {
//        let offset = CGFloat(textItems.count % 5) * 18
//        let pos = CGPoint(x: canvasFrame.width / 2 + offset - 36,
//                           y: canvasFrame.height / 2 + offset - 36)
//        let item = VideoTextItem(text: "", position: pos)
//        textItems.append(item)
//        selectedID = item.id
//        isEditingText = true
//    }
//
//    func select(_ id: UUID) {
//        guard selectedID != id else { return }
//        selectedID = id
//    }
//
//    func removeSelectedText() {
//        guard let id = selectedID else { return }
//        textItems.removeAll { $0.id == id }
//        selectedID = nil
//        isEditingText = false
//    }
//
//    // MARK: Drag
//
//    func beginDrag(for id: UUID) {
//        activeGestureID = id
//        dragStartPos = textItems.first(where: { $0.id == id })?.position ?? .zero
//        isDragging = true
//    }
//
//    func drag(translation: CGSize, bounds: CGRect) {
//        guard let id = activeGestureID else { return }
//        let proposed = CGPoint(x: dragStartPos.x + translation.width,
//                                y: dragStartPos.y + translation.height)
//        let clamped = CGPoint(x: min(max(proposed.x, bounds.minX), bounds.maxX),
//                               y: min(max(proposed.y, bounds.minY), bounds.maxY))
//        updateItem(id) { $0.position = clamped }
//    }
//
//    func endDrag() {
//        isDragging = false
//        activeGestureID = nil
//    }
//
//    // MARK: Zoom
//
//    func beginZoom(for id: UUID) {
//        activeGestureID = id
//        fontSizeAtZoomStart = textItems.first(where: { $0.id == id })?.fontSize ?? 32
//        isZooming = true
//    }
//
//    func zoom(scale: CGFloat) {
//        guard let id = activeGestureID else { return }
//        let clamped = min(max(fontSizeAtZoomStart * scale, minFontSize), maxFontSize)
//        updateItem(id) { $0.fontSize = clamped }
//    }
//
//    func endZoom() {
//        isZooming = false
//        activeGestureID = nil
//    }
//
//    // MARK: Export
//
//    /// Burns all text items into every frame of the video using
//    /// AVVideoCompositionCoreAnimationTool and exports to a temp .mov file.
//    func exportVideo(completion: @escaping (URL?) -> Void) {
//        let items = textItems.filter { !$0.text.isEmpty }
//        guard !items.isEmpty else {
//            // Nothing to burn in — hand back the original URL unchanged.
//            completion(videoURL)
//            return
//        }
//
//        exportTask = Task {
//            isExporting = true
//            exportProgress = 0
//
//            do {
//                let url = try await VideoTextCompositor.export(
//                    videoURL: videoURL,
//                    textItems: items,
//                    canvasFrame: canvasFrame,
//                    videoSize: videoSize,
//                    progressHandler: { [weak self] p in
//                        Task { @MainActor in self?.exportProgress = p }
//                    }
//                )
//                isExporting = false
//                completion(url)
//            } catch {
//                isExporting = false
//                exportErrorMessage = error.localizedDescription
//                showExportError = true
//                completion(nil)
//            }
//        }
//    }
//}
//
//// MARK: - Video compositor (frame-by-frame AVAssetReader + AVAssetWriter)
////
//// Instead of AVVideoCompositionCoreAnimationTool (which crashes on rotated
//// videos due to renderSize / CA coordinate system mismatches), we read every
//// decoded video frame as a CVPixelBuffer, draw it into a CGContext, draw the
//// text on top with Core Graphics, then write the composited pixel buffer to a
//// new file with AVAssetWriter. Audio is copied untouched via a separate
//// AVAssetReaderTrackOutput. This approach is rotation-safe and crash-free.
//
//enum VideoTextCompositor {
//
//    static func export(
//        videoURL: URL,
//        textItems: [VideoTextItem],
//        canvasFrame: CGRect,     // on-screen display rect of the video (SwiftUI points)
//        videoSize: CGSize,       // display size (post-transform, what the user sees)
//        progressHandler: @escaping (Double) -> Void
//    ) async throws -> URL {
//        
//        
//        try await Self.exportSync(
//            videoURL: videoURL,
//            textItems: textItems,
//            canvasFrame: canvasFrame,
//            videoSize: videoSize,
//            progressHandler: progressHandler
//        )
//
//        // Run the entire pipeline off the main thread.
////        return try await Task.detached(priority: .userInitiated) {
////            try Self.exportSync(
////                videoURL: videoURL,
////                textItems: textItems,
////                canvasFrame: canvasFrame,
////                videoSize: videoSize,
////                progressHandler: progressHandler
////            )
////        }.value
//    }
//
//    // MARK: Synchronous pipeline (runs on a background thread via Task.detached)
//
//    private static func exportSync(
//        videoURL: URL,
//        textItems: [VideoTextItem],
//        canvasFrame: CGRect,
//        videoSize: CGSize,
//        progressHandler: (Double) -> Void
//    ) async throws -> URL {
//
//        let asset = AVURLAsset(url: videoURL)
//
//        // ── 1. Probe the video track synchronously ─────────────────────────────
//
//        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
//            throw CompositorError.noVideoTrack
//        }
//
//        let naturalSize  = videoTrack.naturalSize                // pre-rotation, e.g. 1920×1080
//        let transform    = videoTrack.preferredTransform         // rotation metadata
//        let nominalFR    = videoTrack.nominalFrameRate
//        let duration     = asset.duration
//
//        // The display size is the post-rotation size (what the thumbnail shows).
//        // We use it to map canvas-point positions → display-pixel → output-pixel.
//        let outputSize   = videoSize   // e.g. 1080×1920 for a portrait recording
//
//        // ── 2. Set up AVAssetReader ────────────────────────────────────────────
//
//        let reader = try AVAssetReader(asset: asset)
//
//        // Decode video frames into kCVPixelFormatType_32BGRA so we can wrap
//        // them in a CGContext directly without any pixel-format conversion.
//        let videoOutput = AVAssetReaderTrackOutput(
//            track: videoTrack,
//            outputSettings: [
//                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
//            ]
//        )
//        videoOutput.alwaysCopiesSampleData = false
//        reader.add(videoOutput)
//
//        // Audio: copy the compressed samples verbatim (nil outputSettings = passthrough).
//        var audioOutput: AVAssetReaderTrackOutput?
//        if let audioTrack = asset.tracks(withMediaType: .audio).first {
//            let ao = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
//            ao.alwaysCopiesSampleData = false
//            reader.add(ao)
//            audioOutput = ao
//        }
//
//        guard reader.startReading() else {
//            throw reader.error ?? CompositorError.readerFailed
//        }
//
//        // ── 3. Set up AVAssetWriter ────────────────────────────────────────────
//
//        let outputURL = FileManager.default.temporaryDirectory
//            .appendingPathComponent("video_text_\(UUID().uuidString).mov")
//        try? FileManager.default.removeItem(at: outputURL)
//
//        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
//
//        // Output video settings: H.264, same display size as the source.
//        let videoSettings: [String: Any] = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey:  Int(outputSize.width),
//            AVVideoHeightKey: Int(outputSize.height)
//        ]
//        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
//        videoInput.expectsMediaDataInRealTime = false
//        // Carry over the source transform so players rotate the output correctly.
//        // Since our CGContext already draws in display (post-rotation) coordinates,
//        // we clear the transform on the writer input — the output pixels are already
//        // in the right orientation.
//        videoInput.transform = .identity
//
//        // PixelBufferAdaptor: bridges CGContext output → AVAssetWriterInput.
//        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
//            assetWriterInput: videoInput,
//            sourcePixelBufferAttributes: [
//                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
//                kCVPixelBufferWidthKey  as String: Int(outputSize.width),
//                kCVPixelBufferHeightKey as String: Int(outputSize.height)
//            ]
//        )
//        writer.add(videoInput)
//
//        // Audio passthrough input (no re-encoding).
//        var audioInput: AVAssetWriterInput?
//        if audioOutput != nil {
//            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
//            ai.expectsMediaDataInRealTime = false
//            writer.add(ai)
//            audioInput = ai
//        }
//
//        guard writer.startWriting() else {
//            throw writer.error ?? CompositorError.writerFailed
//        }
//        writer.startSession(atSourceTime: .zero)
//
//        // ── 4. Pre-build text attributes (scaled to output pixel space) ────────
//
//        // Scale from canvas display-points → output pixels.
//        let scaleX = canvasFrame.width  > 0 ? outputSize.width  / canvasFrame.width  : 1
//        let scaleY = canvasFrame.height > 0 ? outputSize.height / canvasFrame.height : 1
//        let avgScale = (scaleX + scaleY) / 2
//
//        struct DrawItem {
//            let text: NSAttributedString
//            let center: CGPoint      // in output-pixel space (top-left origin)
//        }
//
//        let drawItems: [DrawItem] = textItems.compactMap { item in
//            guard !item.text.isEmpty else { return nil }
//            let fontSize = item.fontSize * avgScale
//            let attrs: [NSAttributedString.Key: Any] = [
//                .font: UIFont.boldSystemFont(ofSize: fontSize),
//                .foregroundColor: UIColor(item.color)
//            ]
//            let cx = item.position.x * scaleX
//            let cy = item.position.y * scaleY
//            return DrawItem(
//                text: NSAttributedString(string: item.text, attributes: attrs),
//                center: CGPoint(x: cx, y: cy)
//            )
//        }
//
//        // ── 5. Frame-by-frame compositing ─────────────────────────────────────
//        //
//        // For each decoded video frame:
//        //   a. Apply preferredTransform in a CGContext to rotate/flip the raw
//        //      (natural-orientation) pixel data into display orientation.
//        //   b. Draw text on top in display-coordinate space.
//        //   c. Extract the composited CGContext as a CVPixelBuffer.
//        //   d. Append to the writer via the adaptor.
//
//        let durationSeconds = CMTimeGetSeconds(duration)
//
//        // Reusable pixel buffer pool to avoid per-frame allocation.
//        var pixelBufferPool: CVPixelBufferPool?
//        let poolAttrs: [String: Any] = [
//            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
//            kCVPixelBufferWidthKey  as String: Int(outputSize.width),
//            kCVPixelBufferHeightKey as String: Int(outputSize.height)
//        ]
//        CVPixelBufferPoolCreate(nil, nil, poolAttrs as CFDictionary, &pixelBufferPool)
//
//        var frameCount = 0
//        let totalFrames = max(1, Int(durationSeconds * Double(nominalFR)))
//
//        while reader.status == .reading {
//            guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else { break }
//
//            guard let srcPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//                CMSampleBufferInvalidate(sampleBuffer)
//                continue
//            }
//
//            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//
//            // a. Lock the source pixel buffer for reading.
//            CVPixelBufferLockBaseAddress(srcPixelBuffer, .readOnly)
//
//            let srcWidth  = CVPixelBufferGetWidth(srcPixelBuffer)
//            let srcHeight = CVPixelBufferGetHeight(srcPixelBuffer)
//
//            // b. Create an output-sized pixel buffer from the pool.
//            var dstPixelBuffer: CVPixelBuffer?
//            if let pool = pixelBufferPool {
//                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstPixelBuffer)
//            } else {
//                CVPixelBufferCreate(
//                    nil,
//                    Int(outputSize.width), Int(outputSize.height),
//                    kCVPixelFormatType_32BGRA, nil,
//                    &dstPixelBuffer
//                )
//            }
//
//            guard let dst = dstPixelBuffer else {
//                CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
//                CMSampleBufferInvalidate(sampleBuffer)
//                continue
//            }
//
//            CVPixelBufferLockBaseAddress(dst, [])
//
//            // c. Create a CGContext backed by the destination pixel buffer.
//            let colorSpace = CGColorSpaceCreateDeviceRGB()
//            guard let ctx = CGContext(
//                data: CVPixelBufferGetBaseAddress(dst),
//                width:  Int(outputSize.width),
//                height: Int(outputSize.height),
//                bitsPerComponent: 8,
//                bytesPerRow: CVPixelBufferGetBytesPerRow(dst),
//                space: colorSpace,
//                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
//                           | CGBitmapInfo.byteOrder32Little.rawValue
//            ) else {
//                CVPixelBufferUnlockBaseAddress(dst, [])
//                CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
//                CMSampleBufferInvalidate(sampleBuffer)
//                continue
//            }
//
//            // d. Draw the source frame into the context, applying the rotation
//            //    transform so the output is in display (portrait/landscape) orientation.
//            //    CGContext has a flipped Y relative to UIKit, so we flip it first.
//            ctx.translateBy(x: 0, y: outputSize.height)
//            ctx.scaleBy(x: 1, y: -1)
//
//            // Apply the video's preferredTransform to rotate into display orientation.
//            // The transform origin in CA/AVFoundation is bottom-left of the natural frame;
//            // we need to adjust the translation so the rotated image stays in-bounds.
//            let adjustedTransform = normalizedTransform(
//                transform, naturalSize: CGSize(width: srcWidth, height: srcHeight)
//            )
//            ctx.concatenate(adjustedTransform)
//
//            // Draw the raw (natural-orientation) source frame.
//            if let srcImage = CGImage(
//                width: srcWidth, height: srcHeight,
//                bitsPerComponent: 8,
//                bitsPerPixel: 32,
//                bytesPerRow: CVPixelBufferGetBytesPerRow(srcPixelBuffer),
//                space: colorSpace,
//                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
//                                                 | CGBitmapInfo.byteOrder32Little.rawValue),
//                provider: CGDataProvider(
//                    dataInfo: nil,
//                    data: CVPixelBufferGetBaseAddress(srcPixelBuffer)!,
//                    size: CVPixelBufferGetBytesPerRow(srcPixelBuffer) * srcHeight,
//                    releaseData: { _, _, _ in }
//                )!,
//                decode: nil,
//                shouldInterpolate: false,
//                intent: .defaultIntent
//            ) {
//                ctx.draw(srcImage, in: CGRect(x: 0, y: 0,
//                                              width: CGFloat(srcWidth),
//                                              height: CGFloat(srcHeight)))
//            }
//
//            // e. Reset transform and draw text in display-coordinate space
//            //    (top-left origin after our initial Y-flip above).
//            ctx.concatenate(adjustedTransform.inverted())
//            ctx.translateBy(x: 0, y: outputSize.height)
//            ctx.scaleBy(x: 1, y: -1)   // back to UIKit top-left origin
//
//            for drawItem in drawItems {
//                let size = drawItem.text.size()
//                let origin = CGPoint(
//                    x: drawItem.center.x - size.width  / 2,
//                    y: drawItem.center.y - size.height / 2
//                )
//                drawItem.text.draw(at: origin)
//            }
//
//            CVPixelBufferUnlockBaseAddress(srcPixelBuffer, .readOnly)
//            CMSampleBufferInvalidate(sampleBuffer)
//
//            CVPixelBufferUnlockBaseAddress(dst, [])
//
//            // f. Wait until the writer input is ready, then append the frame.
//            while !videoInput.isReadyForMoreMediaData {
//                Thread.sleep(forTimeInterval: 0.005)
//            }
//            adaptor.append(dst, withPresentationTime: presentationTime)
//
//            frameCount += 1
//            progressHandler(min(Double(frameCount) / Double(totalFrames) * 0.9, 0.9))
//        }
//
//        // ── 6. Copy audio samples ──────────────────────────────────────────────
//
//        if let ao = audioOutput, let ai = audioInput {
//            while reader.status == .reading {
//                guard let sample = ao.copyNextSampleBuffer() else { break }
//                while !ai.isReadyForMoreMediaData {
//                    Thread.sleep(forTimeInterval: 0.005)
//                }
//                ai.append(sample)
//                CMSampleBufferInvalidate(sample)
//            }
//            ai.markAsFinished()
//        }
//
//        videoInput.markAsFinished()
//
//        // ── 7. Finish writing ──────────────────────────────────────────────────
//
//        await writer.finishWriting()
//        progressHandler(1.0)
//
//        if writer.status == .failed {
//            throw writer.error ?? CompositorError.writerFailed
//        }
//
//        return outputURL
//    }
//
//    // MARK: Transform helper
//    //
//    // AVFoundation's preferredTransform can include a large translation that
//    // compensates for the coordinate-system origin shifting during rotation.
//    // Strip that translation and rebuild it so the rotated image fits exactly
//    // inside the output rect (no clipping, no offset).
//
//    private static func normalizedTransform(
//        _ t: CGAffineTransform,
//        naturalSize: CGSize
//    ) -> CGAffineTransform {
//        // Rotation only (drop the translation).
//        var r = CGAffineTransform(a: t.a, b: t.b, c: t.c, d: t.d, tx: 0, ty: 0)
//
//        // After applying just the rotation, compute where the origin goes and
//        // add a corrective translation to bring it back to (0,0).
//        let origin = CGPoint.zero.applying(r)
//        let size   = naturalSize
//        let rotatedOrigin = CGPoint(
//            x: origin.x + (t.b < 0 ? size.width  * abs(t.b) : 0)
//                        + (t.a < 0 ? size.width  * abs(t.a) : 0),
//            y: origin.y + (t.c < 0 ? size.height * abs(t.c) : 0)
//                        + (t.d < 0 ? size.height * abs(t.d) : 0)
//        )
//        r.tx = -rotatedOrigin.x
//        r.ty = -rotatedOrigin.y
//        return r
//    }
//
//    // MARK: Errors
//
//    enum CompositorError: LocalizedError {
//        case noVideoTrack
//        case readerFailed
//        case writerFailed
//
//        var errorDescription: String? {
//            switch self {
//            case .noVideoTrack:  return "The video file has no video track."
//            case .readerFailed:  return "Could not read video frames."
//            case .writerFailed:  return "Could not write output video."
//            }
//        }
//    }
//}
//// MARK: - Preview
//
//#Preview {
//    VideoTextEditorPreviewHost()
//}
//
//struct VideoTextEditorPreviewHost: View {
//    
//    @State var resultUrl: URL?
//    var body: some View {
//        // Point this at any .mp4/.mov in your bundle for previewing.
//        
//        if let resultUrl {
//            VideoPlayer(player: AVPlayer(url: resultUrl))
//                .ignoresSafeArea()
//        }
//        else if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
//            VideoTextEditorView(videoURL: url) { result in
//                print("Exported to:", result?.path ?? "nil")
//                resultUrl = result
//            }
//        } else {
//            ZStack {
//                Color.black.ignoresSafeArea()
//                Text("Add a sample.mp4 to your bundle to preview")
//                    .foregroundStyle(.white)
//                    .multilineTextAlignment(.center)
//                    .padding()
//            }
//        }
//    }
//}
