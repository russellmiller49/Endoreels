import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DemoDataStore
    @Binding var selectedReelID: UUID?
    @State private var selectedServiceLine: ServiceLine? = nil
    @State private var selectedProcedure: String? = nil
    @State private var keywordQuery: String = ""
    @State private var showingSettings = false
    @State private var showingFilters = false
    @State private var showOnboarding = false
    @State private var searchQuery: String = ""
    @State private var suggestions: [SearchSuggestion] = []
    @State private var selectedFilterChips: Set<FilterChip> = []

    private var filteredReels: [Reel] {
        var reels = store.reels

        if let line = selectedServiceLine {
            reels = reels.filter { $0.serviceLine == line }
        }

        if let procedure = selectedProcedure, !procedure.isEmpty {
            reels = reels.filter { $0.procedure == procedure }
        }

        let verificationFilters = selectedFilterChips.compactMap { chip -> VerificationTier? in
            if case let .verification(tier) = chip { return tier }
            return nil
        }
        if !verificationFilters.isEmpty {
            reels = reels.filter { verificationFilters.contains($0.author.verification.tier) }
        }

        let difficultyFilters = selectedFilterChips.compactMap { chip -> String? in
            if case let .difficulty(level) = chip { return level }
            return nil
        }
        if !difficultyFilters.isEmpty {
            reels = reels.filter { difficultyFilters.contains($0.difficulty) }
        }

        let filterTokens = keywordTokens
        if !filterTokens.isEmpty {
            reels = reels.filter { reel in
                filterTokens.allSatisfy { token in
                    reel.anatomy.lowercased().contains(token) ||
                    reel.pathology.lowercased().contains(token) ||
                    reel.device.lowercased().contains(token)
                }
            }
        }

        if !searchTokens.isEmpty {
            reels = reels.filter { matchesSearch(reel: $0, tokens: searchTokens) }
        }

        if selectedFilterChips.contains(.recent) {
            reels = reels.sorted { $0.createdAt > $1.createdAt }
        }

        return reels
    }

    private var searchTokens: [String] {
        searchQuery
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
            .filter { !$0.isEmpty }
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
        selectedServiceLine = appState.currentUser.role
        selectedProcedure = nil
        keywordQuery = ""
        searchQuery = ""
        selectedFilterChips.removeAll()
        suggestions = []
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Explore the EndoReels demo")
                        .font(.headline)
                    Text("Preview the guided tour or jump into a sample case to see how the platform works.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("View Demo Tour", systemImage: "sparkles.tv")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            if !store.continueWatching.isEmpty {
                continueWatchingSection
            }

            if !filterChipOptions.isEmpty {
                filtersSection
            }

            if let hero = (filteredReels.first ?? store.reels.first) {
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always)) {
            ForEach(suggestions) { suggestion in
                Button {
                    applySuggestion(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                        if let subtitle = suggestion.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedServiceLine, initial: false) { oldValue, newValue in
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
        .onChange(of: appState.currentUser.role, initial: false) { oldValue, newValue in
            selectedServiceLine = newValue
            selectedProcedure = nil
            keywordQuery = ""
            searchQuery = ""
            selectedFilterChips.removeAll()
            suggestions = []
        }
        .onChange(of: searchQuery, initial: false) { oldValue, newValue in
            updateSuggestions(for: newValue)
        }
    }

    @ViewBuilder
    private var continueWatchingSection: some View {
        Section(header: Text("Continue Watching")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.continueWatching) { progress in
                        if let reel = store.reels.first(where: { $0.id == progress.reelID }) {
                            Button {
                                selectedReelID = reel.id
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(reel.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(progress.lastStepTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ProgressView(value: progress.progress)
                                        .progressViewStyle(.linear)
                                    Text("Updated \(progress.updatedAt, format: .relative(presentation: .named))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(width: 220, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    @ViewBuilder
    private var filtersSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterChipOptions) { chip in
                        FilterChipView(
                            chip: chip,
                            isSelected: selectedFilterChips.contains(chip),
                            action: { toggleFilterChip(chip) }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal)
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

                NavigationLink(value: reel.id) {
                    Text("Open Reel")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
        }
    }

    private var filterChipOptions: [FilterChip] {
        var chips: [FilterChip] = [.recent]
        chips.append(contentsOf: [VerificationTier.educatorGold, .clinicianBlue].map { FilterChip.verification($0) })
        let difficulties = Array(Set(store.reels.map { $0.difficulty })).sorted()
        chips.append(contentsOf: difficulties.map { FilterChip.difficulty($0) })
        return chips
    }

    private func showLoginPrompt() {
        // Login removed in M0 - will be reimplemented in future milestone
    }

    private func toggleFilterChip(_ chip: FilterChip) {
        if selectedFilterChips.contains(chip) {
            selectedFilterChips.remove(chip)
        } else {
            if chip == .recent {
                selectedFilterChips.remove(.recent)
            }
            selectedFilterChips.insert(chip)
        }
    }

    private func matchesSearch(reel: Reel, tokens: [String]) -> Bool {
        let title = reel.title.lowercased()
        let anatomy = reel.anatomy.lowercased()
        let pathology = reel.pathology.lowercased()
        let device = reel.device.lowercased()
        let tags = reel.tags.map { $0.lowercased() }
        return tokens.allSatisfy { token in
            title.contains(token) || anatomy.contains(token) || pathology.contains(token) || device.contains(token) || tags.contains(where: { $0.contains(token) })
        }
    }

    private func updateSuggestions(for query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        let lower = trimmed.lowercased()
        var results: [SearchSuggestion] = []
        var seen = Set<String>()

        for reel in store.reels {
            if reel.title.lowercased().contains(lower) && seen.insert("title-\(reel.id)").inserted {
                results.append(SearchSuggestion(
                    title: reel.title,
                    subtitle: "Open case",
                    action: .openReel(reel.id)
                ))
            }

            for tag in reel.tags {
                if tag.lowercased().contains(lower) && seen.insert("tag-\(tag)").inserted {
                    results.append(SearchSuggestion(
                        title: tag,
                        subtitle: "Tag match",
                        action: .search(tag)
                    ))
                }
            }

            if reel.anatomy.lowercased().contains(lower) && seen.insert("anatomy-\(reel.anatomy)").inserted {
                results.append(SearchSuggestion(
                    title: reel.anatomy,
                    subtitle: "Anatomy",
                    action: .search(reel.anatomy)
                ))
            }

            if reel.pathology.lowercased().contains(lower) && seen.insert("pathology-\(reel.pathology)").inserted {
                results.append(SearchSuggestion(
                    title: reel.pathology,
                    subtitle: "Pathology",
                    action: .search(reel.pathology)
                ))
            }

            if reel.device.lowercased().contains(lower) && seen.insert("device-\(reel.device)").inserted {
                results.append(SearchSuggestion(
                    title: reel.device,
                    subtitle: "Device",
                    action: .search(reel.device)
                ))
            }
        }

        suggestions = Array(results.prefix(8))
    }

    private func applySuggestion(_ suggestion: SearchSuggestion) {
        switch suggestion.action {
        case .search(let value):
            searchQuery = value
        case .openReel(let id):
            selectedReelID = id
            searchQuery = ""
        }
        suggestions = []
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
    @Environment(\.dismiss) private var dismiss

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
}

private enum FilterChip: Hashable, Identifiable {
    case recent
    case verification(VerificationTier)
    case difficulty(String)

    var id: String {
        switch self {
        case .recent: return "recent"
        case .verification(let tier): return "verification-\(tier.rawValue)"
        case .difficulty(let level): return "difficulty-\(level)"
        }
    }

    var label: String {
        switch self {
        case .recent: return "Recent"
        case .verification(let tier): return tier.displayName
        case .difficulty(let level): return level
        }
    }

    var iconName: String {
        switch self {
        case .recent: return "clock";
        case .verification: return "checkmark.seal"
        case .difficulty: return "star"
        }
    }
}

private struct FilterChipView: View {
    let chip: FilterChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: chip.iconName)
                Text(chip.label)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchSuggestion: Identifiable {
    enum Action {
        case search(String)
        case openReel(UUID)
    }

    let id = UUID()
    let title: String
    let subtitle: String?
    let action: Action
}

#Preview {
    NavigationStack {
        FeedView(selectedReelID: .constant(nil))
    }
    .environmentObject(DemoDataStore())
    .environmentObject(AppState())
}
