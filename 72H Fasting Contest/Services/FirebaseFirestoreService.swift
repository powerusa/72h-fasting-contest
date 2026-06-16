import Foundation
import FirebaseCore
import FirebaseFirestore

final class FirebaseListenerToken: BackendListener {
    private let registration: ListenerRegistration

    init(_ registration: ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}

final class FirebaseContestBackend: ContestBackend {
    private let authService = AuthService()
    private var db: Firestore {
        Firestore.firestore()
    }
    private let users = "users"
    private let sessions = "fastingSessions"
    private let contests = "contests"
    private let badges = "badges"

    var currentUserId: String? {
        authService.currentUserId
    }

    var isRemoteBackend: Bool {
        FirebaseBootstrap.isConfigured
    }

    func signInAnonymouslyIfNeeded() async throws -> String {
        try await authService.signInAnonymouslyIfNeeded()
    }

    func fetchCurrentUserProfile(userId: String) async throws -> UserProfile? {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let snapshot = try await db.collection(users).document(userId).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return profile(from: data, id: userId)
    }

    func fetchActiveSession(userId: String) async throws -> FastingSession? {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let snapshot = try await db.collection(sessions)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: SessionStatus.active.firestoreValue)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.compactMap { session(from: $0.data(), id: $0.documentID) }.first
    }

    func fetchUserSessions(userId: String) async throws -> [FastingSession] {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let snapshot = try await db.collection(sessions)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.compactMap { session(from: $0.data(), id: $0.documentID) }
    }

    func fetchUserBadges(userId: String) async throws -> [UnlockedBadge] {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let snapshot = try await db.collection(badges)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.compactMap { badge(from: $0.data(), id: $0.documentID) }
    }

