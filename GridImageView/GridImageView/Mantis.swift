//
//  Mantis.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 26/06/26.
//

import Foundation

import SwiftUI
import PhotosUI


import SwiftUI
import PhotosUI

//struct ImagePicker: View {
//    @Binding var selectedImage: UIImage?
//    @State private var isImagePickerPresented = false
//
//    var body: some View {
//        VStack {
//            Button("Select Image") {
//                isImagePickerPresented.toggle()
//            }
//            .photosPicker(isPresented: $isImagePickerPresented, selection: $selectedImage, matching: .images)
//
//            if let image = selectedImage {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 300, height: 300)
//            }
//        }
//    }
//}

import SwiftUI
import PhotosUI

struct ImagePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var selectedItem: PhotosPickerItem? // Binding for PhotosPickerItem

    var body: some View {
        VStack {
            Button("Select Image") {
                isImagePickerPresented.toggle()
            }
            .photosPicker(isPresented: $isImagePickerPresented, selection: $selectedItem)

//            if let item = selectedItem {
//                // Load the image when the item is selected
//                item.loadTransferable(type: UIImage.self) { result in
//                    switch result {
//                    case .success(let image):
//                        selectedImage = image // Assign the loaded image to the binding
//                    case .failure(let error):
//                        print("Error loading image: \(error)")
//                    }
//                }
//            }
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            }
        }
    }
}



//struct ImagePicker: View {
//    @Binding var selectedImage: UIImage?
//    @State private var isImagePickerPresented = false
//
//    var body: some View {
//        VStack {
//            Button("Select Image") {
//                isImagePickerPresented.toggle()
//            }
//            .photosPicker(isPresented: $isImagePickerPresented) {
//                PhotosPickerItem(UIImage.self) { result in
//                    switch result {
//                    case .success(let item):
//                        item.loadTransferable(type: UIImage.self) { result in
//                            switch result {
//                            case .success(let image):
//                                selectedImage = image
//                            case .failure(let error):
//                                print("Error loading image: \(error)")
//                            }
//                        }
//                    case .failure(let error):
//                        print("Error picking image: \(error)")
//                    }
//                }
//            }
//            if let image = selectedImage {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 300, height: 300)
//            }
//        }
//    }
//}


struct CropView: View {
    @Binding var image: UIImage?
    @State private var cropRect: CGRect = CGRect(x: 50, y: 50, width: 200, height: 200)
    @State private var dragging = false

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .gesture(DragGesture()
                                .onChanged { value in
                                    if !dragging {
                                        cropRect.origin.x = min(max(value.location.x - cropRect.width / 2, 0), image.size.width - cropRect.width)
                                        cropRect.origin.y = min(max(value.location.y - cropRect.height / 2, 0), image.size.height - cropRect.height)
                                    }
                                }
                                .onEnded { _ in
                                    dragging = false
                                }
                            )
                    )
            }
        }
        .frame(height: 300)
    }
}


func cropImage(image: UIImage, cropRect: CGRect) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let scaledCropRect = CGRect(x: cropRect.origin.x * image.scale,
                                 y: cropRect.origin.y * image.scale,
                                 width: cropRect.width * image.scale,
                                 height: cropRect.height * image.scale)
    guard let croppedCGImage = cgImage.cropping(to: scaledCropRect) else { return nil }
    return UIImage(cgImage: croppedCGImage)
}


struct MantisView: View {
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?

    var body: some View {
        VStack {
            ImagePicker(selectedImage: $selectedImage)
            if let image = selectedImage {
                CropView(image: $selectedImage) // This is now correct
                Button("Crop Image") {
                    if let cropped = cropImage(image: image, cropRect: CGRect(x: 50, y: 50, width: 200, height: 200)) {
                        croppedImage = cropped
                    }
                }
                if let cropped = croppedImage {
                    Image(uiImage: cropped)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                }
            }
        }
        .padding()
    }
}
