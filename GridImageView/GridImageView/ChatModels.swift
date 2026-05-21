import Foundation
import SwiftUI

// MARK: - DBMessage

/// Raw message as it comes from the database
struct DBMessage: Identifiable, Equatable {
    let id: String
    let conversationID: String
    let senderID: String
    let senderName: String
    let text: String?
    let timestamp: Date
    let type: MessageType
    let mediaURL: URL?
    var downloadState: DownloadState

    enum MessageType: Equatable {
        case text
        case image
        case video
    }

    enum DownloadState: Equatable {
        case notStarted
        case downloading(progress: Double) // 0.0 – 1.0
        case downloaded(localURL: URL)
        case failed
    }

    var isMedia: Bool { type == .image || type == .video }

    static func == (lhs: DBMessage, rhs: DBMessage) -> Bool {
        lhs.id == rhs.id && lhs.downloadState == rhs.downloadState
    }
}

// MARK: - MessageItem Protocol

protocol MessageItem: Identifiable {
    var id: String { get }
    var messages: [DBMessage] { get }
    var timestamp: Date { get }   // Representative timestamp for sorting
    var isMine: Bool { get }
}

// MARK: - SingleMessage

struct SingleMessage: MessageItem {
    var id: String { messages[0].id }
    var messages: [DBMessage]
    var timestamp: Date { messages[0].timestamp }
    var isMine: Bool

    init(message: DBMessage, currentUserID: String) {
        self.messages = [message]
        self.isMine = message.senderID == currentUserID
    }
}

// MARK: - CollageDownloadState
//
// A single unified download state for the entire collage, aggregated
// from the individual per-message DownloadStates.
//
// Aggregation rules (evaluated in priority order):
//   • If ALL messages are downloaded              → .allDownloaded
//   • If ANY message is downloading               → .downloading(overallProgress)
//     where overallProgress = sum(each msg progress) / totalCount
//     (a not-started message contributes 0, a downloaded one contributes 1.0)
//   • If ALL are notStarted                       → .waiting
//   • If ANY failed and none still downloading    → .failed
//
enum CollageDownloadState: Equatable {
    case waiting                            // nothing started yet
    case downloading(progress: Double)      // 0.0 – 1.0 across ALL items
    case allDownloaded
    case failed
}

// MARK: - CollageMessage

/// Groups consecutive media messages from the same sender into a grid
struct CollageMessage: MessageItem {
    var id: String                      // Stable composite key
    var messages: [DBMessage]
    var timestamp: Date { messages.first?.timestamp ?? Date() }
    var isMine: Bool
    let senderID: String
    let senderName: String

    init(messages: [DBMessage], currentUserID: String) {
        precondition(!messages.isEmpty)
        self.messages   = messages
        self.senderID   = messages[0].senderID
        self.senderName = messages[0].senderName
        self.isMine     = messages[0].senderID == currentUserID
        self.id         = messages.map(\.id).joined(separator: "-")
    }

    /// Append a new media message to this collage (same sender, same day)
    mutating func append(_ message: DBMessage) {
        messages.append(message)
        id = messages.map(\.id).joined(separator: "-")
    }

    /// Layout grid: max 3 columns, variable rows
    var gridLayout: [[DBMessage]] {
        stride(from: 0, to: messages.count, by: 3).map {
            Array(messages[$0 ..< min($0 + 3, messages.count)])
        }
    }

    // MARK: Unified progress aggregation

    /// Derive a single CollageDownloadState from the latest per-message
    /// download states held by the ViewModel.
    func aggregatedDownloadState(
        from perMessageStates: [String: DBMessage.DownloadState]
    ) -> CollageDownloadState {
        let states = messages.map { perMessageStates[$0.id] ?? $0.downloadState }
        let total  = Double(states.count)

        // Tally up the contribution of each message toward overall progress.
        // notStarted = 0 %, downloading(p) = p %, downloaded = 100 %
        var sumProgress: Double = 0
        var anyDownloading = false
        var allDone        = true
        var anyFailed      = false

        for state in states {
            switch state {
            case .notStarted:
                allDone = false
                // sumProgress += 0
            case .downloading(let p):
                anyDownloading = true
                allDone        = false
                sumProgress   += p
            case .downloaded:
                sumProgress += 1.0
            case .failed:
                anyFailed = true
                allDone   = false
            }
        }

        if allDone            { return .allDownloaded }
        if anyDownloading     { return .downloading(progress: sumProgress / total) }
        if anyFailed          { return .failed }
        return .waiting
    }
}

// MARK: - MessageGroup

struct MessageGroup: Identifiable {
    let id: String              // date string used as stable ID
    let date: Date
    var messageItems: [any MessageItem]

    init(date: Date) {
        self.date = date
        self.id   = Self.dateKey(date)
        self.messageItems = []
    }

    static func dateKey(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
    }

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - Grouping Engine

/// Pure function: takes flat [DBMessage] → [MessageGroup]
/// Rules:
///   - Separate groups per calendar day
///   - Consecutive media messages from the same sender → CollageMessage
///   - Everything else → SingleMessage
///   - Groups sorted oldest-first; items within group sorted oldest-first
struct MessageGrouper {

    static func group(
        messages: [DBMessage],
        currentUserID: String
    ) -> [MessageGroup] {

        let sorted = messages.sorted { $0.timestamp < $1.timestamp }
        var groupMap: [String: MessageGroup] = [:]

        for msg in sorted {
            let key = MessageGroup.dateKey(msg.timestamp)
            if groupMap[key] == nil {
                groupMap[key] = MessageGroup(date: msg.timestamp)
            }
            insert(msg, into: &groupMap[key]!, currentUserID: currentUserID)
        }

        return groupMap.values
            .sorted { $0.date < $1.date }
    }

    // MARK: Private

    private static func insert(
        _ msg: DBMessage,
        into group: inout MessageGroup,
        currentUserID: String
    ) {
        // Try to append to the last item if it's a compatible collage
        if msg.isMedia,
           var lastCollage = group.messageItems.last as? CollageMessage,
           lastCollage.senderID == msg.senderID {
            lastCollage.append(msg)
            group.messageItems[group.messageItems.count - 1] = lastCollage
            return
        }

        // Start a new collage when current message is media and
        // previous item was NOT a collage from the same sender
        if msg.isMedia {
            let collage = CollageMessage(messages: [msg], currentUserID: currentUserID)
            group.messageItems.append(collage)
            return
        }

        // Plain text / other → SingleMessage
        let single = SingleMessage(message: msg, currentUserID: currentUserID)
        group.messageItems.append(single)
    }

    /// Merge a fresh page of (older) messages into existing groups.
    /// Returns the combined, re-sorted groups.
    static func merging(
        existing: [MessageGroup],
        with newMessages: [DBMessage],
        currentUserID: String
    ) -> [MessageGroup] {
        // Collect all DBMessages from current groups
        let existingMsgs: [DBMessage] = existing.flatMap { group in
            group.messageItems.flatMap(\.messages)
        }
        let merged = (existingMsgs + newMessages)
            .reduce(into: [String: DBMessage]()) { $0[$1.id] = $1 }  // deduplicate
            .values
        return group(messages: Array(merged), currentUserID: currentUserID)
    }
}
