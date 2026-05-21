//
//  MentionTextfield.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 21/05/26.
//

import Foundation
import SwiftUI

// MARK: - Models

struct GroupMember: Identifiable, Hashable {
    let id: UUID
    let name: String
    let avatar: String // SF Symbol or initials
    let color: Color

    static let samples: [GroupMember] = [
        GroupMember(id: UUID(), name: "Alice Johnson",  avatar: "AJ", color: .blue),
        GroupMember(id: UUID(), name: "Bob Martinez",   avatar: "BM", color: .green),
        GroupMember(id: UUID(), name: "Carol White",    avatar: "CW", color: .purple),
        GroupMember(id: UUID(), name: "David Chen",     avatar: "DC", color: .orange),
        GroupMember(id: UUID(), name: "Emma Davis",     avatar: "ED", color: .pink),
        GroupMember(id: UUID(), name: "Frank Torres",   avatar: "FT", color: .teal),
    ]
}

// A segment of the composed message: either plain text or a tagged mention
enum MessageSegment: Identifiable, Equatable {
    case text(String)
    case mention(GroupMember)

    var id: String {
        switch self {
        case .text(let t): return "text-\(t)"
        case .mention(let m): return "mention-\(m.id)"
        }
    }
}

// MARK: - MentionTextView (UIViewRepresentable)

/// A UITextView wrapper that tracks `@` triggers and inserts
/// highlighted mention chips anywhere in the text.
struct MentionTextView: UIViewRepresentable {

    @Binding var segments: [MessageSegment]
    @Binding var mentionQuery: String?   // non-nil while user is typing after @
    var placeholder: String = "Message..."

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        tv.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        // Placeholder
        context.coordinator.applyPlaceholder(tv, placeholder: placeholder)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Rebuild attributed string from segments if driven externally
        // (e.g., after a mention is inserted by parent)
        guard context.coordinator.pendingSegmentUpdate else { return }
        context.coordinator.pendingSegmentUpdate = false

