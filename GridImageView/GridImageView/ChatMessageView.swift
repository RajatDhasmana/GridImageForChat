//
//  ChatMessageView.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 20/12/25.
//

import SwiftUI

struct ChatMessageView: View {
    
    @State private var scrollPosition: UUID?
    
    @State var viewModel: ChatMessageViewModel = ChatMessageViewModel()
       
    var body: some View {
        
        
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List(viewModel.listMessages, id: \.id) { message in
                    
                    MessageRowView(listMessage: message)
                        .listRowSeparator(.hidden)
                        .id(message.id) // Assign ID for scrolling
                }
                .listStyle(PlainListStyle())
                .onChange(of: viewModel.listMessages.last?.id) { newId in
                    // Automatically scroll to the new message
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .bottom)
                    }
                }
            }
            
            
            Button {
//                let url1 = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
////                viewModel.addImageUrl(url: url1)
//                self.initiateMessageList()
                self.viewModel.didTapOnAddBtn()
            } label: {
                Text("Add")
            }
        }
    }
}

#Preview {
    ChatMessageView()
}


@Observable
class ChatMessageViewModel {
    
    private var messages: [Message] = []
    var listMessages: [ListItemType] = []
    var counter: Int = 0
    
    
    
    func incrementCounter() {
        counter += 1
    }
    
    
    private func initiateChat() {
        
        let message1 = Message(id: "1",
                               text: "hello", messageDirection: .incoming)
        let message2 = Message(id: "2",
                               text: "hi", messageDirection: .incoming)
        
        
        let url = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
        
        let message3 = Message(id: "3",
                               imageUrl: url, messageDirection: .incoming)

        self.messages = [message1, message2, message3]
//        self.messages.append(.normal(message1))
        self.listMessages = regroupMessages()
    }
    
    
    private func addTextMessage() {
        
        let id = UUID().uuidString
        let message = Message(id: id, text: "Rajat", messageDirection: .outgoing)
        self.messages.append(message)
        listMessages = regroupMessages()

    }
    
    
    private func addImage() {
        
        let id = UUID().uuidString
        let url = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
        let message = Message(id: id, imageUrl: url, messageDirection: .outgoing)

        self.messages.append(message)
        listMessages = regroupMessages()
    }
    
    private func addIncomingImage() {
        let id = UUID().uuidString
        let url = URL(string: "https://fastly.picsum.photos/id/821/200/300.jpg?hmac=-CLZlHMcIt8hXlUFZ4-3AvLYDsUJSwUeTri-zHDlnoA")!
        let message = Message(id: id, imageUrl: url, messageDirection: .incoming)

        self.messages.append(message)
        listMessages = regroupMessages()
        
    }
    
    private func regroupMessages() -> [ListItemType] {
        
        
        var resultList = [ListItemType]()
        var imageBuffer = [Message]()
        for message in self.messages {
            
            switch message.messageType {
                
            case .text(let text):
                flushImageBuffer()
                resultList.append(.normal(message))
            case .image(let imageUrl):
                
                if let firstBufferMessage = imageBuffer.first {
                    if firstBufferMessage.messageDirection == message.messageDirection {
                        imageBuffer.append(message)
                    } else {
                        flushImageBuffer()
                        imageBuffer.append(message)
                    }
                } else {
                    imageBuffer.append(message)
                }
                
            case .unknown:
                print("message type not found")
            }
        }
        flushImageBuffer()
        
        func flushImageBuffer() {
            
            if imageBuffer.count > 1 {
                resultList.append(.collage(imageBuffer))
            } else {
                
                if let msg = imageBuffer.first {
                    resultList.append(.normal(msg))
                }
            }
            imageBuffer.removeAll()
        }
        
        return resultList
        
    }
    
    func didTapOnAddBtn() {
        
        if counter <= 0 {
            initiateChat()
        } else if counter < 5 {
            addTextMessage()
        } else if counter >= 5, counter < 15 {
            addImage()
        } else if counter >= 15, counter < 20 {
            addIncomingImage()
        }
        else {
            addTextMessage()
        }
        
        counter += 1
    }
}
