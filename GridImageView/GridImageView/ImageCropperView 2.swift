//
//  ImageCropperView.swift
//
//  An 8-handle (4 corners + 4 edge midpoints) draggable RECTANGULAR crop view
//  for SwiftUI. The crop region is always an axis-aligned CGRect — dragging a
//  corner resizes two sides at once (like Photos.app), dragging an edge
//  handle resizes just that one side. No perspective/skew is possible.
//
//  Usage:
//
//      ImageCropperView(image: myUIImage) { croppedImage in
//          // croppedImage: UIImage?
//      }
//
//  Requires: SwiftUI only (no CoreImage needed for a straight rect crop).
//

import SwiftUI

// MARK: - Public View

struct TextEditItem: Identifiable {
    
    var id: String
    var text: String
    var position: CGPoint
    var color: Color
}


struct ImageCropperViewNew: View {
    
    @State var textItems: [TextEditItem] = TextEditItem.dummyItems
    @StateObject private var model: CropModel = .init(image: UIImage(named: "dummyImage")!)
    
    @State var showPreview: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // The image + crop overlay, sized to fit available space.
                    GeometryReader { imageGeo in
                        let fitted = model.fittedImageFrame(in: imageGeo.size)
//                        let scale = fitted.width / model.rect.width
//                        let transform = CGAffineTransform.identity
//                            .translatedBy(x: -model.rect.minX, y: -model.rect.minY)
//                            .scaledBy(x: scale, y: scale)
                        
//                        let target = model.aspectFitFrame(in: imageGeo.size)
                            let scale = min(fitted.width / model.rect.width, fitted.height / model.rect.height)
                            let offsetX = fitted.midX - model.rect.midX * scale
                            let offsetY = fitted.midY - model.rect.midY * scale
                        
                        if showPreview {
                            
                            ZStack {
                                Image(uiImage: model.image)
                                    .resizable()
                                    .frame(width: fitted.width, height: fitted.height)

                                    .overlay {
                                        ForEach(textItems) { item in
                                            Text(item.text)
                                                .foregroundStyle(item.color)
                                                .position(item.position)
                                                    
                                        }
                                    }
                                .frame(width: fitted.width, height: fitted.height)
                            }
                            .mask(
                                Path { path in
                                    path.addRect(model.rect) // rect in the same local coordinate space
                                }
                            )
                            .scaleEffect(scale, anchor: .topLeading)
                            .offset(x: offsetX, y: offsetY)
                        } else {
                            
                            ZStack {
                                Image(uiImage: model.image)
                                    .resizable()
                                    .frame(width: fitted.width, height: fitted.height)

                                    .overlay {
                                        ForEach(textItems) { item in
                                            Text(item.text)
                                                .foregroundStyle(item.color)
                                                .position(item.position)
                                        }
                                    }
                                    .mask(
                                           Path { path in
                                               path.addRect(model.rect) // rect in the same local coordinate space
                                           }
                                       )
                                
                                CropOverlayNew(model: model, imageFrame: fitted)
                            }
                            .onAppear {
                                
                                print("fitted in else => \(fitted)")
                                model.setupInitialRect(in: fitted)
                            }
                            .onChange(of: imageGeo.size) { _, newSize in
                                // Re-fit on rotation / size change, preserving relative shape.
                                let newFitted = model.fittedImageFrame(in: newSize)
                                model.rescaleRect(to: newFitted)
                                print("on change imagegeo")
                            }
                        }
                    }
//                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)

