//
//  ContentView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 18/12/25.
//

import SwiftUI

struct ContentView: View {
    
    let images = (1...6).map { "photo\($0)" }
    let columns = [GridItem(.adaptive(minimum: 10))]
    var body: some View {
        mainView()
    }
}

#Preview {
    ContentView()
}

extension ContentView {
    
    @ViewBuilder
    private func mainView() -> some View {
        
        let url1 = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
        let urls = [url1, url1, url1, url1]
        let gridImagesViewModel = ImageGridViewModel(imagesUrl: urls, rows: 2, column: 2)
        
        ImageGridView(viewModel: gridImagesViewModel)
    }
}
