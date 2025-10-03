import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRole: ServiceLine = .pulmonary
    @State private var tabIndex: Int = 0

    private let cards: [OnboardingCard] = OnboardingCard.defaultCards

    var body: some View {
        VStack {
            TabView(selection: $tabIndex) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: card.systemImage)
                            .font(.system(size: 56))
                            .foregroundStyle(card.tint)
                        Text(card.title)
                            .font(.title.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(card.subtitle)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        Spacer()
                        if index == cards.indices.last {
                            roleSelection
                            actionButtons
                        }
                        Spacer(minLength: 32)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            if tabIndex < cards.count - 1 {
                Button("Next") {
                    withAnimation { tabIndex += 1 }
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
        .onAppear {
            if let role = appState.currentUser.role {
                selectedRole = role
            }
        }
    }

    private var roleSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your role focus")
                .font(.headline)
            Picker("Specialty", selection: $selectedRole) {
                ForEach(ServiceLine.allCases) { line in
                    Text(line.displayName).tag(line)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                appState.completeOnboarding(with: selectedRole, navigation: .openSampleCase)
                dismiss()
            } label: {
                Label("View sample case", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                appState.completeOnboarding(with: selectedRole, navigation: .openCreator(selectedRole))
                dismiss()
            } label: {
                Label("Create your own", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                appState.completeOnboarding(with: selectedRole, navigation: nil)
                dismiss()
            } label: {
                Text("Explore feed first")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}

private struct OnboardingCard {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    static let defaultCards: [OnboardingCard] = [
        OnboardingCard(
            title: "Create cases in minutes",
            subtitle: "Import clips, add overlays, and publish teaching reels with built-in PHI guardrails.",
            systemImage: "wand.and.rays",
            tint: .orange
        ),
        OnboardingCard(
            title: "Share safely, learn fast",
            subtitle: "Automated privacy review keeps you compliant while learners get structured pearls and CME-ready content.",
            systemImage: "shield.checkered",
            tint: .blue
        ),
        OnboardingCard(
            title: "Tailor EndoReels to your specialty",
            subtitle: "Pick your role to personalize the feed and jump into a sample case or start creating right away.",
            systemImage: "stethoscope",
            tint: .green
        )
    ]
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
