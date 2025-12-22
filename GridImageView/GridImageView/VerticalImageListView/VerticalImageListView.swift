//
//  VerticalImageListView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 22/12/25.
//

import SwiftUI

struct VerticalImageListView: View {
    
    var messages: [Message]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    
                    Image("dummyImage")
                        .resizable()
                        .scaledToFit()

                    Divider()
                        .padding(.horizontal, 40)
                        .opacity(0.2)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    
    let message1 = Message(id: "1",
                           text: "hello", messageDirection: .incoming)
    let message2 = Message(id: "2",
                           text: "hi", messageDirection: .incoming)
    
    let url = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
    
    let message3 = Message(id: "3",
                           imageUrl: url, messageDirection: .incoming)
        
    VerticalImageListView(messages: [message1, message2, message3])
}