                    controls
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }
                .onChange(of: model.rect) { oldValue, newValue in
                    print("new rect value => \(model.rect)")
                }

            }
        }
        .statusBarHidden(false)
    }

    private var controls: some View {
        HStack {
            Button {
//                onCancel?()
                print("cancel tapped")
            } label: {
                Text("Cancel")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Spacer()

            Button {
                model.resetRectToFullImage()
                showPreview = false
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Spacer()

            Button {
//                let result = model.performCrop()
//                onComplete(result)
                print("done tapped")
                showPreview = true
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Crop Overlay (the draggable rect + handles)

private struct CropOverlayNew: View {
    @ObservedObject var model: CropModel
    let imageFrame: CGRect

    var body: some View {
        ZStack {
            // Dimmed mask outside the rect
            CropMaskShape(rect: model.rect)
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            // Rect outline
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: model.rect.width, height: model.rect.height)
                .position(x: model.rect.midX, y: model.rect.midY)
                .allowsHitTesting(false)

            // Rule-of-thirds guide lines, only visible while dragging
            if model.isDragging {
                GridGuides(rect: model.rect)
                    .allowsHitTesting(false)
            }

            // Corner handles
            ForEach(CropModel.Corner.allCases, id: \.self) { corner in
                HandleView(isCorner: true)
                    .position(model.point(for: corner))
                    .gesture(dragGesture(for: corner))
            }

            // Edge (side) handles — midpoint of each edge
            ForEach(CropModel.Edge.allCases, id: \.self) { edge in
                HandleView(isCorner: false)
                    .position(model.midpoint(for: edge))
                    .gesture(dragGesture(for: edge))
            }
        }
        .frame(width: imageFrame.width, height: imageFrame.height)
        .position(x: imageFrame.midX, y: imageFrame.midY)
        .coordinateSpace(name: "cropSpace")
    }

    private func dragGesture(for corner: CropModel.Corner) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
            .onChanged { value in
                if !model.isDragging {
                    model.beginDrag()
                }
                model.dragCorner(corner, translation: value.translation, bounds: localBounds)
            }
            .onEnded { _ in
                model.endDrag()
            }
    }

    private func dragGesture(for edge: CropModel.Edge) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
            .onChanged { value in
                if !model.isDragging {
                    model.beginDrag()
                }
                model.dragEdge(edge, translation: value.translation, bounds: localBounds)
            }
            .onEnded { _ in
                model.endDrag()
            }
    }

    /// Bounds are local to the overlay's own coordinate space (0,0)-(width,height),
    /// since the overlay itself is positioned/sized to match imageFrame.
    private var localBounds: CGRect {
        CGRect(x: 0, y: 0, width: imageFrame.width, height: imageFrame.height)
    }
}

// MARK: - Handle visual

private struct HandleView: View {
    let isCorner: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: isCorner ? 22 : 18, height: isCorner ? 22 : 18)
                .shadow(color: .black.opacity(0.4), radius: 2)
            Circle()
                .fill(Color.accentColor)
                .frame(width: isCorner ? 10 : 8, height: isCorner ? 10 : 8)
        }
        // Enlarge the hit area beyond the visible circle for easier dragging.
        .contentShape(Circle().inset(by: -16))
        .frame(width: 44, height: 44)
    }
}

// MARK: - Shapes

/// Even-odd fill: outer rect minus inner crop rect = dimmed surround.
private struct CropMaskShape: Shape {
    let rect: CGRect
    func path(in bounds: CGRect) -> Path {
        var p = Path()
        p.addRect(bounds)
        p.addRect(rect)
        return p
    }
}

private struct GridGuides: View {
    let rect: CGRect
    var body: some View {
        Path { path in
            for t: CGFloat in [1.0/3.0, 2.0/3.0] {
                let x = rect.minX + rect.width * t
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            for t: CGFloat in [1.0/3.0, 2.0/3.0] {
                let y = rect.minY + rect.height * t
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.6), lineWidth: 0.75)
    }
}

// MARK: - Crop Model (state + logic)

@MainActor
final class CropModel: ObservableObject {

    enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }
    enum Edge: CaseIterable { case top, bottom, left, right }

    /// The single source of truth: an axis-aligned rect in the overlay's local
    /// coordinate space (0,0 at top-left of the displayed image, in points).
    @Published var rect: CGRect
    @Published var isDragging: Bool = false

    /// Snapshot of `rect` taken when a drag gesture begins. All deltas during
    /// that gesture are applied relative to this snapshot (via value.translation),
    /// rather than to the live, constantly-mutating `rect` — this avoids feedback
    /// where moving the handle mid-gesture shifts the gesture's own reference frame.
    private var dragStartRect: CGRect = .zero

    let image: UIImage
    /// The image frame (within the view) that `rect` coordinates are relative to.
    private(set) var currentImageFrame: CGRect = .zero

    private let inset: CGFloat = 24 // initial inset from image edges, in points
    private let minSize: CGFloat = 60 // minimum crop width/height, in points

    init(image: UIImage) {
        self.image = image
        self.rect = .zero
    }

    // MARK: Handle positions derived from rect

