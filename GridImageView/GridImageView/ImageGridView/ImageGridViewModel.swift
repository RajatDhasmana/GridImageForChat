//
//  ImageGridViewModel.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 18/12/25.
//

import Foundation

protocol ImageGridViewModelProtocol {
    
    func getTotalRows() -> Int
    func getTotalColumn() -> Int
    func getImagesUrl() -> [URL]
    func getRemainingCount() -> Int?
    func addImageUrl(url: URL)
}

@Observable
class ImageGridViewModel : ImageGridViewModelProtocol {
    
    private var imagesUrl: [URL]
    private let rows: Int
    private let column: Int
    
    init(imagesUrl: [URL],
         rows: Int,
         column: Int) {
        self.imagesUrl = imagesUrl
        self.rows = rows
        self.column = column
    }
    
    
    func getTotalRows() -> Int {
        rows
    }
    
    func getTotalColumn() -> Int {
        column
    }
    
    func getImagesUrl() -> [URL] {
        imagesUrl
    }
    
    func getRemainingCount() -> Int? {
        
        if getImagesUrl().count > 4 {
            return getImagesUrl().count - 4
        } else {
            return nil
        }
    }
    
    func addImageUrl(url: URL) {
        
        imagesUrl.append(url)
    }
}
