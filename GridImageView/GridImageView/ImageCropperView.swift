//
//  ImageCropperView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 26/06/26.
//

import Foundation
import SwiftUI

//struct ImageCropperView: View

struct CropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.5)
                Rectangle()
                    .frame(width: cropSize, height: cropSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1)
                .frame(width: cropSize, height: cropSize)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
    }
}


//struct ImageCropperView: View {
//    let image: UIImage
//    let onComplete: (UIImage) -> Void
//
//    @Environment(\.dismiss) private var dismiss
//
//    @GestureState private var dragState: CGSize = .zero
//    @GestureState private var magnifyState: CGFloat = 1.0
//
//    @State private var offset: CGSize = .zero
//    @State private var scale: CGFloat = 1.0
//
//    private let cropSize: CGFloat = 300
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            imageLayer
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//            CropOverlay(cropSize: cropSize)
//                .allowsHitTesting(false) // critical: overlay must not block gestures
//
//            controls
//        }
//    }
//
//    private var imageLayer: some View {
//        Image(uiImage: image)
//            .resizable()
//            .scaledToFill()
//            .frame(width: cropSize, height: cropSize)
//            .scaleEffect(scale * magnifyState)
//            .offset(
//                x: offset.width + dragState.width,
//                y: offset.height + dragState.height
//            )
//            .contentShape(Rectangle()) // makes the whole frame draggable, not just where pixels are opaque
//            .gesture(dragGesture)
//            .gesture(magnificationGesture)
//        // Note: putting two separate .gesture() calls (not Simultaneous) on the SAME view
//        // actually composes them as simultaneous by default in SwiftUI when independent state is used.
//    }
//
//    private var dragGesture: some Gesture {
//        DragGesture()
//            .updating($dragState) { value, state, _ in
//                state = value.translation
//            }
//            .onEnded { value in
//                offset.width += value.translation.width
//                offset.height += value.translation.height
//            }
//    }
//
//    private var magnificationGesture: some Gesture {
//        MagnificationGesture()
//            .updating($magnifyState) { value, state, _ in
//                state = value
//            }
//            .onEnded { value in
//                scale = max(1.0, scale * value)
//            }
//    }
//
//    private var controls: some View {
//        VStack {
//            Spacer()
//            HStack {
//                Button("Cancel") { dismiss() }
//                    .foregroundColor(.white)
//                Spacer()
//                Button("Done") {
//                    onComplete(cropImage())
//                }
//                .foregroundColor(.white)
//                .fontWeight(.bold)
//            }
//            .padding()
//        }
//    }
//
//    private func cropImage() -> UIImage {
//        let aspectFillFrame = aspectFillFrame(for: image.size, in: CGSize(width: cropSize, height: cropSize))
//
//        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
//        return renderer.image { ctx in
//            ctx.cgContext.clip(to: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
//
//            let drawFrame = CGRect(
//                x: aspectFillFrame.origin.x + offset.width,
//                y: aspectFillFrame.origin.y + offset.height,
//                width: aspectFillFrame.width * scale,
//                height: aspectFillFrame.height * scale
//            )
//            image.draw(in: drawFrame)
//        }
//    }
//
//    private func aspectFillFrame(for imageSize: CGSize, in boundingSize: CGSize) -> CGRect {
//        let imageAspect = imageSize.width / imageSize.height
//        let boundingAspect = boundingSize.width / boundingSize.height
//
//        var size = boundingSize
//        if imageAspect > boundingAspect {
//            size.width = boundingSize.height * imageAspect
//        } else {
//            size.height = boundingSize.width / imageAspect
//        }
//
//        return CGRect(
//            x: (boundingSize.width - size.width) / 2,
//            y: (boundingSize.height - size.height) / 2,
//            width: size.width,
//            height: size.height
//        )
//    }
//}



