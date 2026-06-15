import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    static let challengeDuration: TimeInterval = 72 * 3600

    @Published var hasCompletedOnboarding = false
    @Published var hasAcceptedSafety = false
    @Published var profile: UserProfile?
    @Published var activeSession: FastingSession?
    @Published var history: [FastingSession] = []
    @Published var contests: [Contest] = []
    @Published var unlockedBadges: [UnlockedBadge] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var notificationPreferences = NotificationPreferences.default
    @Published var celebrationMilestone: Milestone?
    @Published var errorMessage: String?

    let premiumStore = PremiumStore()

    private let store = PersistenceStore()
    private let backend: ContestBackend = OfflineContestBackend()
    private let notificationManager = NotificationManager()
    private var reachedMilestones: Set<Int> = []

    var elapsedSeconds: TimeInterval {
        activeSession?.elapsedSeconds ?? 0
    }

    var remainingSeconds: TimeInterval {
        max(0, Self.challengeDuration - elapsedSeconds)
    }

    var progress: Double {
        min(1, max(0, elapsedSeconds / Self.challengeDuration))
    }

    var status: SessionStatus {
        activeSession?.status ?? .notStarted
    }

    var stats: UserStats {
        let completed = history.filter { $0.status == .completed }
        let best = history.map(\.elapsedSeconds).max() ?? activeSession?.elapsedSeconds ?? 0
        let total = history.map(\.elapsedSeconds).reduce(0, +) + (activeSession?.elapsedSeconds ?? 0)
        let currentRank = leaderboard.first(where: \.isCurrentUser)?.rank ?? 0
        let bestRank = min(history.compactMap(\.rank).min() ?? currentRank, currentRank == 0 ? Int.max : currentRank)
        let streak = completedSuffixCount(in: history)
        return UserStats(
            completedChallenges: completed.count,
            bestFastingSeconds: best,
            totalFastingSeconds: total,
            currentRank: currentRank,
            bestRank: bestRank == Int.max ? 0 : bestRank,
            currentStreak: streak,
            longestStreak: max(streak, completed.count),
            badgesUnlocked: unlockedBadges.count
        )
    }

    func bootstrap() async {
        let snapshot = await store.load()
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        hasAcceptedSafety = snapshot.hasAcceptedSafety
        profile = snapshot.profile
        activeSession = snapshot.activeSession
        history = snapshot.history
        contests = snapshot.contests
        unlockedBadges = snapshot.unlockedBadges
        notificationPreferences = snapshot.notificationPreferences
        recalculateActiveSession()
        await refreshLeaderboard()
        await premiumStore.loadProduct()
        await notificationManager.requestAuthorizationIfNeeded()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        persist()
    }

    func saveProfile(displayName: String, avatarColorHex: String, countryFlag: String) async {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Add a display name to continue."
            return
        }

        let profile = UserProfile(
            id: self.profile?.id ?? "anon-\(UUID().uuidString.prefix(8))",
            displayName: cleanName,
            avatarColorHex: avatarColorHex,
            countryFlag: countryFlag.isEmpty ? "🏁" : countryFlag,
            createdAt: self.profile?.createdAt ?? Date(),
            premiumUnlocked: self.profile?.premiumUnlocked ?? false
        )
        self.profile = profile
        do {
            try await backend.saveUser(profile)
        } catch {
            errorMessage = "Profile saved locally. Backend sync will retry later."
        }
        persist()
        await refreshLeaderboard()
    }

    func acceptSafetyAgreement() {
        hasAcceptedSafety = true
        persist()
    }

    func startFast(contestId: String? = nil) async {
        guard hasAcceptedSafety else {
            errorMessage = "Review and accept the safety agreement first."
            return
        }
        guard activeSession == nil || activeSession?.status != .active else {
            errorMessage = "You already have an active 72H fast."
            return
        }
        guard let profile else { return }

        let now = await backend.serverDate()
        let contest = contests.first(where: { $0.id == contestId })
        let session = FastingSession(
            id: UUID().uuidString,
            userId: profile.id,
            contestId: contestId,
            startTime: now,
            endTime: nil,
            elapsedSeconds: 0,
            status: .active,
            createdAt: now,
            updatedAt: now,
            contestType: contest?.isPrivate == true ? .private : .global,
            rank: nil
        )

        activeSession = session
        reachedMilestones = []
        unlock(.firstStart)
        haptic(.medium)
        notificationManager.scheduleFastNotifications(from: now, preferences: notificationPreferences)
        try? await backend.saveSession(session)
        persist()
        await refreshLeaderboard()
    }

    func stopFast() async {
        guard var session = activeSession, session.status == .active else { return }
        session.elapsedSeconds = Date().timeIntervalSince(session.startTime)
        session.endTime = Date()
        session.updatedAt = Date()
        session.status = .stopped
        activeSession = nil
        history.insert(session, at: 0)
        notificationManager.cancelFastNotifications()
        haptic(.heavy)
        try? await backend.saveSession(session)
        persist()
        await refreshLeaderboard()
    }

    func tick() {
        recalculateActiveSession()
        Task { await refreshLeaderboard() }
    }

    func createPrivateContest(title: String) async {
        guard let profile else { return }
        guard profile.premiumUnlocked else {
            errorMessage = "Private contests are part of the one-time premium unlock."
            return
        }

        let contest = Contest(
            id: UUID().uuidString,
            contestCode: String(UUID().uuidString.prefix(6)).uppercased(),
            creatorUserId: profile.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Private 72H Contest" : title,
            createdAt: Date(),
            participantIds: [profile.id],
            sessionIds: [],
            isPrivate: true
        )
        contests.insert(contest, at: 0)
        try? await backend.saveContest(contest)
        persist()
    }

    func joinContest(code: String) {
        guard let profile else { return }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else { return }

        if let index = contests.firstIndex(where: { $0.contestCode == cleanCode }) {
            if !contests[index].participantIds.contains(profile.id) {
                contests[index].participantIds.append(profile.id)
            }
        } else {
            contests.insert(
                Contest(
                    id: UUID().uuidString,
                    contestCode: cleanCode,
                    creatorUserId: "friend",
                    title: "Friend Contest",
                    createdAt: Date(),
                    participantIds: [profile.id],
                    sessionIds: [],
                    isPrivate: true
                ),
                at: 0
            )
        }
        persist()
    }

    func unlockPremiumLocally() {
        guard var profile else { return }
        profile.premiumUnlocked = true
        self.profile = profile
        persist()
    }

    func restorePurchases() async {
        if await premiumStore.restore() {
            unlockPremiumLocally()
        }
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) {
        notificationPreferences = preferences
        if let activeSession, activeSession.status == .active {
            notificationManager.scheduleFastNotifications(from: activeSession.startTime, preferences: preferences)
        }
        persist()
    }

    func filteredHistory(_ filter: HistoryFilter) -> [FastingSession] {
        switch filter {
        case .all: return history
        case .completed: return history.filter { $0.status == .completed }
        case .stopped: return history.filter { $0.status == .stopped }
        case .privateContests: return history.filter { $0.contestType == .private }
        }
    }

    func persist() {
        let snapshot = AppSnapshot(
            hasCompletedOnboarding: hasCompletedOnboarding,
            hasAcceptedSafety: hasAcceptedSafety,
            profile: profile,
            activeSession: activeSession,
            history: history,
            contests: contests,
            unlockedBadges: unlockedBadges,
            notificationPreferences: notificationPreferences
        )
        Task {
            await store.save(snapshot)
        }
    }

    private func recalculateActiveSession() {
        guard var session = activeSession, session.status == .active else { return }
        let elapsed = Date().timeIntervalSince(session.startTime)
        session.elapsedSeconds = min(elapsed, Self.challengeDuration)
        session.updatedAt = Date()

        handleMilestones(for: session.elapsedSeconds)

        if elapsed >= Self.challengeDuration {
            session.elapsedSeconds = Self.challengeDuration
            session.status = .completed
            session.endTime = session.startTime.addingTimeInterval(Self.challengeDuration)
            session.rank = leaderboard.first(where: \.isCurrentUser)?.rank
            activeSession = nil
            history.insert(session, at: 0)
            notificationManager.cancelFastNotifications()
            unlock(.finisher72)
            if history.filter({ $0.status == .completed }).count >= 3 {
                unlock(.threeTimeFinisher)
            }
            haptic(.heavy)
        } else {
            activeSession = session
        }
        persist()
    }

    private func handleMilestones(for elapsed: TimeInterval) {
        for milestone in Milestone.all where elapsed >= TimeInterval(milestone.hour * 3600) && !reachedMilestones.contains(milestone.hour) {
            reachedMilestones.insert(milestone.hour)
            celebrationMilestone = milestone
            unlockBadgeForMilestone(hour: milestone.hour)
            haptic(.light)
        }
    }

    private func unlockBadgeForMilestone(hour: Int) {
        switch hour {
        case 12: unlock(.warrior12)
        case 24: unlock(.hero24)
        case 36: unlock(.halfway36)
        case 48: unlock(.strong48)
        case 60: unlock(.stretch60)
        case 72: unlock(.finisher72)
        default: break
        }
    }

    private func unlock(_ badgeType: BadgeType) {
        guard let profile, !unlockedBadges.contains(where: { $0.badgeType == badgeType }) else { return }
        unlockedBadges.append(
            UnlockedBadge(
                id: "\(profile.id)-\(badgeType.id)",
                userId: profile.id,
                badgeType: badgeType,
                unlockedAt: Date()
            )
        )
        persist()
    }

    private func refreshLeaderboard() async {
        leaderboard = await backend.leaderboard(
            for: nil,
            currentUser: profile,
            activeSession: activeSession,
            history: history
        )
        if let rank = leaderboard.first(where: \.isCurrentUser)?.rank, rank <= 10 {
            unlock(.top10)
        }
    }

    private func completedSuffixCount(in sessions: [FastingSession]) -> Int {
        var count = 0
        for session in sessions {
            if session.status == .completed {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case completed = "Completed"
    case stopped = "Stopped"
    case privateContests = "Private"

    var id: String { rawValue }
}
