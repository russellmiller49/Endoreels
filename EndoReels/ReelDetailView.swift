import SwiftUI

struct ReelDetailView: View {
    let reel: Reel
    @State private var selectedReaction: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                engagement
                steps
                if !reel.knowledgeHighlights.isEmpty {
                    knowledgeHighlights
                }
                phiChecklist
                if let track = reel.cmeTrack {
                    cmeCard(for: track)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(reel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(reel.engagement.reactions.keys.sorted(), id: \.self) { reaction in
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(reel.title)
                .font(.title.bold())
                .multilineTextAlignment(.leading)

            Text(reel.abstract)
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initials(for: reel.author.name))
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(reel.author.name)
                        .font(.headline)
                    Text("\(reel.author.role) • \(reel.author.institution)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(reel.author.bio)
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
            Label(reel.procedure, systemImage: "scalpel")
            Label(reel.anatomy, systemImage: "lungs.fill")
            Label(reel.pathology, systemImage: "waveform.path.ecg")
            Label(reel.device, systemImage: "stethoscope")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var badgeLabel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(reel.author.verification.tier.displayName)
                .font(.caption2.bold())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
            Text("Verified \(relativeDate(from: reel.author.verification.issuedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var badgeColor: Color {
        switch reel.author.verification.tier {
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
            EngagementRow(engagement: reel.engagement)
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

            ForEach(reel.steps) { step in
                StepCard(step: step)
            }
        }
    }

    private var knowledgeHighlights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Knowledge Highlights")
                .font(.title3.bold())
            ForEach(reel.knowledgeHighlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)
                    Text(highlight)
                        .font(.body)
                }
            }
        }
    }

    private var phiChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("De-identification Checks")
                .font(.title3.bold())
            if reel.phiFindings.isEmpty {
                Label("No PHI findings detected", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
            } else {
                ForEach(reel.phiFindings) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: finding.resolved ? "checkmark.shield" : "exclamationmark.shield")
                            .foregroundStyle(finding.resolved ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.summary)
                                .font(.subheadline.weight(.semibold))
                            Text("Mitigation: \(finding.mitigation)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
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
}

struct StepCard: View {
    let step: ReelStep

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
    }

    private var mediaSystemImage: String {
        switch step.mediaType {
        case .video: return "play.rectangle"
        case .image: return "photo"
        case .dicom: return "waveform.path"
        }
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
    NavigationStack {
        if let reel = DemoDataStore().reels.first {
            ReelDetailView(reel: reel)
        } else {
            Text("No sample data")
        }
    }
}
