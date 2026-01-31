import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct ReelDetailView: View {
    let reel: Reel
    @EnvironmentObject private var store: DemoDataStore
    @State private var selectedReaction: String? = nil
    @State private var commentName: String = ""
    @State private var commentRole: String = ""
    @State private var commentBody: String = ""
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                engagement
                steps
                if !currentReel.knowledgeHighlights.isEmpty {
                    knowledgeHighlights
                }
                commentsSection
                if let track = currentReel.cmeTrack {
                    cmeCard(for: track)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(currentReel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(currentReel.engagement.reactions.keys.sorted(), id: \.self) { reaction in
                        Button(reaction) { selectedReaction = reaction }
                    }
                } label: {
                    Image(systemName: "hands.clap")
                }
                .task(id: selectedReaction) {
                    // no-op: purely illustrative for demo
                }
            }
        }
    }

    private var currentReel: Reel {
        store.reels.first(where: { $0.id == reel.id }) ?? reel
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentReel.title)
                .font(.title.bold())
                .multilineTextAlignment(.leading)

            Text(currentReel.abstract)
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initials(for: currentReel.author.name))
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentReel.author.name)
                        .font(.headline)
                    Text("\(currentReel.author.role) • \(currentReel.author.institution)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(currentReel.author.bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                badgeLabel
            }

            specRow
        }
    }

    private var specRow: some View {
        HStack(spacing: 16) {
            Label(currentReel.procedure, systemImage: "scalpel")
            Label(currentReel.anatomy, systemImage: "lungs.fill")
            Label(currentReel.pathology, systemImage: "waveform.path.ecg")
            Label(currentReel.device, systemImage: "stethoscope")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var badgeLabel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(currentReel.author.verification.tier.displayName)
                .font(.caption2.bold())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
            Text("Verified \(relativeDate(from: currentReel.author.verification.issuedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var badgeColor: Color {
        switch currentReel.author.verification.tier {
        case .unverified:
            return .gray
        case .clinicianBlue:
            return .blue
        case .educatorGold:
            return .yellow
        case .societyEndorsed:
            return .green
        }
    }

    private var engagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engagement Signals")
                .font(.title3.bold())
            EngagementRow(engagement: currentReel.engagement)
            HStack(spacing: 12) {
                Button { selectedReaction = "Insightful" } label: {
                    Label("React", systemImage: "hands.clap.fill")
                }
                .buttonStyle(.borderedProminent)

                Button { /* placeholder */ } label: {
                    Label("Save", systemImage: "bookmark.fill")
                }
                .buttonStyle(.bordered)

                Spacer()
                Text(selectedReaction == nil ? "Select a reaction" : "Reacted with \(selectedReaction!)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storyboard Steps")
                .font(.title3.bold())

            ForEach(currentReel.steps) { step in
                StepCard(step: step)
            }
        }
    }

    private var knowledgeHighlights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Knowledge Highlights")
                .font(.title3.bold())
            ForEach(currentReel.knowledgeHighlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)
                    Text(highlight)
                        .font(.body)
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community Comments")
                .font(.title3.bold())

            if currentReel.comments.isEmpty {
                Label("No comments yet. Be the first to share insights.", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(currentReel.comments) { comment in
                        CommentCard(comment: comment)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add Your Voice")
                    .font(.headline)
                TextField("Name (optional)", text: $commentName)
                    .textFieldStyle(.roundedBorder)
                TextField("Role / Title (optional)", text: $commentRole)
                    .textFieldStyle(.roundedBorder)
                TextField("Share a pearl, question, or feedback", text: $commentBody, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 80)
                    .focused($isCommentFocused)

                HStack {
                    Button("Clear", role: .cancel) {
                        resetCommentFields()
                    }
                    .disabled(commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && commentName.isEmpty && commentRole.isEmpty)

                    Spacer()

                    Button {
                        submitComment()
                    } label: {
                        Label("Post Comment", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func cmeCard(for track: CMETrack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CME Track")
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text(track.title)
                    .font(.headline)
                Text(track.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label("\(track.credits, specifier: "%.2f") AMA PRA Credits", systemImage: "graduationcap")
                    Label(track.provider, systemImage: "building.columns")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Button {
                    // simulate launching CME
                } label: {
                    Label("Launch CME Quiz", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func initials(for name: String) -> String {
        name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func submitComment() {
        let trimmed = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let name = commentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = commentRole.trimmingCharacters(in: .whitespacesAndNewlines)

        let comment = CaseComment(
            authorName: name.isEmpty ? "Guest Clinician" : name,
            authorTitle: role.isEmpty ? "Viewer" : role,
            message: trimmed,
            createdAt: Date()
        )

        store.addComment(comment, to: currentReel.id)
        resetCommentFields()
        isCommentFocused = false
    }

    private func resetCommentFields() {
        commentName = ""
        commentRole = ""
        commentBody = ""
    }
}

private struct CommentCard: View {
    let comment: CaseComment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(initials(for: comment.authorName))
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.authorName)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.authorTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(relativeDate(from: comment.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(comment.message)
                .font(.body)

            Divider()
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let components = trimmed.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

struct StepCard: View {
    let step: ReelStep
    @State private var previewImage: UIImage?
    @State private var showMediaViewer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Step \(step.orderIndex)")
                    .font(.caption.bold())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                Text(step.title)
                    .font(.headline)
                Spacer()
                Label("\(step.durationSeconds) s", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(step.keyPoint)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let url = step.mediaURL {
                Button {
                    showMediaViewer = true
                } label: {
                    StepMediaPreview(mediaType: step.mediaType, previewImage: previewImage)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showMediaViewer) {
                    StepMediaViewer(step: step)
                }
            }

            HStack(spacing: 8) {
                Label(step.mediaType.displayName, systemImage: mediaSystemImage)
                if !step.annotations.isEmpty {
                    Label("\(step.annotations.count) annotations", systemImage: "highlighter")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !step.annotations.isEmpty {
                AnnotationChips(annotations: step.annotations)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .task(id: step.mediaURL?.absoluteString) {
            await loadPreviewImage()
        }
    }

    private var mediaSystemImage: String {
        switch step.mediaType {
        case .video: return "play.rectangle"
        case .image: return "photo"
        case .dicom: return "waveform.path"
        }
    }

    private func loadPreviewImage() async {
        guard let url = step.mediaURL else {
            await MainActor.run { previewImage = nil }
            return
        }

        switch step.mediaType {
        case .video:
            let image = await AVURLAsset(url: url).generateThumbnail()
            await MainActor.run { previewImage = image }
        case .image:
            let image = UIImage(contentsOfFile: url.path)
            await MainActor.run { previewImage = image }
        case .dicom:
            await MainActor.run { previewImage = nil }
        }
    }
}

private struct StepMediaPreview: View {
    let mediaType: MediaType
    let previewImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemBackground))

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: placeholderIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }

            if mediaType == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var placeholderIcon: String {
        switch mediaType {
        case .video:
            return "play.rectangle"
        case .image:
            return "photo"
        case .dicom:
            return "waveform.path"
        }
    }
}

private struct StepMediaViewer: View {
    let step: ReelStep
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let url = step.mediaURL {
                GeometryReader { geometry in
                    let size = geometry.size
                    ZStack {
                        viewerCanvas(url: url, size: size)
                            .scaleEffect(step.cropScale)
                            .offset(
                                x: step.cropOffsetX * size.width,
                                y: step.cropOffsetY * size.height
                            )
                    }
                    .frame(width: size.width, height: size.height)
                    .clipped()
                }
                .ignoresSafeArea()
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding()
            }
        }
        .onAppear {
            if step.mediaType == .video, let url = step.mediaURL {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private func viewerCanvas(url: URL, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            switch step.mediaType {
            case .video:
                if let player {
                    AspectFillPlayerView(player: player)
                        .frame(width: size.width, height: size.height)
                }
            case .image:
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                }
            case .dicom:
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
            }

            ForEach(step.manualBlurRects) { rect in
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(width: rect.width * size.width, height: rect.height * size.height)
                    .position(
                        x: (rect.x + rect.width / 2) * size.width,
                        y: (rect.y + rect.height / 2) * size.height
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ForEach(step.timedAnnotations) { annotation in
                let position = CGPoint(x: annotation.position.x * size.width, y: annotation.position.y * size.height)
                AnnotationOverlay(annotation: annotation)
                    .position(position)
            }
        }
    }
}

private struct AnnotationOverlay: View {
    let annotation: TimedAnnotation

    var body: some View {
        Group {
            switch annotation.type {
            case .arrow:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 28))
                    .foregroundStyle(annotation.color.swiftUIColor)
                    .shadow(radius: 1)

            case .circle:
                Circle()
                    .stroke(annotation.color.swiftUIColor, lineWidth: 4)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 1)

            case .text:
                Text(annotation.text.isEmpty ? "Text" : annotation.text)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(annotation.color.swiftUIColor.opacity(0.8), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)

            default:
                Image(systemName: annotation.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(annotation.color.swiftUIColor)
            }
        }
        .scaleEffect(annotation.scale)
        .rotationEffect(.degrees(annotation.rotation))
        .opacity(annotation.opacity)
    }
}

struct AnnotationChips: View {
    let annotations: [String]
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(annotations, id: \.self) { annotation in
                Text(annotation)
                    .font(.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.gray.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    let store = DemoDataStore()
    return NavigationStack {
        if let reel = store.reels.first {
            ReelDetailView(reel: reel)
        } else {
            Text("No sample data")
        }
    }
    .environmentObject(store)
}