        let attr = buildAttributedString(from: segments)
        tv.attributedText = attr
        // Move cursor to end
        tv.selectedRange = NSRange(location: attr.length, length: 0)
        context.coordinator.syncSegmentsToText(tv)
    }

    // Build NSAttributedString from our segment model
    private func buildAttributedString(from segs: [MessageSegment]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for seg in segs {
            switch seg {
            case .text(let t):
                result.append(NSAttributedString(
                    string: t,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 16),
                        .foregroundColor: UIColor.label
                    ]
                ))
            case .mention(let m):
                let chip = mentionChip(for: m)
                result.append(chip)
            }
        }
        return result
    }

    /// Creates a styled mention chip as an NSAttributedString
    static func mentionChip(for member: GroupMember) -> NSAttributedString {
        let text = "@\(member.name)"
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.systemBlue,
                .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.12),
                // Custom attribute to identify mentions
                NSAttributedString.Key("mentionID"): member.id.uuidString
            ]
        )
    }

    func mentionChip(for member: GroupMember) -> NSAttributedString {
        MentionTextView.mentionChip(for: member)
    }

    // MARK: Coordinator

    class Coordinator: NSObject, UITextViewDelegate {

        var parent: MentionTextView
        var pendingSegmentUpdate = false

        // Track where the current @ trigger started
        var atTriggerLocation: Int? = nil

        init(parent: MentionTextView) {
            self.parent = parent
        }

        // MARK: Placeholder

        func applyPlaceholder(_ tv: UITextView, placeholder: String) {
            if tv.text.isEmpty {
                tv.text = placeholder
                tv.textColor = .placeholderText
            }
        }

        func removePlaceholderIfNeeded(_ tv: UITextView) {
            if tv.textColor == .placeholderText {
                tv.text = ""
                tv.textColor = .label
                tv.typingAttributes = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.label
                ]
            }
        }

        // MARK: UITextViewDelegate

        func textViewDidBeginEditing(_ textView: UITextView) {
            removePlaceholderIfNeeded(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                applyPlaceholder(textView, placeholder: parent.placeholder)
            }
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {

            removePlaceholderIfNeeded(textView)

            // Detect @ trigger
            if text == "@" {
                atTriggerLocation = range.location
            }

            // Detect deletion that removes the @ trigger start
            if text.isEmpty, let trigger = atTriggerLocation {
                if range.location < trigger {
                    atTriggerLocation = nil
                    DispatchQueue.main.async { self.parent.mentionQuery = nil }
                }
            }

            // Prevent editing inside a mention chip
            let attr = textView.attributedText ?? NSAttributedString()
            if range.length > 0 {
                var isMentionChip = false
                attr.enumerateAttribute(
                    NSAttributedString.Key("mentionID"),
                    in: range,
                    options: []
                ) { val, _, _ in
                    if val != nil { isMentionChip = true }
                }
                if isMentionChip {
                    // Delete the whole chip
                    let mutable = NSMutableAttributedString(attributedString: attr)
                    // Expand range to cover full chip
                    var chipRange = range
                    attr.enumerateAttribute(
                        NSAttributedString.Key("mentionID"),
                        in: NSRange(location: 0, length: attr.length),
                        options: []
                    ) { val, r, _ in
                        if val != nil && NSIntersectionRange(r, range).length > 0 {
                            chipRange = r
                        }
                    }
                    mutable.replaceCharacters(in: chipRange, with: "")
                    textView.attributedText = mutable
                    textView.selectedRange = NSRange(location: chipRange.location, length: 0)
                    syncSegmentsToText(textView)
                    DispatchQueue.main.async { self.parent.mentionQuery = nil }
                    return false
                }
            }

            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            updateMentionQuery(in: textView)
            syncSegmentsToText(textView)
        }

        // MARK: - Mention query detection

        private func updateMentionQuery(in textView: UITextView) {
            guard let attr = textView.attributedText else {
                parent.mentionQuery = nil; return
            }

            let cursorPos = textView.selectedRange.location
            let fullText = attr.string as NSString

            // Search backwards from cursor for @
            var found = false
            for i in stride(from: cursorPos - 1, through: 0, by: -1) {
                let ch = fullText.substring(with: NSRange(location: i, length: 1))
                if ch == "@" {
                    // Make sure this @ is not inside a mention chip
                    var isMention = false
                    attr.enumerateAttribute(
                        NSAttributedString.Key("mentionID"),
                        in: NSRange(location: i, length: 1),
                        options: []
                    ) { val, _, _ in if val != nil { isMention = true } }

                    if !isMention {
                        let query = fullText.substring(
                            with: NSRange(location: i + 1, length: cursorPos - i - 1)
                        )
                        // Only show popup if query has no spaces (single word)
                        if !query.contains(" ") && !query.contains("\n") {
                            atTriggerLocation = i
                            DispatchQueue.main.async { self.parent.mentionQuery = query }
                            found = true
                        }
                    }
                    break
                }
                // Stop at whitespace before reaching @
                let scalar = ch.unicodeScalars.first!
                if CharacterSet.whitespaces.union(.newlines).contains(scalar) { break }
            }

            if !found {
                atTriggerLocation = nil
                DispatchQueue.main.async { self.parent.mentionQuery = nil }
            }
        }

        // MARK: - Insert mention

        func insertMention(_ member: GroupMember, into textView: UITextView) {
            guard let triggerLoc = atTriggerLocation else { return }

            let attr = NSMutableAttributedString(
                attributedString: textView.attributedText ?? NSAttributedString()
            )
            let cursorPos = textView.selectedRange.location
            // Range to replace: from @ to current cursor
            let replaceRange = NSRange(location: triggerLoc,
                                       length: cursorPos - triggerLoc)

            // Build chip + trailing space
            let chip = MentionTextView.mentionChip(for: member)
            let space = NSAttributedString(
                string: " ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.label
                ]
            )

            let insertion = NSMutableAttributedString()
            insertion.append(chip)
            insertion.append(space)

            attr.replaceCharacters(in: replaceRange, with: insertion)
            textView.attributedText = attr
            // Move cursor after space
            let newPos = triggerLoc + insertion.length
            textView.selectedRange = NSRange(location: newPos, length: 0)

            atTriggerLocation = nil
            parent.mentionQuery = nil

            syncSegmentsToText(textView)
        }

        // MARK: - Sync attributed text → segments model

        func syncSegmentsToText(_ textView: UITextView) {
            guard let attr = textView.attributedText, attr.length > 0 else {
                DispatchQueue.main.async { self.parent.segments = [] }
                return
            }

            var segs: [MessageSegment] = []
            attr.enumerateAttributes(
                in: NSRange(location: 0, length: attr.length),
                options: []
            ) { attrs, range, _ in
                let substr = (attr.string as NSString).substring(with: range)
                if let _ = attrs[NSAttributedString.Key("mentionID")] as? String {
                    // Find member — strip leading @ and trailing space
                    let raw = substr.trimmingCharacters(in: .whitespaces)
                    let nameOnly = raw.hasPrefix("@") ? String(raw.dropFirst()) : raw
                    if let member = GroupMember.samples.first(where: { $0.name == nameOnly }) {
                        segs.append(.mention(member))
                    }
                } else if !substr.isEmpty {
                    segs.append(.text(substr))
                }
            }
            DispatchQueue.main.async { self.parent.segments = segs }
        }
    }
}

