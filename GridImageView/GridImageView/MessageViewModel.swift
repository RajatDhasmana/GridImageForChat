import Foundation
import Combine
import SwiftUI

// MARK: - Pagination State

enum PaginationState: Equatable {
    case idle
    case loadingInitial
    case loadingMore
    case loaded
    case exhausted       // no more pages
    case error(String)
}

// MARK: - MessageViewModel

@MainActor
final class MessageViewModel: ObservableObject {

    // MARK: Public state

    @Published private(set) var messageGroups: [MessageGroup] = []
    @Published private(set) var paginationState: PaginationState = .idle

    /// Per-message download states (used internally and by SingleMessageView)
    @Published private(set) var downloadStates: [String: DBMessage.DownloadState] = [:]

    /// Unified per-collage download state keyed by CollageMessage.id
    /// CollageMessageView reads only this — never the per-message map.
    @Published private(set) var collageDownloadStates: [String: CollageDownloadState] = [:]

    // MARK: Private

    private let conversationID: String
    private let currentUserID: String
    private let repository: MessageRepositoryProtocol
    private let downloader: MediaDownloaderProtocol

    private var allMessages: [String: DBMessage] = [:]   // id → DBMessage (source of truth)
    private var currentPage = 0
    private let pageSize = 30
    private var cancellables = Set<AnyCancellable>()
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    // Simulated "incoming message" stream — replace with your WebSocket/push publisher
    private var incomingMessageSubject = PassthroughSubject<DBMessage, Never>()
    var incomingMessagePublisher: AnyPublisher<DBMessage, Never> {
        incomingMessageSubject.eraseToAnyPublisher()
    }

    // MARK: Init

    init(
        conversationID: String,
        currentUserID: String,
        repository: MessageRepositoryProtocol = MockMessageRepository(),
        downloader: MediaDownloaderProtocol = MockMediaDownloader()
    ) {
        self.conversationID = conversationID
        self.currentUserID  = currentUserID
        self.repository     = repository
        self.downloader     = downloader

        subscribeToIncoming()
    }

    // MARK: - Load

    /// Initial load — called when the view appears
    func loadInitial() async {
        guard paginationState == .idle else { return }
        paginationState = .loadingInitial
        currentPage = 0
        allMessages  = [:]

        do {
            let page = try await repository.fetchMessages(
                conversationID: conversationID,
                page: currentPage,
                pageSize: pageSize
            )
            store(page)
            currentPage += 1
            paginationState = page.count < pageSize ? .exhausted : .loaded
            rebuildGroups()
            startDownloadsForPendingMedia()
        } catch {
            paginationState = .error(error.localizedDescription)
        }
    }

    /// Called when user scrolls to top — fetch older messages
    func loadMoreIfNeeded() async {
        guard paginationState == .loaded else { return }
        paginationState = .loadingMore

        do {
            let page = try await repository.fetchMessages(
                conversationID: conversationID,
                page: currentPage,
                pageSize: pageSize
            )
            store(page)
            currentPage += 1
            paginationState = page.count < pageSize ? .exhausted : .loaded
            rebuildGroups()
            startDownloadsForPendingMedia()
        } catch {
            paginationState = .error(error.localizedDescription)
        }
    }

    // MARK: - Incoming real-time messages

    /// Call this from your WebSocket / push notification handler
    func receive(incomingMessage: DBMessage) {
        incomingMessageSubject.send(incomingMessage)
    }

