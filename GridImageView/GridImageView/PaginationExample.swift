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

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    private var isLoading = false
    private var hasMore = true

    init() {
        loadInitialMessages()
    }

    func loadInitialMessages() {
        messages = generateMessages(count: 30)
    }

    func loadMoreMessages() async {
        guard !isLoading, hasMore else { return }
        isLoading = true

        try? await Task.sleep(nanoseconds: 700_000_000)

        let older = generateMessages(count: 20)

        if older.isEmpty {
            hasMore = false
        } else {
            messages.insert(contentsOf: older, at: 0)
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
        }.reversed()
    }
}


struct ChatView: View {

    @StateObject private var vm = ChatViewModel()
    @State private var topVisibleMessageID: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {

                    ForEach(vm.messages) { message in
                        Text(message.text)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .id(message.id)
                            .onAppear {
                                if message == vm.messages.first {
                                    topVisibleMessageID = message.id
                                    Task {
                                        await vm.loadMoreMessages()
                                        if let id = topVisibleMessageID {
                                            proxy.scrollTo(id, anchor: .top)
                                        }
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
            .onAppear {
                if let last = vm.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
