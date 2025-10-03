import SwiftUI

struct OperationsView: View {
    @EnvironmentObject private var store: DemoDataStore
    @State private var selectedRunID: UUID? = nil

    var body: some View {
        List {
            Section("Trust & Verification") {
                VerificationSummaryView(reels: store.reels)
            }

            Section("Moderation Queue") {
                if store.moderationQueue.isEmpty {
                    Label("Nothing awaiting review", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.moderationQueue) { ticket in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ticket.reel.title)
                                    .font(.headline)
                                Spacer()
                                Text(ticket.status)
                                    .font(.caption.bold())
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(Color.orange.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Text(ticket.issue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("SLA due in \(timeRemaining(until: ticket.slaDue))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("De-ID Pipeline") {
                ForEach(store.pipelineRuns) { run in
                    DisclosureGroup(isExpanded: Binding(
                        get: { selectedRunID == run.id },
                        set: { expanded in selectedRunID = expanded ? run.id : nil }
                    )) {
                        ForEach(run.stages) { stage in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stage.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(stage.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Label("\(stage.durationSeconds) s", systemImage: "timer")
                                    Label(stage.outcome, systemImage: stage.outcome == "Pass" || stage.outcome == "Approved" ? "checkmark.circle" : "exclamationmark.circle")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } label: {
                        PipelineHeader(run: run)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ops Console")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: simulateRun) {
                    Label("Simulate Run", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func timeRemaining(until date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func simulateRun() {
        selectedRunID = nil
    }
}

private struct VerificationSummaryView: View {
    let reels: [Reel]

    var body: some View {
        let published = reels.filter { $0.status == .published }
        let review = reels.filter { $0.status == .review }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryTile(title: "Published", value: published.count, caption: "Ready for feed")
                summaryTile(title: "In Review", value: review.count, caption: "Awaiting moderation")
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Verification tiers")
                    .font(.subheadline.weight(.semibold))
                ForEach(groupedByTier, id: \.tier) { item in
                    HStack {
                        Label(item.tier.displayName, systemImage: "checkmark.seal")
                            .foregroundStyle(color(for: item.tier))
                        Spacer()
                        Text("\(item.count)")
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var groupedByTier: [(tier: VerificationTier, count: Int)] {
        let allAuthors = reels.map(\.author)
        let counts = Dictionary(grouping: allAuthors, by: { $0.verification.tier })
            .mapValues { $0.count }
        return VerificationTier.allCases.map { ($0, counts[$0] ?? 0) }
    }

    private func summaryTile(title: String, value: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("\(value)")
                .font(.title)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func color(for tier: VerificationTier) -> Color {
        switch tier {
        case .unverified: return .gray
        case .clinicianBlue: return .blue
        case .educatorGold: return .yellow
        case .societyEndorsed: return .green
        }
    }
}

private struct PipelineHeader: View {
    let run: PipelineRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.assetName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(run.status)
                    .font(.caption)
                    .foregroundStyle(run.status == "Completed" ? .green : .orange)
            }
            Label("Started \(relativeDate(from: run.startedAt))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("Resolved findings: \(run.resolvedFindings)", systemImage: "shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    NavigationStack {
        OperationsView()
    }
    .environmentObject(DemoDataStore())
}
