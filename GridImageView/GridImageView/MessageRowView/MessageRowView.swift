//
//  MessageRowView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 20/12/25.
//

import SwiftUI

struct MessageRowView: View {
    
    var listMessage: ListItemType

    var body: some View {
        HStack {
            if listMessage.messageDirection == .outgoing {
                Spacer()
            }

            
            switch listMessage {
                
            case .normal(let message):
                normalMessageView(message: message)
            case .collage(let array):
                let imageUrlArray = array.compactMap({$0.imageUrl})
                ImageGridView(viewModel: ImageGridViewModel(imagesUrl: imageUrlArray, rows: 2, column: 2))
            }
            
            
//            Text(message.content)
//                .padding(10)
//                .foregroundColor(message.isCurrentUser ? .white : .black)
//                .background(message.isCurrentUser ? Color.blue : Color(UIColor.systemGray5))
//                .cornerRadius(10)

            if listMessage.messageDirection == .incoming {
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
    }
}

extension MessageRowView {
    
    @ViewBuilder
    private func normalMessageView(message: Message) -> some View {
        
        switch message.messageType {
        case .text(let text):
            Text(text)
        case .image(let imageUrl):
            AsyncImage(url: imageUrl)
        case .unknown:
            EmptyView()
        }
    }
}

#Preview {
    let message = Message(id: "1", text: "hello", messageDirection: .incoming)
    MessageRowView(listMessage: .normal(message))
}
