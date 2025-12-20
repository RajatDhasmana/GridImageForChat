//
//  Models.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 20/12/25.
//

import Foundation



struct Message {
    var id: String
    var text: String?
    var imageUrl: URL?
    var messageDirection: MessageDirection
    var messageType: MessageType {
        
        if let text {
            return .text(text: text)
        } else if let imageUrl {
            return .image(imageUrl: imageUrl)
        } else {
            return .unknown
        }
    }
}
enum ListItemType {
    case normal(Message)
    case collage([Message])
    
    var id: String {
        switch self {
        case .normal(let message):
            return message.id
        case .collage(let array):
            return array.map { String($0.id) }.joined(separator: "")
        }
    }
    
    var messageDirection: MessageDirection {
        switch self {
        case .normal(let message):
            message.messageDirection
        case .collage(let array):
            array.first?.messageDirection ?? .incoming
        }
    }
    
}

enum MessageDirection {
    case incoming
    case outgoing
}

enum MessageType {
    
    case text(text: String)
    case image(imageUrl: URL)
    case unknown
}
