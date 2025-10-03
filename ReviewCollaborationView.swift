import SwiftUI
import AVKit

// MARK: - Review & Collaboration Models

struct ReviewComment: Identifiable, Codable {
    let id: UUID
    var timestamp: Double
    var author: String
    var authorRole: String
    var text: String
    var createdAt: Date
    var isPinned: Bool
    var isResolved: Bool
    var replies: [ReviewReply]
    var priority: Priority

    init(id: UUID = UUID(), timestamp: Double, author: String, authorRole: String, text: String, createdAt: Date = .now, isPinned: Bool = false, isResolved: Bool = false, replies: [ReviewReply] = [], priority: Priority = .normal) {
        self.id = id
        self.timestamp = timestamp
        self.author = author
        self.authorRole = authorRole
        self.text = text
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.isResolved = isResolved
        self.replies = replies
        self.priority = priority
    }

    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case normal = "Normal"
        case high = "High"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .low: return .gray
            case .normal: return .blue
            case .high: return .orange
            case .critical: return .red
            }
        }

        var systemImage: String {
            switch self {
            case .low: return "arrow.down.circle"
            case .normal: return "circle"
            case .high: return "arrow.up.circle"
            case .critical: return "exclamationmark.circle.fill"
            }
        }
    }
}

struct ReviewReply: Identifiable, Codable {
    let id: UUID
    var author: String
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), author: String, text: String, createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.text = text
        self.createdAt = createdAt
    }
}

struct ReelVersion: Identifiable, Codable {
    let id: UUID
    var versionNumber: Int
    var createdAt: Date
    var createdBy: String
    var changeDescription: String
    var snapshotURL: URL?
    var isCurrent: Bool

    init(id: UUID = UUID(), versionNumber: Int, createdAt: Date = .now, createdBy: String, changeDescription: String, snapshotURL: URL? = nil, isCurrent: Bool = false) {
        self.id = id
        self.versionNumber = versionNumber
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.changeDescription = changeDescription
        self.snapshotURL = snapshotURL
        self.isCurrent = isCurrent
    }
}

struct ReviewSession: Identifiable {
    let id = UUID()
    var shareLink: String
    var expiresAt: Date
    var accessLevel: AccessLevel
    var allowComments: Bool
    var allowDownload: Bool
    var viewCount: Int

    enum AccessLevel: String, CaseIterable {
        case view = "View Only"
        case comment = "View & Comment"
        case edit = "View, Comment & Edit"

        var systemImage: String {
            switch self {
            case .view: return "eye"
            case .comment: return "text.bubble"
            case .edit: return "pencil"
            }
        }
    }

    static func createNew() -> ReviewSession {
        ReviewSession(
            shareLink: "https://endoreels.com/review/\(UUID().uuidString.prefix(8))",
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            accessLevel: .comment,
            allowComments: true,
            allowDownload: false,
            viewCount: 0
        )
    }
}

// MARK: - Review & Collaboration View

struct ReviewCollaborationView: View {
    @Binding var comments: [ReviewComment]
    @Binding var versions: [ReelVersion]
    @Binding var reviewSession: ReviewSession?
    let videoDuration: Double
    let videoURL: URL?

    @State private var currentTime: Double = 0
    @State private var player: AVPlayer?
    @State private var newCommentText = ""
    @State private var showNewCommentSheet = false
    @State private var selectedPriority: ReviewComment.Priority = .normal
    @State private var selectedCommentID: UUID?
    @State private var showVersionHistory = false
    @State private var showShareSheet = false
    @State private var replyText = ""
    @State private var replyingToCommentID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video Player
                videoPlayerSection

                Divider()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Share & Collaborate
                        shareSection

                        // Version History
                        versionSection

                        // Comments Timeline
                        commentsTimelineSection

