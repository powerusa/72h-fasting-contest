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
                        firebaseDebugBanner

                        if filteredEntries.isEmpty {
                            EmptyStateView(title: "No active fasters", message: "The leaderboard will fill when people start a 72H fast.", systemImage: "flame")
                        } else {
                            ForEach(filteredEntries) { entry in
                                LeaderboardRow(entry: entry)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leaderboard")
            .onAppear {
                viewModel.updateLeaderboardScope(tab)
            }
            .onChange(of: tab) { _, newTab in
                viewModel.updateLeaderboardScope(newTab)
            }
        }
    }

    private var firebaseDebugBanner: some View {
        HStack {
            Spacer()
            Image(systemName: viewModel.firebaseDebugInfo.listenerConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(viewModel.firebaseDebugInfo.listenerConnected ? .green : .orange)
                .accessibilityLabel(viewModel.firebaseDebugInfo.listenerConnected ? "Firebase connected" : "Firebase disconnected")
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredEntries: [LeaderboardEntry] {
        switch tab {
        case .global:
            return viewModel.leaderboard.filter { $0.status == .active }
        case .thisWeek:
            return viewModel.leaderboard.filter { $0.status == .active }
        }
    }
}

enum LeaderboardTab: String, CaseIterable, Identifiable {
    case global = "Global"
    case thisWeek = "This Week"

    var id: String { rawValue }
}