    func fetchUserContests(userId: String) async throws -> [Contest] {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let snapshot = try await db.collection(contests)
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents
            .compactMap { contest(from: $0.data(), id: $0.documentID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveUser(_ profile: UserProfile) async throws {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        let doc = db.collection(users).document(profile.id)
        let existing = try await doc.getDocument()
        var data: [String: Any] = [
            "id": profile.id,
            "displayName": profile.displayName,
            "avatarColor": profile.avatarColorHex,
            "countryFlag": profile.countryFlag,
            "premiumUnlocked": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if !existing.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        try await doc.setData(data, merge: true)
    }

    func saveSession(_ session: FastingSession) async throws {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        var data: [String: Any] = [
            "id": session.id,
            "userId": session.userId,
            "contestId": session.contestId as Any,
            "status": session.status.firestoreValue,
            "elapsedSeconds": Int(session.elapsedSeconds),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let endTime = session.endTime {
            data["endTime"] = Timestamp(date: endTime)
        }
        try await db.collection(sessions).document(session.id).setData(data, merge: true)
    }

    func saveContest(_ contest: Contest) async throws {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.firebaseNotConfigured }
        try await db.collection(contests).document(contest.id).setData([
            "id": contest.id,
            "title": contest.title,
            "contestCode": contest.contestCode,
            "creatorUserId": contest.creatorUserId,
            "isPrivate": contest.isPrivate,
            "participantIds": contest.participantIds,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func serverDate() async -> Date {
        Date()
    }

    func startFastingSession(profile: UserProfile, contest: Contest?) async throws -> FastingSession {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }

        if try await fetchActiveSession(userId: profile.id) != nil {
            throw BackendError.activeSessionAlreadyExists
        }

        let doc = db.collection(sessions).document()
        print("Firestore start session collection:", sessions)
        print("Firestore start session document:", doc.documentID)
        print("Firestore start session userId:", profile.id)
        var data: [String: Any] = [
            "id": doc.documentID,
            "userId": profile.id,
            "displayName": profile.displayName,
            "avatarColor": profile.avatarColorHex,
            "countryFlag": profile.countryFlag,
            "startTime": FieldValue.serverTimestamp(),
            "status": SessionStatus.active.firestoreValue,
            "elapsedSeconds": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let contest {
            data["contestId"] = contest.id
            data["contestCode"] = contest.contestCode
        }

        try await doc.setData(data)
        let snapshot = try await doc.getDocument(source: .server)
        guard let session = session(from: snapshot.data() ?? data, id: doc.documentID) else {
            throw BackendError.missingServerTimestamp
        }
        print("Firestore start session server startTime:", session.startTime)
        return session
    }

    func stopFastingSession(_ session: FastingSession) async throws -> FastingSession {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }
        var stopped = session
        stopped.elapsedSeconds = Date().timeIntervalSince(session.startTime)
        stopped.endTime = Date()
        stopped.status = .stopped
        stopped.updatedAt = Date()

        try await db.collection(sessions).document(session.id).updateData([
            "status": SessionStatus.stopped.firestoreValue,
            "elapsedSeconds": Int(stopped.elapsedSeconds),
            "endTime": Timestamp(date: stopped.endTime ?? Date()),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return stopped
    }

    func completeFastingSession(_ session: FastingSession) async throws -> FastingSession {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }
        var completed = session
        completed.elapsedSeconds = AppViewModel.challengeDuration
        completed.endTime = session.startTime.addingTimeInterval(AppViewModel.challengeDuration)
        completed.status = .completed
        completed.updatedAt = Date()

        try await db.collection(sessions).document(session.id).updateData([
            "status": SessionStatus.completed.firestoreValue,
            "elapsedSeconds": Int(AppViewModel.challengeDuration),
            "endTime": Timestamp(date: completed.endTime ?? Date()),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return completed
    }

    func createPrivateContest(title: String, creatorUserId: String) async throws -> Contest {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = try await uniqueContestCode()
        let doc = db.collection(contests).document()
        let now = Date()
        let contest = Contest(
            id: doc.documentID,
            contestCode: code,
            creatorUserId: creatorUserId,
            title: cleanTitle.isEmpty ? "Private 72H Contest" : cleanTitle,
            createdAt: now,
            participantIds: [creatorUserId],
            sessionIds: [],
            isPrivate: true
        )

        try await doc.setData([
            "id": contest.id,
            "title": contest.title,
            "contestCode": contest.contestCode,
            "creatorUserId": contest.creatorUserId,
            "isPrivate": true,
            "participantIds": contest.participantIds,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return contest
    }

    func joinPrivateContest(contestCode: String, userId: String) async throws -> Contest {
        guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }
        let cleanCode = contestCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let snapshot = try await db.collection(contests)
            .whereField("contestCode", isEqualTo: cleanCode)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              var contest = contest(from: document.data(), id: document.documentID) else {
            throw BackendError.contestCodeNotFound
        }

        try await document.reference.updateData([
            "participantIds": FieldValue.arrayUnion([userId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        if !contest.participantIds.contains(userId) {
            contest.participantIds.append(userId)
        }
        return contest
    }

    func unlockBadge(userId: String, badgeType: BadgeType) async throws {
        guard FirebaseBootstrap.isConfigured else { return }
        let badgeId = "\(userId)-\(badgeType.id)"
        try await db.collection(badges).document(badgeId).setData([
            "id": badgeId,
            "userId": userId,
            "badgeType": badgeType.rawValue,
            "unlockedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func leaderboard(for contestId: String?, currentUser: UserProfile?, activeSession: FastingSession?, history: [FastingSession]) async -> [LeaderboardEntry] {
        do {
            guard FirebaseBootstrap.isConfigured else { throw BackendError.noInternetForLeaderboard }
            var query: Query = db.collection(sessions)
            if let contestId {
                query = db.collection(sessions)
                    .whereField("contestId", isEqualTo: contestId)
            }
            let snapshot = try await query.getDocuments()
            return rankedEntries(from: snapshot.documents, currentUserId: currentUser?.id)
        } catch {
            return await OfflineContestBackend().leaderboard(for: contestId, currentUser: currentUser, activeSession: activeSession, history: history)
        }
    }

    func listenToLeaderboard(scope: LeaderboardScope, currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        guard FirebaseBootstrap.isConfigured else {
            onError(BackendError.noInternetForLeaderboard)
            return nil
        }

        switch scope {
        case .global:
            return listenToGlobalLeaderboard(currentUserId: currentUserId, onChange: onChange, onError: onError)
        case .weekly:
            return listenToWeeklyLeaderboard(currentUserId: currentUserId, onChange: onChange, onError: onError)
        case .privateContest(let contestId):
            return listenToPrivateContestLeaderboard(contestId: contestId, currentUserId: currentUserId, onChange: onChange, onError: onError)
        }
    }

    func listenToGlobalLeaderboard(currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        listenToLeaderboardQuery(
            db.collection(sessions),
            queryName: "global: fastingSessions",
            currentUserId: currentUserId,
            onChange: onChange,
            onError: onError
        )
    }

    func listenToWeeklyLeaderboard(currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        listenToLeaderboardQuery(
            db.collection(sessions),
            queryName: "weekly: fastingSessions filtered in Swift",
            currentUserId: currentUserId,
            startDate: Date.startOfCurrentWeek(),
            onChange: onChange,
            onError: onError
        )
    }

    func listenToPrivateContestLeaderboard(contestId: String, currentUserId: String, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        listenToLeaderboardQuery(
            db.collection(sessions).whereField("contestId", isEqualTo: contestId),
            queryName: "privateContest: \(contestId)",
            currentUserId: currentUserId,
            onChange: onChange,
            onError: onError
        )
    }

    private func listenToLeaderboardQuery(_ query: Query, queryName: String, currentUserId: String, startDate: Date? = nil, onChange: @escaping ([LeaderboardEntry], Int) -> Void, onError: @escaping (Error) -> Void) -> BackendListener? {
        print("Firestore leaderboard listener connected:", queryName)
        let registration = query.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("Firestore leaderboard listener error:", error.localizedDescription)
                onError(error)
                return
            }
            guard let self, let documents = snapshot?.documents else {
                onChange([], 0)
                return
            }
            let filteredDocuments = documents.filter { document in
                guard let startDate else { return true }
                guard let startTime = self.timestampDate(document.data()["startTime"]) else { return false }
                return startTime >= startDate
            }
            print("Firestore leaderboard documents loaded:", documents.count)
            onChange(self.rankedEntries(from: filteredDocuments, currentUserId: currentUserId), documents.count)
        }

        return FirebaseListenerToken(registration)
    }

    private func uniqueContestCode() async throws -> String {
        for _ in 0..<10 {
            let code = "FAST-\(Int.random(in: 1000...9999))"
            let snapshot = try await db.collection(contests)
                .whereField("contestCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            if snapshot.documents.isEmpty {
                return code
            }
        }
        return "FAST-\(UUID().uuidString.prefix(4).uppercased())"
    }

    private func rankedEntries(from documents: [QueryDocumentSnapshot], currentUserId: String?) -> [LeaderboardEntry] {
        let entries = documents.compactMap { document -> LeaderboardEntry? in
            let data = document.data()
            guard let userId = data["userId"] as? String else { return nil }
            guard let startTime = timestampDate(data["startTime"]) else {
                print("Leaderboard session pending timestamp:", document.documentID, data["displayName"] as? String ?? "Contestant", data["status"] as? String ?? "-")
                return nil
            }
            let status = SessionStatus(firestoreValue: data["status"] as? String ?? "")
            print("Leaderboard session:", document.documentID, data["displayName"] as? String ?? "Contestant", status.firestoreValue)
            guard status == .active else { return nil }
            let storedElapsed = TimeInterval(data["elapsedSeconds"] as? Int ?? 0)
            let liveElapsed = max(storedElapsed, Date().timeIntervalSince(startTime))

            return LeaderboardEntry(
                id: document.documentID,
                userId: userId,
                rank: 0,
                displayName: data["displayName"] as? String ?? "Contestant",
                avatarColorHex: data["avatarColor"] as? String ?? "#0A84FF",
                countryFlag: data["countryFlag"] as? String ?? "🏁",
                fastingSeconds: min(liveElapsed, AppViewModel.challengeDuration),
                status: status,
                isCurrentUser: userId == currentUserId,
                contestId: data["contestId"] as? String
            )
        }

        return entries.sorted(by: leaderboardSort).enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.id,
                userId: entry.userId,
                rank: index + 1,
                displayName: entry.displayName,
                avatarColorHex: entry.avatarColorHex,
                countryFlag: entry.countryFlag,
                fastingSeconds: entry.fastingSeconds,
                status: entry.status,
                isCurrentUser: entry.isCurrentUser,
                contestId: entry.contestId
            )
        }
    }

    private func leaderboardSort(_ lhs: LeaderboardEntry, _ rhs: LeaderboardEntry) -> Bool {
        return lhs.fastingSeconds > rhs.fastingSeconds
    }

    private func profile(from data: [String: Any], id: String) -> UserProfile {
        UserProfile(
            id: data["id"] as? String ?? id,
            displayName: data["displayName"] as? String ?? "Contestant",
            avatarColorHex: data["avatarColor"] as? String ?? "#0A84FF",
            countryFlag: data["countryFlag"] as? String ?? "🏁",
            createdAt: timestampDate(data["createdAt"]) ?? Date(),
            premiumUnlocked: data["premiumUnlocked"] as? Bool ?? true
        )
    }

    private func session(from data: [String: Any], id: String) -> FastingSession? {
        guard let userId = data["userId"] as? String,
              let startTime = timestampDate(data["startTime"]) else { return nil }
        let contestId = data["contestId"] as? String
        let status = SessionStatus(firestoreValue: data["status"] as? String ?? "")
        let elapsed = TimeInterval(data["elapsedSeconds"] as? Int ?? 0)
        return FastingSession(
            id: data["id"] as? String ?? id,
            userId: userId,
            contestId: contestId,
            startTime: startTime,
            endTime: timestampDate(data["endTime"]),
            elapsedSeconds: status == .active ? min(Date().timeIntervalSince(startTime), AppViewModel.challengeDuration) : elapsed,
            status: status,
            createdAt: timestampDate(data["createdAt"]) ?? startTime,
            updatedAt: timestampDate(data["updatedAt"]) ?? Date(),
            contestType: contestId == nil ? .global : .private,
            rank: nil
        )
    }

    private func contest(from data: [String: Any], id: String) -> Contest? {
        guard let title = data["title"] as? String,
              let contestCode = data["contestCode"] as? String,
              let creatorUserId = data["creatorUserId"] as? String else { return nil }
        return Contest(
            id: data["id"] as? String ?? id,
            contestCode: contestCode,
            creatorUserId: creatorUserId,
            title: title,
            createdAt: timestampDate(data["createdAt"]) ?? Date(),
            participantIds: data["participantIds"] as? [String] ?? [],
            sessionIds: [],
            isPrivate: data["isPrivate"] as? Bool ?? true
        )
    }

    private func badge(from data: [String: Any], id: String) -> UnlockedBadge? {
        guard let userId = data["userId"] as? String,
              let rawBadge = data["badgeType"] as? String,
              let badgeType = BadgeType(rawValue: rawBadge) else { return nil }
        return UnlockedBadge(
            id: data["id"] as? String ?? id,
            userId: userId,
            badgeType: badgeType,
            unlockedAt: timestampDate(data["unlockedAt"]) ?? Date()
        )
    }

    private func timestampDate(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return value as? Date
    }
}

extension Date {
    static func startOfCurrentWeek(calendar: Calendar = .current) -> Date {
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }
}
