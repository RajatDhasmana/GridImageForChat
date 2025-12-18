//
//  ImageGridView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 18/12/25.
//

import SwiftUI

struct ImageGridView: View {
    
    @State var viewModel: ImageGridViewModelProtocol
    let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 2)
    
    var body: some View {
        
        
        VStack {
            
            LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                
                ForEach(viewModel.getImagesUrl().prefix(4).indices, id: \.self) { index in
                    
                    ZStack {
                                            
                        CustomImageView(imageUrl: viewModel.getImagesUrl()[index], index: index, totalImageCount: viewModel.getImagesUrl().count)
                        
                        if index == 3, let remainingCount = viewModel.getRemainingCount() {
                            Color.black
                                .opacity(0.4)
                            Text("+ \(remainingCount)")
                                .foregroundStyle(Color.white)
                        }
                    }
                }
            }
            .frame(maxWidth: getViewWidth(), maxHeight: getViewWidth())
            .padding()
            .background(Color.green)
            
            
            Button {
                let url1 = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
                viewModel.addImageUrl(url: url1)
            } label: {
                Text("Add")
            }

        }
        
       
    }
}

extension ImageGridView {
    
    private func getViewWidth() -> CGFloat {
        
        (getRect().width * 60) / 100
    }
    
    func getImageWidth(index: Int) -> CGFloat {

        let width = (getRect().width * 60) / 100
        let totalImageCount = viewModel.getImagesUrl().count
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
}


#Preview {
    
    let url1 = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
    let urls = [url1, url1, url1]
    let gridImagesViewModel = ImageGridViewModel(imagesUrl: urls, rows: 2, column: 2)
    
    ImageGridView(viewModel: gridImagesViewModel)
    
}
