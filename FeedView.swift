import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DemoDataStore
    @State private var selectedServiceLine: ServiceLine? = nil
    @State private var selectedProcedure: String? = nil
    @State private var keywordQuery: String = ""
    @State private var showingSettings = false
    @State private var showingFilters = false

    private var filteredReels: [Reel] {
        var reels = store.reels

        if let line = selectedServiceLine {
            reels = reels.filter { $0.serviceLine == line }
        }

        if let procedure = selectedProcedure, !procedure.isEmpty {
            reels = reels.filter { $0.procedure == procedure }
        }

        let tokens = keywordTokens
        if !tokens.isEmpty {
            reels = reels.filter { reel in
                tokens.allSatisfy { token in
                    reel.anatomy.lowercased().contains(token) ||
                    reel.pathology.lowercased().contains(token) ||
                    reel.device.lowercased().contains(token)
                }
            }
        }

        return reels
    }

    private var keywordTokens: [String] {
        keywordQuery
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private var hasActiveFilters: Bool {
        selectedServiceLine != nil || selectedProcedure != nil || !keywordTokens.isEmpty
    }

    private var activeFilterSummary: String? {
        var parts: [String] = []
        if let line = selectedServiceLine {
            parts.append(line.displayName)
        }
        if let procedure = selectedProcedure, !procedure.isEmpty {
            parts.append(procedure)
        }
        if !keywordTokens.isEmpty {
            parts.append("Keywords: \(keywordTokens.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func clearFilters() {
        selectedServiceLine = nil
        selectedProcedure = nil
        keywordQuery = ""
    }

    var body: some View {
        List {
            if let hero = store.reels.first {
                heroSection(hero)
            }

            Section(header: Text("Latest Reels")) {
                ForEach(filteredReels) { reel in
                    NavigationLink(value: reel.id) {
                        ReelCardView(reel: reel)
                    }
                }
            }
            if let summary = activeFilterSummary {
                Section {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("EndoReels Demo")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Demo Setup") {
                    showingSettings = true
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    Label("Filters", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            DemoSetupSheet()
        }
        .sheet(isPresented: $showingFilters) {
            FeedFilterSheet(
                selectedServiceLine: $selectedServiceLine,
                selectedProcedure: $selectedProcedure,
                keywordQuery: $keywordQuery,
                onClear: clearFilters
            )
        }
        .onChange(of: selectedServiceLine) { _, newValue in
            guard let newValue else {
                selectedProcedure = nil
                return
            }
            let options = newValue.defaultProcedures
            if let current = selectedProcedure, !options.contains(current) {
                selectedProcedure = nil
            }
        }
        .task {
            if selectedServiceLine == nil {
                selectedServiceLine = appState.currentUser.role
            }
        }
        .navigationDestination(for: UUID.self) { reelID in
            if let reel = store.reels.first(where: { $0.id == reelID }) {
                ReelDetailView(reel: reel)
            } else {
                Text("Reel unavailable")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func heroSection(_ reel: Reel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Featured Case")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.secondary)

                Text(reel.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(reel.abstract)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label("\(reel.engagement.views) views", systemImage: "play.circle")
                    Label("\(Int(reel.engagement.completionRate * 100))% completion", systemImage: "percent")
                    Label("\(reel.engagement.saves) saves", systemImage: "bookmark")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reel.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                NavigationLink("Open Reel") {
                    ReelDetailView(reel: reel)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
        }
    }
}

private struct FeedFilterSheet: View {
    @Binding var selectedServiceLine: ServiceLine?
    @Binding var selectedProcedure: String?
    @Binding var keywordQuery: String
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var procedureBinding: Binding<String> {
        Binding<String>(
            get: { selectedProcedure ?? "" },
            set: { newValue in
                selectedProcedure = newValue.isEmpty ? nil : newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Line") {
                    Picker("Service Line", selection: $selectedServiceLine) {
                        Text("All").tag(ServiceLine?.none)
                        ForEach(ServiceLine.allCases) { line in
                            Text(line.displayName).tag(ServiceLine?.some(line))
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Procedure") {
                    if let selectedServiceLine {
                        Picker("Procedure", selection: procedureBinding) {
                            Text("All").tag("")
                            ForEach(selectedServiceLine.defaultProcedures, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                    } else {
                        Label("Select a service line to refine by procedure", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Keywords") {
                    TextField("e.g. left main, ulcer", text: $keywordQuery)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Text("Matches anatomy, pathology, or device.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") {
                        onClear()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReelCardView: View {
    let reel: Reel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reel.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(reel.abstract)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            HStack(alignment: .center, spacing: 12) {
                serviceLineBadge
                authorBadge
                Divider()
                    .frame(height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reel.procedure)
                    Text(reel.anatomy)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            EngagementRow(engagement: reel.engagement)
        }
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        Text(reel.status.displayName)
            .font(.caption.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch reel.status {
        case .draft:
            return .gray
        case .review:
            return .orange
        case .published:
            return .green
        }
    }

    private var authorBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reel.author.name)
                .font(.subheadline.weight(.medium))
            Text("\(reel.author.role) • \(reel.author.institution)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var serviceLineBadge: some View {
        Label(reel.serviceLine.displayName, systemImage: "list.bullet.rectangle")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.08))
            .clipShape(Capsule())
    }
}

struct EngagementRow: View {
    let engagement: EngagementSignals

    var body: some View {
        HStack(spacing: 16) {
            Label("\(engagement.views)", systemImage: "eye")
            Label("\(engagement.saves)", systemImage: "bookmark")
            Label("\(engagement.reactions.values.reduce(0, +))", systemImage: "hands.clap")
            Label("\(Int(engagement.completionRate * 100))%", systemImage: "percent")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct DemoSetupSheet: View {
    @State private var enableBetaUI = true
    @State private var useSyntheticAssets = true
    @State private var showCMETracks = true
    @State private var anonymizeAuthors = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feature Flags") {
                    Toggle("Enable beta UI", isOn: $enableBetaUI)
                    Toggle("Show CME surfaces", isOn: $showCMETracks)
                    Toggle("Use synthetic demo assets", isOn: $useSyntheticAssets)
                }
                Section("Privacy Controls") {
                    Toggle("Anonymize author names", isOn: $anonymizeAuthors)
                    Label("Audit logging enforced", systemImage: "lock.shield")
                }
                Section("Environment") {
                    Label("Mode: Local-only demo", systemImage: "desktopcomputer")
                    Label("PHI handling: disabled", systemImage: "nosign")
                }
            }
            .navigationTitle("Demo Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    NavigationStack {
        FeedView()
    }
    .environmentObject(DemoDataStore())
}
