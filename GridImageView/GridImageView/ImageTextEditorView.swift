//
//  ImageTextEditorView.swift
//
//  A SwiftUI view that takes a UIImage, lets the user add a text overlay,
//  drag it anywhere on the image, change its color via a draggable hue bar,
//  and on "Done" returns a new UIImage with the text composited onto it.
//
//  Usage:
//
//      ImageTextEditorView(image: myUIImage) { editedImage in
//          // editedImage: UIImage?
//      }
//
//  Requires: SwiftUI only (text is composited using Core Graphics /
//  UIGraphicsImageRenderer, both system frameworks).
//

import SwiftUI

// MARK: - Public View

struct ImageTextEditorView: View {

    let image: UIImage
    /// Called with the image with text composited onto it, or nil if rendering failed.
    let onComplete: (UIImage?) -> Void

    /// Optional: called if the user cancels.
    var onCancel: (() -> Void)? = nil

    @StateObject private var model: TextEditorModel

    init(image: UIImage, onCancel: (() -> Void)? = nil, onComplete: @escaping (UIImage?) -> Void) {
        self.image = image
        self.onCancel = onCancel
        self.onComplete = onComplete
        _model = StateObject(wrappedValue: TextEditorModel(image: image))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, max(geo.safeAreaInsets.top, 12))

                    Spacer(minLength: 0)

                    // The image canvas with the draggable text overlay.
                    GeometryReader { canvasGeo in
                        let fitted = model.fittedImageFrame(in: canvasGeo.size)

                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: fitted.width, height: fitted.height)
                                .position(x: fitted.midX, y: fitted.midY)
                                .onTapGesture {
                                    // Tapping the image dismisses the keyboard / color bar focus.
                                    model.isEditingText = false
                                }

                            if model.hasText {
                                DraggableTextView(model: model, canvasFrame: fitted)
                            }
                        }
                        .onAppear {
                            model.setupCanvas(in: fitted)
                        }
                        .onChange(of: canvasGeo.size) { _, newSize in
                            let newFitted = model.fittedImageFrame(in: newSize)
                            model.rescaleCanvas(to: newFitted)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)

                    bottomControls
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }
            }
        }
        // Hidden text field that drives keyboard text entry for the overlay.
        .background(
            HiddenTextInput(text: $model.text, isActive: $model.isEditingText)
        )
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
                let result = model.renderFinalImage()
                onComplete(result)
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Color bar only appears once there's text to color.
            if model.hasText {
                HueColorBar(selectedColor: $model.textColor)
                    .frame(height: 36)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 24) {
                Button {
                    if model.hasText {
                        model.isEditingText = true
                    } else {
                        model.addText()
                    }
                } label: {
                    Label(model.hasText ? "Edit Text" : "Add Text", systemImage: "textformat")
                        .foregroundStyle(.white)
                        .font(.callout.weight(.medium))
                }

                if model.hasText {
                    Button(role: .destructive) {
                        model.removeText()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .foregroundStyle(.white)
                            .font(.callout.weight(.medium))
                    }
                }
            }
        }
    }
}

// MARK: - Draggable text overlay

private struct DraggableTextView: View {
    @ObservedObject var model: TextEditorModel
    let canvasFrame: CGRect

    var body: some View {
        Text(model.text.isEmpty ? "Tap to edit" : model.text)
            .font(.system(size: model.fontSize, weight: .bold))
            .foregroundStyle(model.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                // Subtle scrim so text stays legible over any part of the photo,
                // visible only while actively dragging/editing, like most editors.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(model.isDraggingText ? 0.18 : 0))
            )
            .position(model.textPosition)
            .gesture(dragGesture)
            .onTapGesture {
                model.isEditingText = true
            }
            .frame(width: canvasFrame.width, height: canvasFrame.height, alignment: .topLeading)
            .allowsHitTesting(true)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !model.isDraggingText {
                    model.beginTextDrag()
                }
                model.dragText(translation: value.translation, bounds: CGRect(origin: .zero, size: canvasFrame.size))
            }
            .onEnded { _ in
                model.endTextDrag()
            }
    }
}

/// Invisible UITextField bridge so the keyboard can drive `model.text`.
/// SwiftUI's native TextField requires visible chrome; this keeps the
/// on-image Text as the only visible representation while still using
/// the system keyboard for input.
private struct HiddenTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.returnKeyType = .done
        field.isHidden = true // visually hidden; only used to summon the keyboard
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        if isActive, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isActive, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: HiddenTextInput
        init(_ parent: HiddenTextInput) { self.parent = parent }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.isActive = false
            return true
        }
    }
}

// MARK: - Draggable hue color bar

