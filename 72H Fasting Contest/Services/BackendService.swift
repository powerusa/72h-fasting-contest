import Foundation

protocol ContestBackend {
    func saveUser(_ profile: UserProfile) async throws
    func saveSession(_ session: FastingSession) async throws
    func saveContest(_ contest: Contest) async throws
    func serverDate() async -> Date
    func leaderboard(for contestId: String?, currentUser: UserProfile?, activeSession: FastingSession?, history: [FastingSession]) async -> [LeaderboardEntry]
}

struct OfflineContestBackend: ContestBackend {
    func saveUser(_ profile: UserProfile) async throws {}
    func saveSession(_ session: FastingSession) async throws {}
    func saveContest(_ contest: Contest) async throws {}
    func serverDate() async -> Date { Date() }

    func leaderboard(for contestId: String?, currentUser: UserProfile?, activeSession: FastingSession?, history: [FastingSession]) async -> [LeaderboardEntry] {
        let userEntry = makeCurrentUserEntry(currentUser: currentUser, activeSession: activeSession, history: history)

        var seeded = [
            LeaderboardEntry(id: "seed-1", userId: "seed-1", rank: 1, displayName: "Maya", avatarColorHex: "#34C759", countryFlag: "🇨🇦", fastingSeconds: 72 * 3600, status: .completed, isCurrentUser: false),
            LeaderboardEntry(id: "seed-2", userId: "seed-2", rank: 2, displayName: "Jonas", avatarColorHex: "#0A84FF", countryFlag: "🇩🇰", fastingSeconds: 71 * 3600 + 1800, status: .active, isCurrentUser: false),
            LeaderboardEntry(id: "seed-3", userId: "seed-3", rank: 3, displayName: "Ari", avatarColorHex: "#FF9F0A", countryFlag: "🇺🇸", fastingSeconds: 63 * 3600, status: .active, isCurrentUser: false),
            LeaderboardEntry(id: "seed-4", userId: "seed-4", rank: 4, displayName: "Noor", avatarColorHex: "#AF52DE", countryFlag: "🇬🇧", fastingSeconds: 48 * 3600, status: .active, isCurrentUser: false),
            LeaderboardEntry(id: "seed-5", userId: "seed-5", rank: 5, displayName: "Kai", avatarColorHex: "#FF375F", countryFlag: "🇯🇵", fastingSeconds: 29 * 3600, status: .stopped, isCurrentUser: false)
        ]

        if let userEntry {
            seeded.append(userEntry)
        }

        let sorted = seeded.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }

        return sorted.enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.id,
                userId: entry.userId,
                rank: index + 1,
                displayName: entry.displayName,
                avatarColorHex: entry.avatarColorHex,
                countryFlag: entry.countryFlag,
                fastingSeconds: entry.fastingSeconds,
                status: entry.status,
                isCurrentUser: entry.isCurrentUser
            )
        }
    }

    private func makeCurrentUserEntry(currentUser: UserProfile?, activeSession: FastingSession?, history: [FastingSession]) -> LeaderboardEntry? {
        guard let currentUser else { return nil }
        let bestHistory = history.max { $0.elapsedSeconds < $1.elapsedSeconds }
        let selected = activeSession ?? bestHistory
        let seconds = selected?.elapsedSeconds ?? 0
        let status = selected?.status ?? .notStarted
        return LeaderboardEntry(
            id: currentUser.id,
            userId: currentUser.id,
            rank: 0,
            displayName: currentUser.displayName,
            avatarColorHex: currentUser.avatarColorHex,
            countryFlag: currentUser.countryFlag,
            fastingSeconds: seconds,
            status: status,
            isCurrentUser: true
        )
    }

    private func score(_ entry: LeaderboardEntry) -> Double {
        switch entry.status {
        case .completed:
            return 3_000_000 + entry.fastingSeconds
        case .active:
            return 2_000_000 + entry.fastingSeconds
        case .stopped:
            return 1_000_000 + entry.fastingSeconds
        case .notStarted:
            return entry.fastingSeconds
        }
    }
}
