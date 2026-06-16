import Foundation

protocol BackendListener {
    func remove()
}

struct ClosureBackendListener: BackendListener {
    let onRemove: () -> Void
    func remove() {
        onRemove()
    }
}

protocol ContestBackend {
    var currentUserId: String? { get }
    var isRemoteBackend: Bool { get }

    func signInAnonymouslyIfNeeded() async throws -> String
    func fetchCurrentUserProfile(userId: String) async throws -> UserProfile?
    func fetchActiveSession(userId: String) async throws -> FastingSession?
    func fetchUserSessions(userId: String) async throws -> [FastingSession]
    func fetchUserBadges(userId: String) async throws -> [UnlockedBadge]
    func fetchUserContests(userId: String) async throws -> [Contest]
    func saveUser(_ profile: UserProfile) async throws
    func saveSession(_ session: FastingSession) async throws
    func saveContest(_ contest: Contest) async throws
    func serverDate() async -> Date
    func startFastingSession(profile: UserProfile, contest: Contest?) async throws -> FastingSession
    func stopFastingSession(_ session: FastingSession) async throws -> FastingSession
    func completeFastingSession(_ session: FastingSession) async throws -> FastingSession
    func createPrivateContest(title: String, creatorUserId: String) async throws -> Contest
    func joinPrivateContest(contestCode: String, userId: String) async throws -> Contest
    func unlockBadge(userId: String, badgeType: BadgeType) async throws
    func leaderboard(for contestId: String?, currentUser: UserProfile?, activeSession: FastingSession?, history: [FastingSession]) async -> [LeaderboardEntry]
    func listenToLeaderboard(scope: LeaderboardScope, currentUserId: String, onChange: @escaping ([LeaderboardEntry]) -> Void, onError: @escaping (Error) -> Void) -> BackendListener?
}

struct OfflineContestBackend: ContestBackend {
    var currentUserId: String? { nil }
    var isRemoteBackend: Bool { false }

    func signInAnonymouslyIfNeeded() async throws -> String {
        "anon-\(UUID().uuidString.prefix(8))"
    }

    func fetchCurrentUserProfile(userId: String) async throws -> UserProfile? { nil }
    func fetchActiveSession(userId: String) async throws -> FastingSession? { nil }
    func fetchUserSessions(userId: String) async throws -> [FastingSession] { [] }
    func fetchUserBadges(userId: String) async throws -> [UnlockedBadge] { [] }
    func fetchUserContests(userId: String) async throws -> [Contest] { [] }
    func saveUser(_ profile: UserProfile) async throws {}
    func saveSession(_ session: FastingSession) async throws {}
    func saveContest(_ contest: Contest) async throws {}
    func serverDate() async -> Date { Date() }

    func startFastingSession(profile: UserProfile, contest: Contest?) async throws -> FastingSession {
        let now = Date()
        return FastingSession(
            id: UUID().uuidString,
            userId: profile.id,
            contestId: contest?.id,
            startTime: now,
            endTime: nil,
            elapsedSeconds: 0,
            status: .active,
            createdAt: now,
            updatedAt: now,
            contestType: contest?.isPrivate == true ? .private : .global,
            rank: nil
        )
    }

    func stopFastingSession(_ session: FastingSession) async throws -> FastingSession {
        var stopped = session
        stopped.elapsedSeconds = Date().timeIntervalSince(stopped.startTime)
        stopped.endTime = Date()
        stopped.updatedAt = Date()
        stopped.status = .stopped
        return stopped
    }

    func completeFastingSession(_ session: FastingSession) async throws -> FastingSession {
        var completed = session
        completed.elapsedSeconds = AppViewModel.challengeDuration
        completed.endTime = completed.startTime.addingTimeInterval(AppViewModel.challengeDuration)
        completed.updatedAt = Date()
        completed.status = .completed
        return completed
    }

    func createPrivateContest(title: String, creatorUserId: String) async throws -> Contest {
        Contest(
            id: UUID().uuidString,
            contestCode: String(UUID().uuidString.prefix(6)).uppercased(),
            creatorUserId: creatorUserId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Private 72H Contest" : title,
            createdAt: Date(),
            participantIds: [creatorUserId],
            sessionIds: [],
            isPrivate: true
        )
    }

    func joinPrivateContest(contestCode: String, userId: String) async throws -> Contest {
        Contest(
            id: UUID().uuidString,
            contestCode: contestCode,
            creatorUserId: "friend",
            title: "Friend Contest",
            createdAt: Date(),
            participantIds: [userId],
            sessionIds: [],
            isPrivate: true
        )
    }

    func unlockBadge(userId: String, badgeType: BadgeType) async throws {}

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

    func listenToLeaderboard(scope: LeaderboardScope, currentUserId: String, onChange: @escaping ([LeaderboardEntry]) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        nil
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