                        // Comments List
                        commentsListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Review & Collaborate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showNewCommentSheet = true
                        } label: {
                            Label("Add Comment", systemImage: "plus.bubble")
                        }

                        Button {
                            showVersionHistory = true
                        } label: {
                            Label("Version History", systemImage: "clock.arrow.circlepath")
                        }

                        Button {
                            createSnapshot()
                        } label: {
                            Label("Create Snapshot", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNewCommentSheet) {
                NewCommentSheet(
                    currentTime: currentTime,
                    onSubmit: { text, priority in
                        addComment(text: text, priority: priority)
                        showNewCommentSheet = false
                    }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareLinkSheet(session: $reviewSession)
            }
            .sheet(isPresented: $showVersionHistory) {
                VersionHistoryView(versions: $versions, onRestore: { version in
                    restoreVersion(version)
                    showVersionHistory = false
                })
            }
            .onAppear { setupPlayer() }
        }
    }

    private var videoPlayerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 220)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 220)
                        .overlay(
                            Text("No video loaded")
                                .foregroundStyle(.white)
                        )
                }

                // Comment markers on video
                GeometryReader { geometry in
                    ForEach(comments) { comment in
                        if abs(comment.timestamp - currentTime) < 1.0 {
                            VStack {
                                Image(systemName: "bubble.left.fill")
                                    .foregroundStyle(comment.priority.color)
                                    .font(.title3)
                            }
                            .position(x: geometry.size.width - 30, y: 30)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Text("\(currentTime, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Slider(value: $currentTime, in: 0...max(videoDuration, 1))
                    .onChange(of: currentTime) { _, newValue in
                        seekPlayer(to: newValue)
                    }

                Button {
                    showNewCommentSheet = true
                } label: {
                    Image(systemName: "plus.bubble")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share & Collaborate")
                .font(.headline)

            if let session = reviewSession {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review Link Active")
                                .font(.subheadline.weight(.semibold))
                            Text("Expires \(relativeDate(from: session.expiresAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label("\(session.viewCount)", systemImage: "eye")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(session.shareLink)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            UIPasteboard.general.string = session.shareLink
                        }

                    HStack(spacing: 8) {
                        Label(session.accessLevel.rawValue, systemImage: session.accessLevel.systemImage)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())

                        if session.allowComments {
                            Label("Comments On", systemImage: "checkmark")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Manage Sharing", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    createReviewSession()
                } label: {
                    Label("Create Review Link", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version History")
                    .font(.headline)
                Spacer()
                Text("\(versions.count) versions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let current = versions.first(where: { $0.isCurrent }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version \(current.versionNumber)")
                            .font(.subheadline.weight(.semibold))
                        Text(current.changeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showVersionHistory = true
            } label: {
                Label("View All Versions", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var commentsTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments Timeline")
                    .font(.headline)
                Spacer()
                Text("\(comments.count) comments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 60)

                    ForEach(comments) { comment in
                        commentTimelineMarker(comment, containerWidth: geometry.size.width)
                    }

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: currentTimeOffset(containerWidth: geometry.size.width))
                }
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func commentTimelineMarker(_ comment: ReviewComment, containerWidth: CGFloat) -> some View {
        let offset = (comment.timestamp / max(videoDuration, 1)) * containerWidth * 0.85

        return VStack {
            Circle()
                .fill(comment.priority.color)
                .frame(width: comment.isPinned ? 16 : 12, height: comment.isPinned ? 16 : 12)
                .overlay(
                    Image(systemName: comment.isPinned ? "pin.fill" : "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.white)
                )
        }
        .offset(x: offset)
    }

    private func currentTimeOffset(containerWidth: CGFloat) -> CGFloat {
        (currentTime / max(videoDuration, 1)) * containerWidth * 0.85
    }

    private var commentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Comments")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("All Comments") { }
                    Button("Pinned Only") { }
                    Button("Unresolved Only") { }
                    Divider()
                    Button("By Priority") { }
                    Button("By Time") { }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                }
            }

            if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add time-coded comments to collaborate on this reel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach($comments.sorted(by: { $0.timestamp.wrappedValue < $1.timestamp.wrappedValue })) { $comment in
                    ReviewCommentCard(
                        comment: $comment,
                        isSelected: selectedCommentID == comment.id,
                        onSelect: {
                            selectedCommentID = comment.id
                            currentTime = comment.timestamp
                            seekPlayer(to: comment.timestamp)
                        },
                        onReply: {
                            replyingToCommentID = comment.id
                        },
                        onPin: {
                            comment.isPinned.toggle()
                        },
                        onResolve: {
                            comment.isResolved.toggle()
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper Functions

    private func setupPlayer() {
        guard let videoURL = videoURL else { return }
        player = AVPlayer(url: videoURL)
    }

    private func seekPlayer(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    private func addComment(text: String, priority: ReviewComment.Priority) {
        let comment = ReviewComment(
            timestamp: currentTime,
            author: "Current User",
            authorRole: "Creator",
            text: text,
            priority: priority
        )
        comments.append(comment)
    }

    private func createReviewSession() {
        reviewSession = ReviewSession.createNew()
    }

    private func createSnapshot() {
        let newVersion = ReelVersion(
            versionNumber: versions.count + 1,
            createdBy: "Current User",
            changeDescription: "Manual snapshot",
            isCurrent: false
        )

        // Set all versions to not current
        for i in versions.indices {
            versions[i].isCurrent = false
        }

        versions.insert(newVersion, at: 0)
    }

    private func restoreVersion(_ version: ReelVersion) {
        for i in versions.indices {
            versions[i].isCurrent = versions[i].id == version.id
        }
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

// MARK: - Supporting Views

private struct ReviewCommentCard: View {
    @Binding var comment: ReviewComment
    let isSelected: Bool
    let onSelect: () -> Void
    let onReply: () -> Void
    let onPin: () -> Void
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(comment.author.prefix(2).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .font(.subheadline.weight(.semibold))
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(comment.authorRole)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Label("\(comment.timestamp, specifier: "%.1f")s", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(comment.text)
                        .font(.subheadline)
                }

                Spacer()

                Image(systemName: comment.priority.systemImage)
                    .foregroundStyle(comment.priority.color)
            }

            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(comment.replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(reply.author.prefix(1).uppercased())
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(reply.author)
                                    .font(.caption.weight(.semibold))
                                Text(reply.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: onReply) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: onPin) {
                    Label(comment.isPinned ? "Unpin" : "Pin", systemImage: comment.isPinned ? "pin.slash" : "pin")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: onResolve) {
                    Label(comment.isResolved ? "Unresolve" : "Resolve", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(comment.isResolved ? .green : .gray)

                Spacer()

                if comment.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                }

                if comment.isResolved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : (comment.isResolved ? Color.green.opacity(0.05) : Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : (comment.isPinned ? Color.orange : Color.clear), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture(perform: onSelect)
    }
}

private struct NewCommentSheet: View {
    let currentTime: Double
    let onSubmit: (String, ReviewComment.Priority) -> Void

    @State private var text = ""
    @State private var priority: ReviewComment.Priority = .normal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Comment Details") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)

                    Picker("Priority", selection: $priority) {
                        ForEach(ReviewComment.Priority.allCases, id: \.self) { priority in
                            Label(priority.rawValue, systemImage: priority.systemImage)
                                .tag(priority)
                        }
                    }

                    Label("At \(currentTime, specifier: "%.1f")s", systemImage: "timer")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSubmit(text, priority)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

private struct ShareLinkSheet: View {
    @Binding var session: ReviewSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let session = session {
                    Section("Link") {
                        Text(session.shareLink)
                            .font(.caption)
                    }

                    Section("Settings") {
                        Toggle("Allow Comments", isOn: .constant(session.allowComments))
                        Toggle("Allow Download", isOn: .constant(session.allowDownload))
                    }
                }
            }
            .navigationTitle("Share Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct VersionHistoryView: View {
    @Binding var versions: [ReelVersion]
    let onRestore: (ReelVersion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(versions.sorted(by: { $0.versionNumber > $1.versionNumber })) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Version \(version.versionNumber)")
                                .font(.headline)
                            Text(version.changeDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("By \(version.createdBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if version.isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Restore") {
                                onRestore(version)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Version History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReviewCollaborationView(
        comments: .constant([]),
        versions: .constant([]),
        reviewSession: .constant(nil),
        videoDuration: 60,
        videoURL: nil
    )
}
