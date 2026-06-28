//
//  Signal.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 26/06/26.
//

import Foundation

import SwiftUI

// MARK: - Crop Region

enum CropRegion {
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
}

enum CropViewState {
    case initial   // no crop frame visible, background blackout
    case normal    // crop frame visible, grid hidden, background blurred
    case resizing  // crop frame + grid visible, background darkened
}

// MARK: - L-shaped Corner Handle

struct CropCornerShape: Shape {
    let region: CropRegion
    let cornerThickness: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let t = cornerThickness

        switch region {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + t))
            path.addLine(to: CGPoint(x: rect.minX + t, y: rect.minY + t))
            path.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + t))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + t, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - t))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - t))
            path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY - t))
            path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        default:
            break
        }
        return path
    }
}

struct CropCornerView: View {
    let region: CropRegion
    let size: CGFloat

    var body: some View {
        CropCornerShape(region: region)
            .fill(Color.white)
            .frame(width: size, height: size)
    }
}

// MARK: - Background with mask punch-out

struct CropBackgroundView: View {
    enum Style { case blur, darkening, blackout }

    let style: Style
    let cropRect: CGRect

    var body: some View {
        ZStack {
            switch style {
            case .blur:
                Rectangle().fill(.black.opacity(0.001)) // keep hit-testing consistent
                VisualEffectBlur(blurStyle: .dark)
            case .darkening:
                Color.black.opacity(0.5)
            case .blackout:
                Color.black
            }
        }
        .mask(
            Canvas { context, size in
                var path = Path(CGRect(origin: .zero, size: size))
                path.addPath(Path(cropRect))
                context.fill(path, with: .color(.black), style: FillStyle(eoFill: true))
            }
        )
        .animation(.easeInOut(duration: 0.15), value: cropRect)
        .allowsHitTesting(false)
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}



struct ImageCropperViewSignal: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // Crop frame, in screen points, lives within the container
    @State private var cropRect: CGRect = .zero
    @State private var containerSize: CGSize = .zero

    // Image transform
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var minScale: CGFloat = 1.0

    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero
    @GestureState private var resizeTranslation: CGSize = .zero
    @GestureState private var activeResizeRegion: CropRegion?

    @State private var viewState: CropViewState = .initial

