import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingSettings = false

    var body: some View {
        TabView {
            ChallengeView()
                .tabItem { Label("Challenge", systemImage: "timer") }
            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "list.number") }
            ContestsView()
                .tabItem { Label("Contests", systemImage: "person.3.fill") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .overlay(alignment: .top) {
            if let milestone = viewModel.celebrationMilestone {
                CelebrationBanner(milestone: milestone)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation {
                                viewModel.celebrationMilestone = nil
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .environment(\.openSettings, OpenSettingsAction { showingSettings = true })
    }
}

private struct CelebrationBanner: View {
    let milestone: Milestone

    var body: some View {
        Label("\(milestone.hour)H \(milestone.title)", systemImage: "sparkles")
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: Capsule())
            .shadow(radius: 12)
    }
}

struct OpenSettingsAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue = OpenSettingsAction {}
}

extension EnvironmentValues {
    var openSettings: OpenSettingsAction {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