    private func subscribeToIncoming() {
        incomingMessageSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.store([msg])
                self.rebuildGroups()
                if msg.isMedia { self.startDownload(for: msg) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Download management

    func startDownloadsForPendingMedia() {
        let pending = allMessages.values.filter {
            $0.isMedia && $0.downloadState == .notStarted
        }
        pending.forEach { startDownload(for: $0) }
    }

    private func startDownload(for message: DBMessage) {
        guard downloadTasks[message.id] == nil else { return }
        guard let url = message.mediaURL else { return }

        updateDownloadState(.downloading(progress: 0), for: message.id)

        downloadTasks[message.id] = Task {
            do {
                for try await event in downloader.download(url: url, messageID: message.id) {
                    switch event {
                    case .progress(let p):
                        updateDownloadState(.downloading(progress: p), for: message.id)
                    case .completed(let localURL):
                        updateDownloadState(.downloaded(localURL: localURL), for: message.id)
                        downloadTasks[message.id] = nil
                    }
                }
            } catch {
                updateDownloadState(.failed, for: message.id)
                downloadTasks[message.id] = nil
            }
        }
    }

    private func updateDownloadState(_ state: DBMessage.DownloadState, for id: String) {
        downloadStates[id] = state
        allMessages[id]?.downloadState = state
        rebuildGroups()
    }

    // MARK: - Helpers

    private func store(_ messages: [DBMessage]) {
        messages.forEach { allMessages[$0.id] = $0 }
    }

    private func rebuildGroups() {
        messageGroups = MessageGrouper.group(
            messages: Array(allMessages.values),
            currentUserID: currentUserID
        )
        recomputeCollageStates()
    }

    /// Walk every CollageMessage in the current groups and derive its
    /// unified CollageDownloadState from the latest per-message map.
    private func recomputeCollageStates() {
        var updated: [String: CollageDownloadState] = [:]
        for group in messageGroups {
            for item in group.messageItems {
                guard let collage = item as? CollageMessage else { continue }
                updated[collage.id] = collage.aggregatedDownloadState(from: downloadStates)
            }
        }
        collageDownloadStates = updated
    }
}

// MARK: - Repository Protocol + Mock

protocol MessageRepositoryProtocol {
    func fetchMessages(conversationID: String, page: Int, pageSize: Int) async throws -> [DBMessage]
}

/// Mock that generates fake paginated data with a mix of text and media messages
final class MockMessageRepository: MessageRepositoryProtocol {

    private static let senders = [
        ("user_alice", "Alice"),
        ("user_bob",   "Bob"),
        ("user_carol", "Carol"),
    ]

    func fetchMessages(conversationID: String, page: Int, pageSize: Int) async throws -> [DBMessage] {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 800_000_000)

        // 3 pages of data
        guard page < 3 else { return [] }

        let baseIndex = page * pageSize
        let now = Date()
        var msgs: [DBMessage] = []

        for i in 0 ..< pageSize {
            let idx    = baseIndex + i
            let sender = Self.senders[idx % Self.senders.count]
            // Spread messages across 3 days
            let age    = TimeInterval(-(pageSize * 3 - idx) * 120) // 2 min apart
            let date   = now.addingTimeInterval(age)

            // Every 4th and 5th consecutive same-sender messages → media burst
            let isMedia = (i % 7 == 3 || i % 7 == 4 || i % 7 == 5)

            msgs.append(DBMessage(
                id: "msg_\(conversationID)_\(idx)",
                conversationID: conversationID,
                senderID: sender.0,
                senderName: sender.1,
                text: isMedia ? nil : sampleText(idx),
                timestamp: date,
                type: isMedia ? .image : .text,
                mediaURL: isMedia ? URL(string: "https://picsum.photos/seed/\(idx)/400/400") : nil,
                downloadState: .notStarted
            ))
        }
        return msgs
    }

    private func sampleText(_ idx: Int) -> String {
        let samples = [
            "Hey, how are things going?",
            "Just finished the new designs 🎨",
            "Can you review the PR when you get a chance?",
            "Looks great, shipping it tomorrow!",
            "What time is the stand-up?",
            "Check out these photos from yesterday",
            "The client loved the presentation 🙌",
        ]
        return samples[idx % samples.count]
    }
}

// MARK: - Downloader Protocol + Mock

enum DownloadEvent {
    case progress(Double)
    case completed(URL)
}

protocol MediaDownloaderProtocol {
    func download(url: URL, messageID: String) -> AsyncThrowingStream<DownloadEvent, Error>
}

final class MockMediaDownloader: MediaDownloaderProtocol {
    func download(url: URL, messageID: String) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Simulate incremental progress
                for step in 1...10 {
                    try await Task.sleep(nanoseconds: 150_000_000)
                    continuation.yield(.progress(Double(step) / 10.0))
                }
                // "Downloaded" — in real app use URLSession download task
                let fakeLocal = URL(string: "file:///cache/\(messageID).jpg")!
                continuation.yield(.completed(fakeLocal))
                continuation.finish()
            }
        }
    }
}
