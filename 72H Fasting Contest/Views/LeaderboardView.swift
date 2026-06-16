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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(viewModel.firebaseDebugInfo.listenerConnected ? "Firebase connected" : "Firebase disconnected", systemImage: viewModel.firebaseDebugInfo.listenerConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(viewModel.firebaseDebugInfo.listenerConnected ? .green : .orange)
                Spacer()
                Text("\(viewModel.firebaseDebugInfo.fastingSessionsLoaded) docs")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("Project: \(viewModel.firebaseDebugInfo.projectID)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if viewModel.firebaseDebugInfo.lastListenerError != "-" {
                Text(viewModel.firebaseDebugInfo.lastListenerError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
