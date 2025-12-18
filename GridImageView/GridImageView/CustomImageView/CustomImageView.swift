//
//  CustomImageView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 18/12/25.
//

import SwiftUI

struct CustomImageView: View {
    
    var imageUrl: URL
    var index: Int
    var totalImageCount: Int
//    var allImage
    
    var body: some View {
        
        ZStack {
            
            Image("dummyImage")
                .resizable()
                .clipped()
                .cornerRadius(12)
                .aspectRatio(contentMode: .fill)

            
//            if index <= 3 {
//                AsyncImage(url: imageUrl)
//                    .aspectRatio(contentMode: .fill)
//                    .cornerRadius(12)

//            }
            
        }
        .frame(width: getImageWidth(), height: getImageHeight())
        .clipped()
        .cornerRadius(12)
        .background(Color.blue)

    }
}

#Preview {
    CustomImageView(imageUrl: URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!, index: 1, totalImageCount: 3)
}

extension CustomImageView {
    
    func getImageWidth() -> CGFloat {

        let width = (getRect().width * 60) / 100
        
        if totalImageCount % 2 == 0 {
            return width / 2
        } else {
            if index == totalImageCount - 1 {
                return width
            } else {
                return width / 2
            }
        }
    }
    
    func getImageHeight() -> CGFloat {
        ((getRect().width * 60) / 100) / 2
    }
}

extension View {
    
    func getRect() -> CGRect {
        UIScreen.main.bounds
    }
}
