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
    func listenToLeaderboard(scope: LeaderboardScope, currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener?
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
        guard let userEntry = makeCurrentUserEntry(currentUser: currentUser, activeSession: activeSession) else {
            return []
        }

        return [userEntry].enumerated().map { index, entry in
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

    func listenToLeaderboard(scope: LeaderboardScope, currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        nil
    }

    private func makeCurrentUserEntry(currentUser: UserProfile?, activeSession: FastingSession?) -> LeaderboardEntry? {
        guard let currentUser, let activeSession, activeSession.status == .active else { return nil }
        return LeaderboardEntry(
            id: currentUser.id,
            userId: currentUser.id,
            rank: 0,
            displayName: currentUser.displayName,
            avatarColorHex: currentUser.avatarColorHex,
            countryFlag: currentUser.countryFlag,
            fastingSeconds: activeSession.elapsedSeconds,
            status: .active,
            isCurrentUser: true
        )
    }
}
