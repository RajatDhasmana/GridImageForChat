//
//  PaginationExample.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 06/01/26.
//

import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
}

struct ScrollPositionModel: Equatable {
    var id: UUID
    var position: ScrollPosition
    var animated: Bool = false
}

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    private var isLoading = false
    private var hasMore = true

    private var currentPage: Int = 0
    
    @Published var scrollToLast: Bool = false
    @Published var scrollToId: UUID?
    
    @Published var scrollPosition: ScrollPositionModel?
    @Published var isPaginating = false
    
    var hasUserScrolled: Bool = false
    
    init() {
//        loadInitialMessages()
    }

    func loadInitialMessages() {
        messages = generateMessages(count: 30)
        currentPage += 1
//        scrollToLast = true
        scrollToId = messages.last?.id
        if let lastMessage = messages.last {
            scrollPosition = ScrollPositionModel(id: lastMessage.id, position: .top)
        }
    }

    func loadMoreMessages() async {
        
        guard !isLoading, hasMore else { return }
        isLoading = true
//        scrollToId = messages.first?.id
        
        
//        if let firstMessage = messages.last {
//            scrollPosition = ScrollPositionModel(id: firstMessage.id, position: .bottom)
//        }

        try? await Task.sleep(nanoseconds: 700_000_00)

        let older = generateMessages(count: 20)

        if older.isEmpty {
            hasMore = false
        } else {
            if currentPage > 5 {
                hasMore = false
            } else {
//                if let id = messages.first?.id {
//                    scrollPosition?.id = id
//                }
             

                messages.insert(contentsOf: older, at: 0)
                currentPage += 1

            }
        }

        isLoading = false
    }

    private func generateMessages(count: Int) -> [ChatMessage] {
        guard let firstDate = messages.first?.timestamp ?? Date() as Date? else { return [] }

        return (0..<count).map { i in
            ChatMessage(
                id: UUID(),
                text: "Message \(Int.random(in: 0...999))",
                timestamp: firstDate.addingTimeInterval(TimeInterval(-60 * (i + 1)))
            )
        }
//        .reversed()
    }
}


struct ChatView: View {

    @StateObject private var vm = ChatViewModel()
    @State private var topVisibleMessageID: UUID?

    var body: some View {
        
        
        
        
//        MessageListView(chatViewModel: vm)
//            .onAppear {
//                
//                vm.loadInitialMessages()
//            }
        
        
        
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {

                    
                    ProgressView()
                        .onAppear {
                            
                            print("start pagination")
                            
                            guard vm.hasUserScrolled else { return }
                            
                            
                            if let firstMessage = vm.messages.first {
                                
//                                proxy.scrollTo(firstMessage.id, anchor: .bottom)
                                
                                vm.scrollPosition?.id = firstMessage.id

                                Task {
                                    await vm.loadMoreMessages()
                                }

                            }

                        }
                    
                    ForEach(vm.messages) { message in
                        Text(message.text)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .id(message.id)
//                            .onAppear {
//                                
//                                
////                                print("\(message.text) appeared")
//                                
//                                guard vm.hasUserScrolled else { return }
//                                
//                                
//                                if message == vm.messages.first {
//                                    topVisibleMessageID = message.id
//                                    Task {
//                                        
//                                        await vm.loadMoreMessages()
//                                        
//                                        proxy.scrollTo(message.id, anchor: .center)
//
////                                        DispatchQueue.main.async {
////                                            if let id = vm.scrollToId {
////                                                proxy.scrollTo(id, anchor: .bottom)
////                                            }
////                                        }
//
//                                        
////                                        if let id = vm.scrollToId {
////                                            proxy.scrollTo(id, anchor: .bottom)
////                                        }
//                                    }
//                                }
//                            }
                    }
                }
                .padding()
            }
            
            .onScrollPhaseChange { phase, _  in
                switch phase {
                case .interacting, .decelerating:
//                    isUserScrolling = true
                    vm.hasUserScrolled = true
                case .idle:
//                    isUserScrolling = false
                    vm.hasUserScrolled = false
                default:
                    break
                }
            }
            
            .onAppear {
                
                vm.loadInitialMessages()
            }
            
            .onChange(of: vm.scrollPosition) { oldValue, newValue in
                
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        
                    if let m = vm.messages.first(where: {$0.id == vm.scrollPosition?.id}) {
                            print("scroll to => \(m.text)")
                        }
                                  
                        proxy.scrollTo(vm.scrollPosition?.id, anchor: vm.scrollPosition?.position.unitPoint)
                }
            }
            
            
            
//            .onChange(of: vm.scrollToLast) { oldValue, newValue in
//                if newValue {
//                    if let last = vm.messages.last {
//                        proxy.scrollTo(last.id, anchor: .bottom)
//                        vm.scrollToLast = false
//                    }
//
//                }
//            }
        }
    }
}


enum ScrollPosition {
    
    case bottom, center, top, zero
    
    var unitPoint: UnitPoint {
        
        switch self {
        case .bottom:
                .bottom
        case .center:
                .center
        case .top:
                .top
        case .zero:
                .zero
        }
    }
    
}
