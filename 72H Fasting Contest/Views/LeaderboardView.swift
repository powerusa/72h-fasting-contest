import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var tab: LeaderboardTab = .global

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Leaderboard", selection: $tab) {
                    ForEach(LeaderboardTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEntries) { entry in
                            LeaderboardRow(entry: entry)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leaderboard")
        }
    }

    private var filteredEntries: [LeaderboardEntry] {
        switch tab {
        case .global:
            return viewModel.leaderboard
        case .thisWeek:
            return viewModel.leaderboard.filter { $0.status != .stopped }
        case .active:
            return viewModel.leaderboard.filter { $0.status == .active }
        case .completed:
            return viewModel.leaderboard.filter { $0.status == .completed }
        }
    }
}

enum LeaderboardTab: String, CaseIterable, Identifiable {
    case global = "Global"
    case thisWeek = "This Week"
    case active = "Active"
    case completed = "Completed"

    var id: String { rawValue }
}