    func point(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func midpoint(for edge: Edge) -> CGPoint {
        switch edge {
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    // MARK: Layout

    /// Computes the rect (within `containerSize`) that the image occupies when
    /// aspect-fit, with origin relative to the container's own coordinate space.
    func fittedImageFrame(in containerSize: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        
        return CGRect(origin: .zero, size: containerSize)
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

    func setupInitialRect(in imageFrame: CGRect) {
        currentImageFrame = imageFrame
        resetRectToFullImage()
    }

    func resetRectToFullImage() {
        let f = currentImageFrame
        guard f.width > 0, f.height > 0 else { return }
        rect = currentImageFrame

        let dx = min(inset, f.width * 0.15)
        let dy = min(inset, f.height * 0.15)
        // rect is LOCAL to the overlay (sized to f.width x f.height),
        // so its coordinate space is (0,0)-(f.width, f.height).
//        rect = currentImageFrame
//        rect = CGRect(x: 0, y: 0, width: f.width, height: f.height)
//        rect = CGRect(x: dx, y: dy, width: f.width - dx * 2, height: f.height - dy * 2)
        print("rect from resetRectToFullImage => \(rect)")
    }

    /// Rescales the rect proportionally when the image frame changes size
    /// (e.g. on device rotation), preserving the user's relative crop shape.
    func rescaleRect(to newFrame: CGRect) {
        let old = currentImageFrame
        guard old.width > 0, old.height > 0 else {
            currentImageFrame = newFrame
            resetRectToFullImage()
            return
        }
        let sx = newFrame.width / old.width
        let sy = newFrame.height / old.height
        rect = CGRect(x: rect.minX * sx, y: rect.minY * sy,
                       width: rect.width * sx, height: rect.height * sy)
        currentImageFrame = newFrame
    }

    // MARK: Dragging — corners resize two sides at once, edges resize one side
    //
    // Drags are computed from `value.translation` (the cumulative offset from
    // the finger's down-location) applied to a snapshot of `rect` taken at
    // gesture start, rather than from `value.location` applied to the live
    // `rect`. This matters because the handle itself moves every time `rect`
    // changes, and if the handle's gesture re-reads its location against a
    // target that moved out from under it mid-gesture, drags can appear to
    // "stick" in one direction (e.g. dragging down works, but the reverse
    // drag back up reads an inconsistent location and gets immediately
    // re-clamped). Translation is computed once from the original touch-down
    // point and is unaffected by where the handle has since moved to.

    func beginDrag() {
        dragStartRect = rect
        isDragging = true
    }

    func endDrag() {
        isDragging = false
    }

    func dragCorner(_ corner: Corner, translation: CGSize, bounds: CGRect) {
        var minX = dragStartRect.minX, minY = dragStartRect.minY
        var maxX = dragStartRect.maxX, maxY = dragStartRect.maxY

        switch corner {
        case .topLeft:
            minX = clampValue(dragStartRect.minX + translation.width, min: bounds.minX, max: maxX - minSize)
            minY = clampValue(dragStartRect.minY + translation.height, min: bounds.minY, max: maxY - minSize)
        case .topRight:
            maxX = clampValue(dragStartRect.maxX + translation.width, min: minX + minSize, max: bounds.maxX)
            minY = clampValue(dragStartRect.minY + translation.height, min: bounds.minY, max: maxY - minSize)
        case .bottomLeft:
            minX = clampValue(dragStartRect.minX + translation.width, min: bounds.minX, max: maxX - minSize)
            maxY = clampValue(dragStartRect.maxY + translation.height, min: minY + minSize, max: bounds.maxY)
        case .bottomRight:
            maxX = clampValue(dragStartRect.maxX + translation.width, min: minX + minSize, max: bounds.maxX)
            maxY = clampValue(dragStartRect.maxY + translation.height, min: minY + minSize, max: bounds.maxY)
        }

        rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        print("rect from drag corner => \(rect)")

    }

    func dragEdge(_ edge: Edge, translation: CGSize, bounds: CGRect) {
        var minX = dragStartRect.minX, minY = dragStartRect.minY
        var maxX = dragStartRect.maxX, maxY = dragStartRect.maxY

        switch edge {
        case .top:
            minY = clampValue(dragStartRect.minY + translation.height, min: bounds.minY, max: maxY - minSize)
        case .bottom:
            maxY = clampValue(dragStartRect.maxY + translation.height, min: minY + minSize, max: bounds.maxY)
        case .left:
            minX = clampValue(dragStartRect.minX + translation.width, min: bounds.minX, max: maxX - minSize)
        case .right:
            maxX = clampValue(dragStartRect.maxX + translation.width, min: minX + minSize, max: bounds.maxX)
        }

        rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        print("rect from drag edge => \(rect)")

    }

    private func clampValue(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        // Guard against lo > hi (can happen transiently at minSize boundary).
        let safeHi = Swift.max(lo, hi)
        return Swift.max(lo, Swift.min(safeHi, v))
    }

    // MARK: Cropping

    /// Maps the on-screen rect (local overlay coords) into the UIImage's own
    /// pixel coordinate space and performs a plain rectangular crop.
//    func performCrop() -> UIImage? {
//        guard let cgImage = image.cgImage else { return nil }
//        let frame = currentImageFrame
//        guard frame.width > 0, frame.height > 0 else { return nil }
//
//        // Scale factor from displayed (point) coordinates to actual pixel coordinates.
//        let pixelWidth = CGFloat(cgImage.width)
//        let pixelHeight = CGFloat(cgImage.height)
//        let sx = pixelWidth / frame.width
//        let sy = pixelHeight / frame.height
//
//        var pixelRect = CGRect(
//            x: rect.minX * sx,
//            y: rect.minY * sy,
//            width: rect.width * sx,
//            height: rect.height * sy
//        )
//
//        // Clamp to image bounds and round to whole pixels to avoid edge artifacts.
//        pixelRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
//        pixelRect = pixelRect.integral
//
//        guard pixelRect.width > 0, pixelRect.height > 0,
//              let croppedCG = cgImage.cropping(to: pixelRect) else {
//            return nil
//        }
//
//        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
//    }
}

// MARK: - Preview

#Preview {
    ImageCropperViewPreviewHost()
}

struct ImageCropperViewPreviewHost: View {
    @State private var resultImage: UIImage?

    var body: some View {
        
//        ZStack {
//            if let img = UIImage(named: "dummyImage") {
//                ImageCropperViewNew(image: img) { cropped in
//                    resultImage = cropped
//                }
//            } else {
//                Text("No preview image")
//            }
//        }
        
        
        VStack {
            if let img = resultImage {
                resultView()
            } else {
                mainView()
            }

            
            
            Button {
                resultImage = nil
            } label: {
                Text("Undo")
            }

        }
//        .onChange(of: self.resultImage) { oldValue, newValue in
//            print("result image changed")
//        }
    }
}

extension ImageCropperViewPreviewHost {
    
    @ViewBuilder
    private func resultView() -> some View {
        
        if let img = resultImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
//                .frame(width: <#T##CGFloat?#>)
//                .frame(width: 300, height: 400)
            
        }
    }
    
    private func mainView() -> some View {
        
        ZStack {
            if let img = UIImage(named: "dummyImage") {
//                ImageCropperViewNew(image: img) { cropped in
//                    resultImage = cropped
//                }
                
                EmptyView()
            } else {
                Text("No preview image")
            }
        }
        
    }
}

extension TextEditItem {
    static var dummyItems: [TextEditItem] {
        [
            TextEditItem(
                id: "1",
                text: "Hello!",
                position: CGPoint(x: 100, y: 150),
                color: .red
            ),
            TextEditItem(
                id: "2",
                text: "Center Text",
                position: CGPoint(x: 180, y: 300),
                color: .red
            ),
            TextEditItem(
                id: "3",
                text: "Bottom Caption",
                position: CGPoint(x: 150, y: 500),
                color: .red
            ),
            TextEditItem(
                id: "4",
                text: "Edge Case",
                position: CGPoint(x: 20, y: 20), // near top-left corner — likely clipped
                color: .red
            ),
            TextEditItem(
                id: "5",
                text: "Far Right",
                position: CGPoint(x: 350, y: 200), // near right edge — likely clipped
                color: .green
            ),
            TextEditItem(
                id: "6",
                text: "🎉 Emoji Test 🎉",
                position: CGPoint(x: 150, y: 400),
                color: .orange
            ),
            TextEditItem(
                id: "7",
                text: "A very long line of text to test wrapping and bounds",
                position: CGPoint(x: 150, y: 250),
                color: .pink
            )
        ]
    }
}

extension CropModel {
    /// Aspect-fit frame for the *original image's* aspect ratio within a container —
    /// used only to decide where/how big the cropped preview should appear.
    func aspectFitFrame(in containerSize: CGSize) -> CGRect {
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
}
