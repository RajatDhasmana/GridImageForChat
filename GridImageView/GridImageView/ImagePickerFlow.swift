//
//  ImagePickerFlow.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 26/06/26.
//

import Foundation
import SwiftUICore
import UIKit
import SwiftUI

struct ImagePickerFlow: View {
    @State private var showPicker = false
    @State private var pickedImage: UIImage?
    @State private var showCropper = false
    @State private var croppedImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            if let croppedImage {
                Image(uiImage: croppedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
            }

            Button("Select Photo") {
                showPicker = true
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(selectedImage: $pickedImage)
        }
        // When an image is picked, trigger the cropper
        .onChange(of: pickedImage) { _, newValue in
            if newValue != nil {
                showCropper = true
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let pickedImage {
                ImageCropperView(image: pickedImage) { result in
                    croppedImage = result
                    showCropper = false
                    self.pickedImage = nil // reset for next pick
                }
            }
        }
    }
}

struct ImagePickerFlowSignal: View {
    @State private var showPicker = false
    @State private var pickedImage: UIImage?
    @State private var showCropper = false
    @State private var croppedImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            if let croppedImage {
                Image(uiImage: croppedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
            }

            Button("Select Photo") {
                showPicker = true
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(selectedImage: $pickedImage)
        }
        .onChange(of: pickedImage) { _, newValue in
            if newValue != nil {
                showCropper = true
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let pickedImage {
                ImageCropperViewSignal(image: pickedImage) { result in
                    croppedImage = result
                    showCropper = false
                    self.pickedImage = nil
                }
            }
        }
    }
}
