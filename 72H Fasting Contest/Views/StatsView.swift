import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    StatCard(title: "Completed", value: "\(viewModel.stats.completedChallenges)", systemImage: "checkmark.seal.fill")
                    StatCard(title: "Best Time", value: viewModel.stats.bestFastingSeconds.compactHoursString, systemImage: "timer")
                    StatCard(title: "Total Hours", value: "\(Int(viewModel.stats.totalFastingSeconds / 3600))h", systemImage: "sum")
                    StatCard(title: "Current Rank", value: viewModel.stats.currentRank == 0 ? "--" : "#\(viewModel.stats.currentRank)", systemImage: "list.number")
                    StatCard(title: "Best Rank", value: viewModel.stats.bestRank == 0 ? "--" : "#\(viewModel.stats.bestRank)", systemImage: "star.fill")
                    StatCard(title: "Streak", value: "\(viewModel.stats.currentStreak)", systemImage: "flame.fill")
                    StatCard(title: "Longest Streak", value: "\(viewModel.stats.longestStreak)", systemImage: "bolt.fill")
                    StatCard(title: "Badges", value: "\(viewModel.stats.badgesUnlocked)", systemImage: "medal.fill")
                }
                .padding()

                BadgeGalleryView()
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
        }
    }
}

struct BadgeGalleryView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.title3.bold())
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BadgeType.allCases) { badge in
                    BadgeCard(
                        badgeType: badge,
                        unlockedBadge: viewModel.unlockedBadges.first(where: { $0.badgeType == badge })
                    )
                }
            }
        }
    }
}