//struct ImageCropperView: View {
//    let image: UIImage
//    let onComplete: (UIImage) -> Void
//
//    @Environment(\.dismiss) private var dismiss
//
//    @State private var imageFrame: CGRect = .zero   // where the image is drawn on screen
//    @State private var cropRect: CGRect = .zero     // current crop rectangle on screen
//
//    private let minCropSize: CGFloat = 60
//    private let handleSize: CGFloat = 24
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            GeometryReader { geo in
//                let displayFrame = aspectFitFrame(for: image.size, in: geo.size)
//
//                ZStack {
//                    Image(uiImage: image)
//                        .resizable()
//                        .frame(width: displayFrame.width, height: displayFrame.height)
//                        .position(x: displayFrame.midX, y: displayFrame.midY)
//
//                    // Dimmed area outside crop rect
//                    dimOverlay(containerSize: geo.size)
//
//                    // Crop rectangle border
//                    Rectangle()
//                        .strokeBorder(Color.white, lineWidth: 1)
//                        .frame(width: cropRect.width, height: cropRect.height)
//                        .position(x: cropRect.midX, y: cropRect.midY)
//
//                    // Grid lines (rule of thirds) — optional, nice touch
//                    gridLines
//
//                    // Move gesture on the crop area itself
//                    Rectangle()
//                        .fill(Color.clear)
//                        .frame(width: cropRect.width, height: cropRect.height)
//                        .position(x: cropRect.midX, y: cropRect.midY)
//                        .contentShape(Rectangle())
//                        .gesture(moveGesture(displayFrame: displayFrame))
//
//                    // Corner handles
//                    handles(displayFrame: displayFrame)
//                }
//                .coordinateSpace(name: "cropSpace")
//                .onAppear {
//                    imageFrame = displayFrame
//                    // Start crop rect as a centered square inset from the image
//                    let side = min(displayFrame.width, displayFrame.height) * 0.8
//                    cropRect = CGRect(
//                        x: displayFrame.midX - side / 2,
//                        y: displayFrame.midY - side / 2,
//                        width: side,
//                        height: side
//                    )
//                }
//            }
//
//            controls
//        }
//    }
//
//    // MARK: - Handles
//
//    private func handles(displayFrame: CGRect) -> some View {
//        ZStack {
//            handle(at: CGPoint(x: cropRect.minX, y: cropRect.minY), corner: .topLeft, displayFrame: displayFrame)
//            handle(at: CGPoint(x: cropRect.maxX, y: cropRect.minY), corner: .topRight, displayFrame: displayFrame)
//            handle(at: CGPoint(x: cropRect.minX, y: cropRect.maxY), corner: .bottomLeft, displayFrame: displayFrame)
//            handle(at: CGPoint(x: cropRect.maxX, y: cropRect.maxY), corner: .bottomRight, displayFrame: displayFrame)
//        }
//    }
//
//    private enum Corner {
//        case topLeft, topRight, bottomLeft, bottomRight
//    }
//
//    private func handle(at point: CGPoint, corner: Corner, displayFrame: CGRect) -> some View {
//        Circle()
//            .fill(Color.white)
//            .frame(width: handleSize, height: handleSize)
//            .position(point)
//            .contentShape(Circle().inset(by: -20)) // bigger invisible tap/drag target
//            .gesture(resizeGesture(corner: corner, displayFrame: displayFrame))
//    }
//
////    private func resizeGesture(corner: Corner, displayFrame: CGRect) -> some Gesture {
////        DragGesture()
////            .onChanged { value in
////                var newRect = cropRect
////                let loc = value.location
////
////                switch corner {
////                case .topLeft:
////                    newRect.origin.x = min(loc.x, cropRect.maxX - minCropSize)
////                    newRect.origin.y = min(loc.y, cropRect.maxY - minCropSize)
////                    newRect.size.width = cropRect.maxX - newRect.origin.x
////                    newRect.size.height = cropRect.maxY - newRect.origin.y
////                case .topRight:
////                    newRect.size.width = max(minCropSize, loc.x - cropRect.minX)
////                    newRect.origin.y = min(loc.y, cropRect.maxY - minCropSize)
////                    newRect.size.height = cropRect.maxY - newRect.origin.y
////                case .bottomLeft:
////                    newRect.origin.x = min(loc.x, cropRect.maxX - minCropSize)
////                    newRect.size.width = cropRect.maxX - newRect.origin.x
////                    newRect.size.height = max(minCropSize, loc.y - cropRect.minY)
////                case .bottomRight:
////                    newRect.size.width = max(minCropSize, loc.x - cropRect.minX)
////                    newRect.size.height = max(minCropSize, loc.y - cropRect.minY)
////                }
////
////                // Clamp to image bounds
////                cropRect = clamp(newRect, to: displayFrame)
////            }
////    }
//
////    private func moveGesture(displayFrame: CGRect) -> some Gesture {
////        DragGesture()
////            .onChanged { value in
////                var newRect = cropRect
////                newRect.origin.x += value.translation.width
////                newRect.origin.y += value.translation.height
////                cropRect = clamp(newRect, to: displayFrame, isMoveOnly: true)
////            }
////    }
//    
//    
//    
//    private func resizeGesture(corner: Corner, displayFrame: CGRect) -> some Gesture {
//        DragGesture(coordinateSpace: .named("cropSpace"))   // 👈
//            .onChanged { value in
//                var newRect = cropRect
//                let loc = value.location   // now in "cropSpace", matches cropRect's coordinates
//
//                switch corner {
//                case .topLeft:
//                    newRect.origin.x = min(loc.x, cropRect.maxX - minCropSize)
//                    newRect.origin.y = min(loc.y, cropRect.maxY - minCropSize)
//                    newRect.size.width = cropRect.maxX - newRect.origin.x
//                    newRect.size.height = cropRect.maxY - newRect.origin.y
//                case .topRight:
//                    newRect.size.width = max(minCropSize, loc.x - cropRect.minX)
//                    newRect.origin.y = min(loc.y, cropRect.maxY - minCropSize)
//                    newRect.size.height = cropRect.maxY - newRect.origin.y
//                case .bottomLeft:
//                    newRect.origin.x = min(loc.x, cropRect.maxX - minCropSize)
//                    newRect.size.width = cropRect.maxX - newRect.origin.x
//                    newRect.size.height = max(minCropSize, loc.y - cropRect.minY)
//                case .bottomRight:
//                    newRect.size.width = max(minCropSize, loc.x - cropRect.minX)
//                    newRect.size.height = max(minCropSize, loc.y - cropRect.minY)
//                }
//
//                cropRect = clamp(newRect, to: displayFrame)
//            }
//    }
//
//    private func moveGesture(displayFrame: CGRect) -> some Gesture {
//        DragGesture(coordinateSpace: .named("cropSpace"))   // 👈
//            .onChanged { value in
//                var newRect = cropRect
//                newRect.origin.x += value.translation.width
//                newRect.origin.y += value.translation.height
//                cropRect = clamp(newRect, to: displayFrame, isMoveOnly: true)
//            }
//    }
//
//    // Keep crop rect within the image's display frame
//    private func clamp(_ rect: CGRect, to bounds: CGRect, isMoveOnly: Bool = false) -> CGRect {
//        var r = rect
//
//        if isMoveOnly {
//            if r.minX < bounds.minX { r.origin.x = bounds.minX }
//            if r.minY < bounds.minY { r.origin.y = bounds.minY }
//            if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
//            if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
//        } else {
//            r.origin.x = max(r.origin.x, bounds.minX)
//            r.origin.y = max(r.origin.y, bounds.minY)
//            if r.maxX > bounds.maxX { r.size.width = bounds.maxX - r.origin.x }
//            if r.maxY > bounds.maxY { r.size.height = bounds.maxY - r.origin.y }
//        }
//
//        return r
//    }
//
//    // MARK: - Visuals
//
//    private func dimOverlay(containerSize: CGSize) -> some View {
//        Canvas { context, size in
//            var path = Rectangle().path(in: CGRect(origin: .zero, size: size))
//            let cropPath = Rectangle().path(in: cropRect)
//            path.addPath(cropPath)
//            context.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
//        }
//        .allowsHitTesting(false)
//    }
//
//    private var gridLines: some View {
//        Path { path in
//            for i in 1..<3 {
//                let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
//                path.move(to: CGPoint(x: x, y: cropRect.minY))
//                path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
//
//                let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
//                path.move(to: CGPoint(x: cropRect.minX, y: y))
//                path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
//            }
//        }
//        .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
//        .allowsHitTesting(false)
//    }
//
//    private var controls: some View {
//        VStack {
//            Spacer()
//            HStack {
//                Button("Cancel") { dismiss() }
//                    .foregroundColor(.white)
//                Spacer()
//                Button("Done") {
//                    onComplete(cropImage())
//                }
//                .foregroundColor(.white)
//                .fontWeight(.bold)
//            }
//            .padding()
//        }
//    }
//
//    // MARK: - Cropping
//
//    private func cropImage() -> UIImage {
//        // Map screen crop rect -> image pixel space
//        let scaleX = image.size.width / imageFrame.width
//        let scaleY = image.size.height / imageFrame.height
//
//        let cropX = (cropRect.minX - imageFrame.minX) * scaleX
//        let cropY = (cropRect.minY - imageFrame.minY) * scaleY
//        let cropW = cropRect.width * scaleX
//        let cropH = cropRect.height * scaleY
//
//        let pixelCropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
//
//        guard let cgImage = image.cgImage?.cropping(to: pixelCropRect) else {
//            return image
//        }
//
//        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
//    }
//
//    private func aspectFitFrame(for imageSize: CGSize, in boundingSize: CGSize) -> CGRect {
//        let imageAspect = imageSize.width / imageSize.height
//        let boundingAspect = boundingSize.width / boundingSize.height
//
//        var size = boundingSize
//        if imageAspect > boundingAspect {
//            size.height = boundingSize.width / imageAspect
//        } else {
//            size.width = boundingSize.height * imageAspect
//        }
//
//        return CGRect(
//            x: (boundingSize.width - size.width) / 2,
//            y: (boundingSize.height - size.height) / 2,
//            width: size.width,
//            height: size.height
//        )
//    }
//}





struct ImageCropperView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var minScale: CGFloat = 1.0

    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero

    private let cropSize: CGFloat = 300
    private let maxScaleMultiplier: CGFloat = 4.0 // how far past minScale user can zoom

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let containerSize = geo.size
                let baseImageSize = aspectFillSize(for: image.size, in: CGSize(width: cropSize, height: cropSize))

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: baseImageSize.width, height: baseImageSize.height)
                        .scaleEffect(scale * gestureScale)
                        .offset(
                            x: offset.width + gestureOffset.width,
                            y: offset.height + gestureOffset.height
                        )
                        .position(x: containerSize.width / 2, y: containerSize.height / 2)
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .clipped()
                .gesture(
                    DragGesture()
                        .updating($gestureOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            clampOffset(baseImageSize: baseImageSize, currentScale: scale)
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .updating($gestureScale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            let newScale = scale * value
                            scale = min(max(newScale, minScale), minScale * maxScaleMultiplier)
                            clampOffset(baseImageSize: baseImageSize, currentScale: scale)
                        }
                )
                .onAppear {
                    minScale = 1.0 // baseImageSize is already aspect-fill at scale 1
                    scale = minScale
                }
            }

            // Dimmed mask with clear crop window
            CropMaskOverlay(cropSize: cropSize)
                .allowsHitTesting(false)

            controls
        }
    }

    // MARK: - Clamping

    /// Keeps the image covering the crop square at all times — no gaps allowed.
    private func clampOffset(baseImageSize: CGSize, currentScale: CGFloat) {
        let scaledWidth = baseImageSize.width * currentScale
        let scaledHeight = baseImageSize.height * currentScale

        // Half the "slack" — how far the image can move before its edge enters the crop square
        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)

        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        let baseImageSize = aspectFillSize(for: image.size, in: CGSize(width: cropSize, height: cropSize))

        // Convert image's natural pixel size <-> displayed point size
        let pointsToPixels = image.size.width / baseImageSize.width

        let scaledWidth = baseImageSize.width * scale
        let scaledHeight = baseImageSize.height * scale

        // Top-left of the *scaled* image relative to the crop square's top-left,
        // given the image is centered in the crop square and then offset.
        let imageOriginX = (cropSize - scaledWidth) / 2 + offset.width
        let imageOriginY = (cropSize - scaledHeight) / 2 + offset.height

        // The crop square's top-left, in the scaled image's local coordinate space,
        // is just the negative of the image's origin (since crop square origin is 0,0).
        let cropXInScaledImage = -imageOriginX
        let cropYInScaledImage = -imageOriginY

        // Convert from "scaled image points" to "original image pixels"
        let pixelCropX = (cropXInScaledImage / scale) * pointsToPixels
        let pixelCropY = (cropYInScaledImage / scale) * pointsToPixels
        let pixelCropSize = (cropSize / scale) * pointsToPixels

        let pixelCropRect = CGRect(
            x: pixelCropX,
            y: pixelCropY,
            width: pixelCropSize,
            height: pixelCropSize
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelCropRect) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Geometry helpers

    /// Size that fills (covers) the bounding box while preserving aspect ratio — like .scaledToFill.
    private func aspectFillSize(for imageSize: CGSize, in boundingSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let boundingAspect = boundingSize.width / boundingSize.height

        if imageAspect > boundingAspect {
            // image is wider than the box -> match height, overflow width
            let height = boundingSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        } else {
            // image is taller than the box -> match width, overflow height
            let width = boundingSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private var controls: some View {
        VStack {
            Spacer()
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    onComplete(cropImage())
                }
                .foregroundColor(.white)
                .fontWeight(.bold)
            }
            .padding()
        }
    }
}

struct CropMaskOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                var path = Rectangle().path(in: CGRect(origin: .zero, size: size))
                let cropRect = CGRect(
                    x: (size.width - cropSize) / 2,
                    y: (size.height - cropSize) / 2,
                    width: cropSize,
                    height: cropSize
                )
                path.addPath(Rectangle().path(in: cropRect))
                context.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
            }

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1)
                .frame(width: cropSize, height: cropSize)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
    }
}
