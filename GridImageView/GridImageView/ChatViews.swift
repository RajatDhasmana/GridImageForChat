import SwiftUI

// MARK: - Root Chat List View

struct ChatListView: View {

    @StateObject private var vm = MessageViewModel(
        conversationID: "conv_001",
        currentUserID:  "user_alice"
    )

    // Used to detect scroll-to-top for pagination
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var showScrollToBottom = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            // Top loader (pagination trigger)
                            topLoadingIndicator

                            ForEach(vm.messageGroups, id: \.id) { group in
                                Section(header: DateHeaderView(title: group.displayDate)) {
                                    ForEach(0 ..< group.messageItems.count, id: \.self) { idx in
                                        itemView(for: group.messageItems[idx])
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 3)
                                    }
                                }
                            }

                            // Anchor to scroll-to-bottom
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollProxy = proxy
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in showScrollToBottom = true }
                    )
                    // Pagination: detect reaching top
                    .refreshable { await vm.loadMoreIfNeeded() }
                }

                // Scroll-to-bottom FAB
                if showScrollToBottom {
                    scrollToBottomButton
                }
            }
            .navigationTitle("Design Team")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .task { await vm.loadInitial() }

            // Simulate incoming message (for demo)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sim") { simulateIncoming() }
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var topLoadingIndicator: some View {
        switch vm.paginationState {
        case .loadingInitial:
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading messages…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)

        case .loadingMore:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Loading older messages…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)

        case .exhausted:
            Text("Beginning of conversation")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

        default:
            Color.clear.frame(height: 4)
        }
    }

    @ViewBuilder
    private func itemView(for item: any MessageItem) -> some View {
        if let collage = item as? CollageMessage {
            CollageMessageView(collage: collage, downloadStates: vm.downloadStates)
        } else if let single = item as? SingleMessage {
            SingleMessageView(message: single, downloadStates: vm.downloadStates)
        }
    }

    private var scrollToBottomButton: some View {
        Button {
            withAnimation { scrollProxy?.scrollTo("bottom", anchor: .bottom) }
            showScrollToBottom = false
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .shadow(radius: 4)
        }
        .padding(.bottom, 80)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Demo helper

    private var simCounter = 0
    func simulateIncoming() {
        let mediaTypes: [DBMessage.MessageType] = [.image, .image, .text]
        let typeIdx = 0//Int.random(in: 0..<3)
        let isMedia = mediaTypes[typeIdx] == .image
        let id = "incoming_\(UUID().uuidString)"

        let msg = DBMessage(
            id: id,
            conversationID: "conv_001",
            senderID: "user_bob",
            senderName: "Bob",
            text: isMedia ? nil : "New message! 🎉",
            timestamp: Date(),
            type: isMedia ? .image : .text,
            mediaURL: isMedia ? URL(string: "https://picsum.photos/seed/\(id)/400/400") : nil,
            downloadState: .notStarted
        )
        vm.receive(incomingMessage: msg)
    }
}

// MARK: - Date Header

struct DateHeaderView: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(.regularMaterial)
            )
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Single Message View

struct SingleMessageView: View {
    let message: SingleMessage
    let downloadStates: [String: DBMessage.DownloadState]

    private var msg: DBMessage { message.messages[0] }
    private var isMine: Bool { message.isMine }
    private var state: DBMessage.DownloadState {
        downloadStates[msg.id] ?? msg.downloadState
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 60) }

            if !isMine { avatarView }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(msg.senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                bubbleContent
            }

            if !isMine { Spacer(minLength: 60) }
            if isMine  { Spacer().frame(width: 0) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if msg.isMedia {
            mediaCell(msg: msg, state: state, width: 220, height: 220, cornerRadius: 16)
        } else {
            Text(msg.text ?? "")
                .font(.system(size: 15))
                .foregroundStyle(isMine ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isMine ? Color.blue : Color(.secondarySystemBackground))
                )
        }
    }

    private var avatarView: some View {
        Circle()
            .fill(Color.blue.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(msg.senderName.prefix(1)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
            )
    }
}

// MARK: - Collage Message View

struct CollageMessageView: View {
    let collage: CollageMessage
    let downloadStates: [String: DBMessage.DownloadState]

    private var isMine: Bool { collage.isMine }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 40) }

            if !isMine { avatarView }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(collage.senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                collageGrid
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var collageGrid: some View {
        let rows = collage.gridLayout
        let totalCount = collage.messages.count
        let maxWidth: CGFloat = totalCount == 1 ? 220 : 260

        VStack(spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowMsgs in
                HStack(spacing: 2) {
                    ForEach(rowMsgs, id: \.id) { msg in
                        let state = downloadStates[msg.id] ?? msg.downloadState
                        let cellWidth  = cellWidth(totalInRow: rowMsgs.count, maxWidth: maxWidth)
                        let cellHeight = cellHeight(rowCount: rows.count)
                        mediaCell(
                            msg: msg,
                            state: state,
                            width: cellWidth,
                            height: cellHeight,
                            cornerRadius: cornerRadius(
                                rowIndex: rowIdx, colIndex: rowMsgs.firstIndex(of: msg)!,
                                totalRows: rows.count, totalInRow: rowMsgs.count
                            )
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func cellWidth(totalInRow: Int, maxWidth: CGFloat) -> CGFloat {
        let gap: CGFloat = 2
        return (maxWidth - gap * CGFloat(totalInRow - 1)) / CGFloat(totalInRow)
    }

    private func cellHeight(rowCount: Int) -> CGFloat {
        switch rowCount {
        case 1: return 200
        case 2: return 130
        default: return 100
        }
    }

    // Outer corners only on edge cells
    private func cornerRadius(rowIndex: Int, colIndex: Int, totalRows: Int, totalInRow: Int) -> CGFloat {
        0  // Clipped by parent RoundedRectangle
    }

    private var avatarView: some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(collage.senderName.prefix(1)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.purple)
            )
    }
}

// MARK: - Shared Media Cell

/// Used by both SingleMessage (large) and CollageMessage (small cells)
@ViewBuilder
func mediaCell(
    msg: DBMessage,
    state: DBMessage.DownloadState,
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat
) -> some View {
    ZStack {
        // Background placeholder
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)

        switch state {
        case .notStarted:
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

        case .downloading(let progress):
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.15), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(radius: 4)
            }

        case .downloaded:
            // In production: use AsyncImage(url: localURL)
            // Here we load from the original remote URL as simulation
            AsyncImage(url: msg.mediaURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }

        case .failed:
            VStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text("Retry")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    // Video badge
    .overlay(alignment: .bottomLeading) {
        if msg.type == .video {
            Label("Video", systemImage: "play.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatListView()
}