/// A horizontal gradient strip spanning the hue spectrum, with a draggable
/// handle. Dragging anywhere on the bar (not just the handle) updates the
/// selected color immediately, matching the Instagram/Snapchat-style text
/// color picker.
private struct HueColorBar: View {
    @Binding var selectedColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: geo.size.height / 2)
                    .fill(
                        LinearGradient(
                            colors: hueGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Circle()
                    .fill(selectedColor)
                    .frame(width: geo.size.height + 6, height: geo.size.height + 6)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: handleX(in: geo.size), y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateColor(atX: value.location.x, width: geo.size.width)
                    }
            )
        }
    }

    private var hueGradientColors: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 0.9, brightness: 1.0)
        }
    }

    /// Recovers the approximate hue of `selectedColor` to position the handle.
    private func handleX(in size: CGSize) -> CGFloat {
        var hue: CGFloat = 0
        UIColor(selectedColor).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue * size.width
    }

    private func updateColor(atX x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let clampedX = min(max(x, 0), width)
        let hue = clampedX / width
        selectedColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
    }
}

// MARK: - Model

@MainActor
final class TextEditorModel: ObservableObject {

    let image: UIImage

    /// Whether a text overlay currently exists on the canvas.
    @Published var hasText: Bool = false
    @Published var text: String = ""
    @Published var textColor: Color = .white
    @Published var fontSize: CGFloat = 32
    @Published var isEditingText: Bool = false
    @Published var isDraggingText: Bool = false

    /// Text position in the canvas's local coordinate space (points).
    @Published var textPosition: CGPoint = .zero

    private(set) var currentCanvasFrame: CGRect = .zero
    private var dragStartPosition: CGPoint = .zero

    init(image: UIImage) {
        self.image = image
    }

    // MARK: Layout (identical aspect-fit approach to the cropper view)

    func fittedImageFrame(in containerSize: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        var size = containerSize
        if imageAspect > containerAspect {
            size.width = containerSize.width
            size.height = containerSize.width / imageAspect
        } else {
            size.height = containerSize.height
            size.width = containerSize.height * imageAspect
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                              y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    func setupCanvas(in frame: CGRect) {
        currentCanvasFrame = frame
        if textPosition == .zero {
            textPosition = CGPoint(x: frame.width / 2, y: frame.height / 2)
        }
    }

    func rescaleCanvas(to newFrame: CGRect) {
        let old = currentCanvasFrame
        guard old.width > 0, old.height > 0 else {
            currentCanvasFrame = newFrame
            return
        }
        let sx = newFrame.width / old.width
        let sy = newFrame.height / old.height
        textPosition = CGPoint(x: textPosition.x * sx, y: textPosition.y * sy)
        fontSize *= (sx + sy) / 2
        currentCanvasFrame = newFrame
    }

    // MARK: Text lifecycle

    func addText() {
        hasText = true
        text = ""
        textPosition = CGPoint(x: currentCanvasFrame.width / 2, y: currentCanvasFrame.height / 2)
        isEditingText = true
    }

    func removeText() {
        hasText = false
        text = ""
        isEditingText = false
    }

    // MARK: Dragging (same translation-from-snapshot approach as the cropper,
    // to avoid the handle-moves-mid-gesture issue)

    func beginTextDrag() {
        dragStartPosition = textPosition
        isDraggingText = true
    }

    func endTextDrag() {
        isDraggingText = false
    }

    func dragText(translation: CGSize, bounds: CGRect) {
        let proposed = CGPoint(
            x: dragStartPosition.x + translation.width,
            y: dragStartPosition.y + translation.height
        )
        textPosition = CGPoint(
            x: min(max(proposed.x, bounds.minX), bounds.maxX),
            y: min(max(proposed.y, bounds.minY), bounds.maxY)
        )
    }

    // MARK: Rendering final image

    /// Composites the text onto the original image at full resolution and
    /// returns the result. Text position/size are scaled from the on-screen
    /// canvas (points) into the image's own pixel space.
    func renderFinalImage() -> UIImage? {
        guard hasText, !text.isEmpty else { return image }

        let frame = currentCanvasFrame
        guard frame.width > 0, frame.height > 0 else { return image }

        // UIImage.size is already in points, and UIGraphicsImageRenderer below
        // renders in that same point space — so we just need the ratio between
        // the image's point-size and the on-screen canvas's point-size.
        let scaleX = image.size.width / frame.width
        let scaleY = image.size.height / frame.height

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let scaledFontSize = fontSize * ((scaleX + scaleY) / 2)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: scaledFontSize),
                .foregroundColor: UIColor(textColor)
            ]

            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()

            let centerInImageSpace = CGPoint(x: textPosition.x * scaleX, y: textPosition.y * scaleY)
            let drawOrigin = CGPoint(
                x: centerInImageSpace.x - textSize.width / 2,
                y: centerInImageSpace.y - textSize.height / 2
            )

            attributedText.draw(at: drawOrigin)
        }

        return rendered
    }
}

// MARK: - Preview

#Preview {
    ImageTextEditorViewPreviewHost()
}

struct ImageTextEditorViewPreviewHost: View {
    @State private var resultImage: UIImage?

    var body: some View {
        if let img = UIImage(named: "dummyImage") {
            ImageTextEditorView(image: img) { edited in
                resultImage = edited
            }
        } else {
            Text("No preview image — add \"photo1\" to Assets.xcassets")
        }
    }
}