// MARK: - MentionSuggestionsView

struct MentionSuggestionsView: View {
    let members: [GroupMember]
    let onSelect: (GroupMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(members.enumerated()), id: \.element.id) { idx, member in
                Button(action: { onSelect(member) }) {
                    HStack(spacing: 12) {
                        // Avatar circle
                        ZStack {
                            Circle()
                                .fill(member.color.opacity(0.18))
                            Text(member.avatar)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(member.color)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Spacer()

                        Image(systemName: "at")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < members.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

// MARK: - GroupChatInputBar

struct GroupChatInputBar: View {

    let members: [GroupMember]

    @State private var segments: [MessageSegment] = []
    @State private var mentionQuery: String? = nil
    @State private var filteredMembers: [GroupMember] = []

    // A reference to the coordinator so we can call insertMention
    @State private var textViewRef: UITextView? = nil
    @State private var coordinatorRef: MentionTextView.Coordinator? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Mention suggestions popup
            if let _ = mentionQuery, !filteredMembers.isEmpty {
                MentionSuggestionsView(members: filteredMembers) { member in
                    guard let tv = textViewRef, let coord = coordinatorRef else { return }
                    coord.insertMention(member, into: tv)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input row
            HStack(alignment: .bottom, spacing: 10) {
                // Attachment button
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }

                // Text field
                ZStack(alignment: .topLeading) {
                    MentionTextViewWrapper(
                        segments: $segments,
                        mentionQuery: $mentionQuery,
                        onTextViewReady: { tv, coord in
                            textViewRef = tv
                            coordinatorRef = coord
                        }
                    )
                    .frame(minHeight: 40, maxHeight: 120)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Send button
                Button(action: sendMessage) {
                    Image(systemName: segments.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(segments.isEmpty ? .red : .blue)
                        .animation(.spring(response: 0.3), value: segments.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .onChange(of: mentionQuery) { query in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if let q = query {
                    filteredMembers = members.filter {
                        q.isEmpty || $0.name.localizedCaseInsensitiveContains(q)
                    }
                } else {
                    filteredMembers = []
                }
            }
        }
    }

    private func sendMessage() {
        // TODO: handle send
        segments = []
    }
}

// MARK: - Wrapper to expose UITextView + Coordinator references

struct MentionTextViewWrapper: UIViewRepresentable {

    @Binding var segments: [MessageSegment]
    @Binding var mentionQuery: String?
    var onTextViewReady: (UITextView, MentionTextView.Coordinator) -> Void

    func makeCoordinator() -> MentionTextView.Coordinator {
        MentionTextView.Coordinator(parent: MentionTextView(
            segments: $segments,
            mentionQuery: $mentionQuery
        ))
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        tv.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        context.coordinator.applyPlaceholder(tv, placeholder: "Message...")
        DispatchQueue.main.async {
            onTextViewReady(tv, context.coordinator)
        }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {}
}

// MARK: - Demo Chat Screen

struct GroupChatScreen: View {

    let members = GroupMember.samples

    // Sample messages
    struct ChatMessage: Identifiable {
        let id = UUID()
        let sender: GroupMember
        let text: String
        let isMine: Bool
    }

    let messages: [ChatMessage] = [
        ChatMessage(sender: GroupMember.samples[1], text: "Hey everyone! Ready for the meeting?", isMine: false),
        ChatMessage(sender: GroupMember.samples[2], text: "Almost! Give me 5 minutes 🙏", isMine: false),
        ChatMessage(sender: GroupMember.samples[0], text: "Sure, no rush!", isMine: true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("Design Team")
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(members.count) members")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 17))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)

            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            Divider()

            // Input bar
            GroupChatInputBar(members: members)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct MessageBubble: View {
    let message: GroupChatScreen.ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 60) }

            if !message.isMine {
                ZStack {
                    Circle().fill(message.sender.color.opacity(0.18))
                    Text(message.sender.avatar)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(message.sender.color)
                }
                .frame(width: 30, height: 30)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine {
                    Text(message.sender.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(message.sender.color)
                }
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(message.isMine ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isMine ? Color.blue : Color(.secondarySystemBackground))
                    )
            }

            if !message.isMine { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Preview

#Preview {
    GroupChatScreen()
}
