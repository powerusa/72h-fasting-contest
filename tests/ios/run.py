from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
src=(root / '72H Fasting Contest/Services/FirebaseFirestoreService.swift').read_text()
models=(root / '72H Fasting Contest/Models/AppModels.swift').read_text()
token=src[src.index('final class FirebaseListenerToken'):src.index('final class FirebaseContestBackend')]
listen=src[src.index('    private func listenToLeaderboardQuery'):src.index('    private func uniqueContestCode')].replace('private func','func')
rank=src[src.index('    private func rankedEntries'):src.index('    private func profile(')]
entry = '' # Compile the actual AppModels.swift alongside the test harness.
date=src[src.index('extension Date {'):]
stubs='''import Foundation
protocol BackendListener { func remove() }
class ListenerRegistration { var removed = false; func remove() { removed = true } }
struct Metadata { var isFromCache = false }
struct Snapshot { var documents: [QueryDocumentSnapshot]; var metadata = Metadata() }
class Query { var callback: ((Snapshot?, Error?) -> Void)?; let registration = ListenerRegistration()
func addSnapshotListener(includeMetadataChanges: Bool, listener: @escaping (Snapshot?, Error?) -> Void) -> ListenerRegistration { callback = listener; return registration }
}
struct QueryDocumentSnapshot { var documentID: String; var fields: [String: Any]; func data() -> [String: Any] { fields } }
enum AppViewModel { static let challengeDuration: TimeInterval = 259200 }
enum BackendError: Error { case noInternetForLeaderboard }
'''
helper='''    private func timestampDate(_ value: Any?) -> Date? { value as? Date }
'''
tests='''
func doc(_ id: String, _ user: String, _ age: Double, status: String = "active") -> QueryDocumentSnapshot {
QueryDocumentSnapshot(documentID: id, fields: ["userId":user, "startTime":Date().addingTimeInterval(-age), "status":status, "elapsedSeconds":0])
}
let backend = Backend()
let query = Query()
var updates = [[LeaderboardEntry]]()
let token = backend.listenToLeaderboardQuery(query, queryName:"test", currentUserId:"u", onChange:{ entries, _ in updates.append(entries) }, onError:{ _ in })!
query.callback?(Snapshot(documents:[doc("one","u",10),doc("stopped","s",50,status:"stopped"),doc("old","v",259201)]),nil)
assert(updates.last!.count == 2)
assert(updates.last![0].isCurrentUser)
assert(updates.last![1].status == .completed)
let initial = updates.last![0].fastingSeconds
RunLoop.current.run(until:Date().addingTimeInterval(1.2))
assert(updates.last![0].fastingSeconds > initial, "Live times must advance without a new Firestore snapshot")
token.remove()
let count = updates.count
RunLoop.current.run(until:Date().addingTimeInterval(1.2))
assert(updates.count == count, "Removed listener must stop its timer")
assert(query.registration.removed)
let weekly = Query()
var rows = [LeaderboardEntry]()
let weekToken = backend.listenToLeaderboardQuery(weekly, queryName:"weekly", currentUserId:"u", startDate:Date.startOfCurrentWeek(), onChange:{ entries, _ in rows=entries }, onError:{ _ in })!
weekly.callback?(Snapshot(documents:[doc("now","u",1),doc("past","v",86400*14)]),nil)
assert(rows.count == 1 && rows[0].userId == "u", "Weekly results must exclude prior weeks")
weekToken.remove()
let cache = Query()
var cacheUpdates = 0
var connectionErrors = 0
let cacheToken = backend.listenToLeaderboardQuery(cache, queryName:"cache", currentUserId:"u", onChange:{ _, _ in cacheUpdates += 1 }, onError:{ _ in connectionErrors += 1 })!
cache.callback?(Snapshot(documents:[],metadata:Metadata(isFromCache:true)),nil)
assert(cacheUpdates == 0, "Cache must not claim server connectivity")
cache.callback?(Snapshot(documents:[]),nil)
assert(cacheUpdates == 1)
cache.callback?(Snapshot(documents:[],metadata:Metadata(isFromCache:true)),nil)
assert(connectionErrors == 1, "A lost server connection must clear connected status")
cacheToken.remove()
print("PASS: live elapsed time, 72h completion, stopped exclusion, listener cleanup, weekly filtering, cache/server status")
'''
tests += r"""
func session(_ id: String, _ status: SessionStatus, _ duration: TimeInterval, rank: Int? = nil) -> FastingSession {
    FastingSession(id: id, userId: "u", contestId: nil, startTime: Date(timeIntervalSince1970: Double(id)!), endTime: nil,
                   elapsedSeconds: duration, status: status, createdAt: .now, updatedAt: .now, contestType: .global, rank: rank)
}
let history = [session("1", .completed, 100, rank: 5), session("2", .completed, 100), session("3", .stopped, 50), session("4", .completed, 100)]
let stats = UserStats.calculate(history: history, activeSession: session("5", .active, 200), currentRank: 0, badgesUnlocked: 3)
assert(stats.bestFastingSeconds == 200, "An active session can be the best time even when history exists")
assert(stats.totalFastingSeconds == 550)
assert(stats.bestRank == 5, "An absent current rank must not erase the best historic rank")
assert(stats.longestStreak == 2 && stats.currentStreak == 1, "Stopped attempts break streaks")
let emptyStats = UserStats.calculate(history: [], activeSession: nil, currentRank: 0, badgesUnlocked: 0)
assert(emptyStats == .empty)
let profile = UserProfile(id: "u", displayName: "Preview", avatarColorHex: "#0A84FF", countryFlag: "🏁", createdAt: .now, premiumUnlocked: true)
let contest = Contest(id: "contest", contestCode: "FAST-1234", creatorUserId: "u", title: "Test", createdAt: .now, participantIds: ["u", "other"], sessionIds: [], isPrivate: true)
let unrelated = LeaderboardEntry(id: "unrelated", userId: "u", rank: 1, displayName: "Preview", avatarColorHex: "#0A84FF", countryFlag: "🏁", fastingSeconds: 100, status: .active, isCurrentUser: true)
let contestRows = ContestParticipantRow.rows(for: contest, entries: [unrelated], profile: profile, activeSession: session("6", .active, 100))
assert(contestRows.count == 2)
assert(contestRows.first!.status == nil, "A global fast must not count as a private contest fast")
var contestSession = session("7", .active, 150)
contestSession.contestId = "contest"
assert(ContestParticipantRow.rows(for: contest, entries: [], profile: profile, activeSession: contestSession).first!.fastingSeconds == 150)
let tied = Query()
var tiedIds = [String]()
let tiedStart = Date().addingTimeInterval(-100)
let tiedDocs = ["b", "a"].map { QueryDocumentSnapshot(documentID: $0, fields: ["userId": $0, "startTime": tiedStart, "status": "active"]) }
let tiedToken = backend.listenToLeaderboardQuery(tied, queryName: "ties", currentUserId: "a", onChange: { entries, _ in tiedIds = entries.map(\.id) }, onError: { _ in })!
tied.callback?(Snapshot(documents: tiedDocs), nil)
assert(tiedIds == ["a", "b"], "Equal results need stable tie-breaking")
tiedToken.remove()
print("PASS: stats, empty history, streaks, historic ranks, private contest isolation, stable ties")
"""
with tempfile.TemporaryDirectory(prefix="fasting-ios-tests-") as directory:
    directory = Path(directory)
    source = directory / "main.swift"
    executable = directory / "regressions"
    source.write_text(stubs + token + entry + 'class Backend {\n' + listen + rank + helper + '}\n' + date + tests)
    subprocess.run(["xcrun", "swiftc", "-module-cache-path", str(directory / "modules"), str(root / "72H Fasting Contest/Models/AppModels.swift"), str(source), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
