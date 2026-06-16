import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    nonisolated static let challengeDuration: TimeInterval = 72 * 3600

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
    @Published var firebaseDebugInfo = FirebaseDebugInfo()

    private let store = PersistenceStore()
    private let remoteBackend = FirebaseContestBackend()
    private let offlineBackend = OfflineContestBackend()
    private let notificationManager = NotificationManager()
    private var reachedMilestones: Set<Int> = []
    private var leaderboardListener: BackendListener?
    private var leaderboardScope: LeaderboardScope = .global
    private var fastingSessionsLoadedFromFirestore = 0
    private var lastLeaderboardListenerError: String?
    private var leaderboardListenerConnected = false

    private var backend: ContestBackend {
        FirebaseBootstrap.isConfigured ? remoteBackend : offlineBackend
    }

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
        profile = snapshot.profile.map { existingProfile in
            var unlockedProfile = existingProfile
            unlockedProfile.premiumUnlocked = true
            return unlockedProfile
        }
        activeSession = snapshot.activeSession
        history = snapshot.history
        contests = snapshot.contests
        unlockedBadges = snapshot.unlockedBadges
        notificationPreferences = snapshot.notificationPreferences
        recalculateActiveSession()
        await syncRemoteStateIfAvailable()
        await notificationManager.requestAuthorizationIfNeeded()
        updateFirebaseDebugInfo()
        persist()
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

        let userId: String
        if let currentUserId = backend.currentUserId {
            userId = currentUserId
        } else if backend.isRemoteBackend, let signedInId = try? await backend.signInAnonymouslyIfNeeded() {
            userId = signedInId
        } else {
            userId = self.profile?.id ?? "anon-\(UUID().uuidString.prefix(8))"
        }

        let profile = UserProfile(
            id: userId,
            displayName: cleanName,
            avatarColorHex: avatarColorHex,
            countryFlag: countryFlag.isEmpty ? "🏁" : countryFlag,
            createdAt: self.profile?.createdAt ?? Date(),
            premiumUnlocked: true
        )
        self.profile = profile
        do {
            try await backend.saveUser(profile)
        } catch {
            errorMessage = "Profile saved locally. Backend sync will retry later."
        }
        persist()
        startLeaderboardListener(scope: leaderboardScope)
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
        guard backend.isRemoteBackend else {
            errorMessage = "Firebase is not connected. Add GoogleService-Info.plist to the app target before starting a synced fast."
            updateFirebaseDebugInfo()
            return
        }
        guard activeSession == nil || activeSession?.status != .active else {
            errorMessage = "You already have an active 72H fast."
            return
        }
        guard var profile else { return }
        let authUserId: String
        do {
            authUserId = try await backend.signInAnonymouslyIfNeeded()
        } catch {
            errorMessage = "Could not sign in to Firebase. \(friendlyMessage(for: error))"
            updateFirebaseDebugInfo()
            return
        }

        if profile.id != authUserId {
            profile.id = authUserId
        }

        self.profile = profile
        do {
            try await backend.saveUser(profile)
        } catch {
            errorMessage = "Could not sync your profile to Firebase. \(friendlyMessage(for: error))"
            persist()
            updateFirebaseDebugInfo()
            return
        }
        persist()
        updateFirebaseDebugInfo()

        let contest = contests.first(where: { $0.id == contestId })

        let session: FastingSession
        do {
            session = try await backend.startFastingSession(profile: profile, contest: contest)
        } catch {
            errorMessage = friendlyMessage(for: error)
            return
        }

        activeSession = session
        reachedMilestones = []
        unlock(.firstStart)
        haptic(.medium)
        notificationManager.scheduleFastNotifications(from: session.startTime, preferences: notificationPreferences)
        persist()
        startLeaderboardListener(scope: leaderboardScope)
        await refreshLeaderboard()
        updateFirebaseDebugInfo()
    }

    func stopFast() async {
        guard let session = activeSession, session.status == .active else { return }
        let stoppedSession: FastingSession
        do {
            stoppedSession = try await backend.stopFastingSession(session)
        } catch {
            errorMessage = friendlyMessage(for: error)
            return
        }

        activeSession = nil
        history.insert(stoppedSession, at: 0)
        notificationManager.cancelFastNotifications()
        haptic(.heavy)
        persist()
        await refreshLeaderboard()
    }

    func tick() {
        recalculateActiveSession()
        if !backend.isRemoteBackend {
            Task { await refreshLeaderboard() }
        }
    }

    func createPrivateContest(title: String) async {
        guard let profile else { return }

        do {
            let contest = try await backend.createPrivateContest(title: title, creatorUserId: profile.id)
            contests.insert(contest, at: 0)
            persist()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func joinContest(code: String) async {
        guard let profile else { return }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else { return }

        do {
            let contest = try await backend.joinPrivateContest(contestCode: cleanCode, userId: profile.id)
            if let index = contests.firstIndex(where: { $0.id == contest.id }) {
                contests[index] = contest
            } else {
                contests.insert(contest, at: 0)
            }
            persist()
        } catch {
            errorMessage = friendlyMessage(for: error)
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
            Task {
                _ = try? await backend.completeFastingSession(session)
                await refreshLeaderboard()
            }
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
        Task {
            try? await backend.unlockBadge(userId: profile.id, badgeType: badgeType)
        }
        persist()
    }

    private func syncRemoteStateIfAvailable() async {
        guard backend.isRemoteBackend else {
            await refreshLeaderboard()
            return
        }

        do {
            let userId = try await backend.signInAnonymouslyIfNeeded()
            print("Firebase bootstrap uid:", userId)
            print("Firebase bootstrap bundleID:", Bundle.main.bundleIdentifier ?? "-")

            if let remoteProfile = try await backend.fetchCurrentUserProfile(userId: userId) {
                var unlockedProfile = remoteProfile
                unlockedProfile.premiumUnlocked = true
                profile = unlockedProfile
            } else if var cachedProfile = profile {
                cachedProfile.id = userId
                cachedProfile.premiumUnlocked = true
                profile = cachedProfile
                try await backend.saveUser(cachedProfile)
            }

            let remoteSessions = try await backend.fetchUserSessions(userId: userId)
            var remoteActiveSession = remoteSessions.first(where: { $0.status == .active })
            if remoteActiveSession == nil {
                remoteActiveSession = try await backend.fetchActiveSession(userId: userId)
            }
            if let remoteActiveSession {
                activeSession = remoteActiveSession
                reachedMilestones = Set(Milestone.all.filter { remoteActiveSession.elapsedSeconds >= TimeInterval($0.hour * 3600) }.map(\.hour))
            } else if let localActiveSession = activeSession,
                      localActiveSession.status == .active,
                      let profile {
                let migratedSession = try await backend.startFastingSession(profile: profile, contest: nil)
                activeSession = migratedSession
                reachedMilestones = []
                print("Firebase migrated local active fast to Firestore:", migratedSession.id)
            }
            history = remoteSessions.filter { $0.status != .active }
            unlockedBadges = try await backend.fetchUserBadges(userId: userId)
            contests = try await backend.fetchUserContests(userId: userId)
            recalculateActiveSession()
            startLeaderboardListener(scope: leaderboardScope)
            updateFirebaseDebugInfo()
        } catch {
            errorMessage = friendlyMessage(for: error)
            lastLeaderboardListenerError = friendlyMessage(for: error)
            leaderboardListenerConnected = false
            updateFirebaseDebugInfo()
            await refreshLeaderboard()
        }
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

    func updateLeaderboardScope(_ tab: LeaderboardTab) {
        switch tab {
        case .global:
            leaderboardScope = .global
        case .thisWeek:
            leaderboardScope = .weekly
        }
        startLeaderboardListener(scope: leaderboardScope)
    }

    private func startLeaderboardListener(scope: LeaderboardScope) {
        leaderboardListener?.remove()
        leaderboardListenerConnected = false
        lastLeaderboardListenerError = nil
        updateFirebaseDebugInfo()
        guard backend.isRemoteBackend else {
            lastLeaderboardListenerError = "Firebase is not connected. Add GoogleService-Info.plist to the app target."
            updateFirebaseDebugInfo()
            Task { await refreshLeaderboard() }
            return
        }
        guard let userId = profile?.id ?? backend.currentUserId else {
            lastLeaderboardListenerError = "Firebase Auth uid is missing."
            updateFirebaseDebugInfo()
            Task { await refreshLeaderboard() }
            return
        }

        leaderboardListener = backend.listenToLeaderboard(
            scope: scope,
            currentUserId: userId,
            onChange: { [weak self] entries, loadedCount in
                Task { @MainActor in
                    self?.fastingSessionsLoadedFromFirestore = loadedCount
                    self?.leaderboardListenerConnected = true
                    self?.lastLeaderboardListenerError = nil
                    self?.leaderboard = entries
                    if let rank = entries.first(where: \.isCurrentUser)?.rank, rank <= 10 {
                        self?.unlock(.top10)
                    }
                    self?.updateFirebaseDebugInfo()
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    let message = self?.friendlyMessage(for: error) ?? error.localizedDescription
                    self?.leaderboardListenerConnected = false
                    self?.lastLeaderboardListenerError = message
                    self?.errorMessage = message
                    self?.updateFirebaseDebugInfo()
                }
            }
        )
        leaderboardListenerConnected = leaderboardListener != nil
        updateFirebaseDebugInfo()
    }

    func refreshFirebaseDebugInfo() {
        updateFirebaseDebugInfo()
    }

    private func updateFirebaseDebugInfo() {
        firebaseDebugInfo = FirebaseBootstrap.debugInfo(
            authUID: backend.currentUserId,
            displayName: profile?.displayName,
            fastingSessionsLoaded: fastingSessionsLoadedFromFirestore,
            lastListenerError: lastLeaderboardListenerError,
            leaderboardQueryType: leaderboardScope.debugName,
            listenerConnected: leaderboardListenerConnected
        )
    }

    private func friendlyMessage(for error: Error) -> String {
        if let backendError = error as? BackendError {
            switch backendError {
            case .firebaseNotConfigured:
                return "Firebase is not configured yet. Add GoogleService-Info.plist to the app target."
            case .noAuthenticatedUser:
                return "Could not sign in anonymously. Check Firebase Authentication."
            case .activeSessionAlreadyExists:
                return "You already have an active 72H fast on another device."
            case .contestCodeNotFound:
                return "Contest code not found. Check the FAST code and try again."
            case .missingServerTimestamp:
                return "Firebase did not return the official server start time yet. Try again."
            case .noInternetForLeaderboard:
                return "Internet connection is required for live contests and leaderboard sync."
            }
        }
        let nsError = error as NSError
        let rawDescription = "\(nsError.localizedDescription) \(nsError.userInfo)"
        if rawDescription.contains("CONFIGURATION_NOT_FOUND") {
            return "Firebase Authentication is not enabled yet. Enable Anonymous sign-in in Firebase Console."
        }
        return nsError.localizedDescription
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