    private let cornerSize: CGFloat = 24
    private let minCropDimension: CGFloat = 80
    private let edgeInset: CGFloat = 24 // margin from screen edges
    private let maxScaleMultiplier: CGFloat = 4.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let baseImageSize = aspectFillSize(for: image.size, in: cropRect.isEmpty ? CGSize(width: 300, height: 300) : cropRect.size)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: baseImageSize.width, height: baseImageSize.height)
                        .scaleEffect(scale * gestureScale)
                        .position(x: cropRect.midX + offset.width + gestureOffset.width,
                                  y: cropRect.midY + offset.height + gestureOffset.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .mask(
                    Rectangle()
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                )
                .contentShape(Rectangle())
                .gesture(panGesture(baseImageSize: baseImageSize))
                .gesture(zoomGesture(baseImageSize: baseImageSize))
                .onAppear {
                    containerSize = geo.size
                    setupInitialCrop(in: geo.size)
                }

                CropBackgroundView(style: backgroundStyle, cropRect: cropRect)

                cropFrameOverlay

                if viewState == .resizing {
                    gridLines
                }

                cornerHandles
                edgeHandles
            }

            controls
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewState = .normal
            }
        }
    }

    // MARK: - Setup

    private func setupInitialCrop(in size: CGSize) {
        let side = min(size.width, size.height) - edgeInset * 2
        cropRect = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
        minScale = 1.0
        scale = 1.0
        offset = .zero
    }

    // MARK: - Visual state

    private var backgroundStyle: CropBackgroundView.Style {
        switch viewState {
        case .initial: return .blackout
        case .normal: return .blur
        case .resizing: return .darkening
        }
    }

    private var cropFrameOverlay: some View {
        Rectangle()
            .strokeBorder(Color.white, lineWidth: 1)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .opacity(viewState == .initial ? 0 : 1)
            .allowsHitTesting(false)
    }

    private var gridLines: some View {
        Path { path in
            for i in 1..<3 {
                let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
                path.move(to: CGPoint(x: x, y: cropRect.minY))
                path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
                path.move(to: CGPoint(x: cropRect.minX, y: y))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - Corner Handles

    private var cornerHandles: some View {
        let actualCornerSize = min(cornerSize, min(cropRect.width, cropRect.height) * 0.5)
        return ZStack {
            cornerHandle(.topLeft, at: CGPoint(x: cropRect.minX, y: cropRect.minY), size: actualCornerSize)
            cornerHandle(.topRight, at: CGPoint(x: cropRect.maxX, y: cropRect.minY), size: actualCornerSize)
            cornerHandle(.bottomLeft, at: CGPoint(x: cropRect.minX, y: cropRect.maxY), size: actualCornerSize)
            cornerHandle(.bottomRight, at: CGPoint(x: cropRect.maxX, y: cropRect.maxY), size: actualCornerSize)
        }
    }

    private func cornerHandle(_ region: CropRegion, at point: CGPoint, size: CGFloat) -> some View {
        // Anchor each L-shape so its "inner" corner sits exactly on `point`
        let anchorOffset: CGPoint = {
            switch region {
            case .topLeft: return CGPoint(x: size / 2, y: size / 2)
            case .topRight: return CGPoint(x: -size / 2, y: size / 2)
            case .bottomLeft: return CGPoint(x: size / 2, y: -size / 2)
            case .bottomRight: return CGPoint(x: -size / 2, y: -size / 2)
            default: return .zero
            }
        }()

        return CropCornerView(region: region, size: size)
            .position(x: point.x + anchorOffset.x, y: point.y + anchorOffset.y)
            .contentShape(Rectangle().size(CGSize(width: size + 32, height: size + 32)).offset(x: -16, y: -16))
            .frame(width: size, height: size) // keeps layout tidy; hit area extended via contentShape below
            .position(x: point.x + anchorOffset.x, y: point.y + anchorOffset.y)
            .gesture(resizeGesture(for: region))
    }

    // MARK: - Edge Handles (invisible, wider hit targets for dragging a full side)

    private var edgeHandles: some View {
        ZStack {
            edgeHandle(.top)
            edgeHandle(.bottom)
            edgeHandle(.left)
            edgeHandle(.right)
        }
    }

    private func edgeHandle(_ region: CropRegion) -> some View {
        let hitWidth: CGFloat = 32
        let rect: CGRect
        switch region {
        case .top:
            rect = CGRect(x: cropRect.minX + cornerSize, y: cropRect.minY - hitWidth / 2,
                           width: cropRect.width - cornerSize * 2, height: hitWidth)
        case .bottom:
            rect = CGRect(x: cropRect.minX + cornerSize, y: cropRect.maxY - hitWidth / 2,
                           width: cropRect.width - cornerSize * 2, height: hitWidth)
        case .left:
            rect = CGRect(x: cropRect.minX - hitWidth / 2, y: cropRect.minY + cornerSize,
                           width: hitWidth, height: cropRect.height - cornerSize * 2)
        case .right:
            rect = CGRect(x: cropRect.maxX - hitWidth / 2, y: cropRect.minY + cornerSize,
                           width: hitWidth, height: cropRect.height - cornerSize * 2)
        default:
            rect = .zero
        }

        guard rect.width > 0, rect.height > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            Color.clear
                .contentShape(Rectangle())
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(resizeGesture(for: region))
        )
    }

    // MARK: - Resize Gesture (shared by corners + edges)

    private func resizeGesture(for region: CropRegion) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                if viewState != .resizing {
                    withAnimation(.easeInOut(duration: 0.15)) { viewState = .resizing }
                }
                cropRect = resizedRect(from: cropRect, region: region, translation: value.translation, in: containerSize)
            }
            .onEnded { value in
                withAnimation(.easeInOut(duration: 0.15)) { viewState = .normal }
                clampOffsetAfterCropChange()
            }
    }

    private func resizedRect(from rect: CGRect, region: CropRegion, translation: CGSize, in container: CGSize) -> CGRect {
        var r = rect
        let dx = translation.width
        let dy = translation.height

        switch region {
        case .topLeft:
            r.origin.x = min(rect.minX + dx, rect.maxX - minCropDimension)
            r.origin.y = min(rect.minY + dy, rect.maxY - minCropDimension)
            r.size.width = rect.maxX - r.origin.x
            r.size.height = rect.maxY - r.origin.y
        case .topRight:
            r.size.width = max(minCropDimension, rect.width + dx)
            r.origin.y = min(rect.minY + dy, rect.maxY - minCropDimension)
            r.size.height = rect.maxY - r.origin.y
        case .bottomLeft:
            r.origin.x = min(rect.minX + dx, rect.maxX - minCropDimension)
            r.size.width = rect.maxX - r.origin.x
            r.size.height = max(minCropDimension, rect.height + dy)
        case .bottomRight:
            r.size.width = max(minCropDimension, rect.width + dx)
            r.size.height = max(minCropDimension, rect.height + dy)
        case .top:
            r.origin.y = min(rect.minY + dy, rect.maxY - minCropDimension)
            r.size.height = rect.maxY - r.origin.y
        case .bottom:
            r.size.height = max(minCropDimension, rect.height + dy)
        case .left:
            r.origin.x = min(rect.minX + dx, rect.maxX - minCropDimension)
            r.size.width = rect.maxX - r.origin.x
        case .right:
            r.size.width = max(minCropDimension, rect.width + dx)
        }

        // Clamp to container bounds (with edge inset margin)
        let bounds = CGRect(x: edgeInset, y: edgeInset,
                             width: container.width - edgeInset * 2,
                             height: container.height - edgeInset * 2)

        r.origin.x = max(r.origin.x, bounds.minX)
        r.origin.y = max(r.origin.y, bounds.minY)
        if r.maxX > bounds.maxX { r.size.width = bounds.maxX - r.origin.x }
        if r.maxY > bounds.maxY { r.size.height = bounds.maxY - r.origin.y }

        return r
    }

    // MARK: - Pan / Zoom on image

    private func panGesture(baseImageSize: CGSize) -> some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                clampOffset(baseImageSize: baseImageSize)
            }
    }

    private func zoomGesture(baseImageSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale = min(max(scale * value, minScale), minScale * maxScaleMultiplier)
                clampOffset(baseImageSize: baseImageSize)
            }
    }

    /// Recomputes the image's base (cover) size for the *current* crop rect and
    /// re-clamps scale/offset so the image still fully covers the (possibly resized) frame.
    private func clampOffsetAfterCropChange() {
        let baseImageSize = aspectFillSize(for: image.size, in: cropRect.size)
        scale = max(scale, minScale)
        clampOffset(baseImageSize: baseImageSize)
    }

    private func clampOffset(baseImageSize: CGSize) {
        let scaledWidth = baseImageSize.width * scale
        let scaledHeight = baseImageSize.height * scale

        let maxOffsetX = max(0, (scaledWidth - cropRect.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropRect.height) / 2)

        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        let baseImageSize = aspectFillSize(for: image.size, in: cropRect.size)
        let pointsToPixels = image.size.width / baseImageSize.width

        let scaledWidth = baseImageSize.width * scale
        let scaledHeight = baseImageSize.height * scale

        // Image's top-left, relative to crop rect's top-left
        let imageOriginX = (cropRect.width - scaledWidth) / 2 + offset.width
        let imageOriginY = (cropRect.height - scaledHeight) / 2 + offset.height

        let cropXInScaledImage = -imageOriginX
        let cropYInScaledImage = -imageOriginY

        let pixelCropX = (cropXInScaledImage / scale) * pointsToPixels
        let pixelCropY = (cropYInScaledImage / scale) * pointsToPixels
        let pixelCropWidth = (cropRect.width / scale) * pointsToPixels
        let pixelCropHeight = (cropRect.height / scale) * pointsToPixels

        let pixelCropRect = CGRect(x: pixelCropX, y: pixelCropY, width: pixelCropWidth, height: pixelCropHeight)

        guard let cgImage = image.cgImage?.cropping(to: pixelCropRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func aspectFillSize(for imageSize: CGSize, in boundingSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let boundingAspect = boundingSize.width / boundingSize.height
        if imageAspect > boundingAspect {
            let height = boundingSize.height
            return CGSize(width: height * imageAspect, height: height)
        } else {
            let width = boundingSize.width
            return CGSize(width: width, height: width / imageAspect)
        }
    }

    private var controls: some View {
        VStack {
            Spacer()
            HStack {
                Button("Cancel") { dismiss() }.foregroundColor(.white)
                Spacer()
                Button("Done") { onComplete(cropImage()) }
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .padding()
        }
    }
}

private extension Path {
    func eoFilled(_ value: Bool) -> Path { self } // placeholder, see note below
}
