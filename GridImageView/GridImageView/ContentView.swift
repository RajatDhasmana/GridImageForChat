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
//        VStack {
//            ChatMessageView()
//        }
        
        ChatView()
    }
}

#Preview {
    ContentView()
}
