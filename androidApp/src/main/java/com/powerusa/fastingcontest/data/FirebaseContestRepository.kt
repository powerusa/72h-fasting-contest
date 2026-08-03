package com.powerusa.fastingcontest.data

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await
import kotlin.random.Random

class FirebaseContestRepository(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private var leaderboardListener: ListenerRegistration? = null
    private var userSessionsListener: ListenerRegistration? = null
    private var contestsListener: ListenerRegistration? = null

    suspend fun signIn(): String {
        auth.currentUser?.uid?.let { return it }
        return auth.signInAnonymously().await().user?.uid
            ?: error("Firebase anonymous sign-in did not return a user.")
    }

    suspend fun loadProfile(uid: String): UserProfile? {
        val doc = db.collection("users").document(uid).get().await()
        if (!doc.exists()) return null
        return UserProfile(
            id = uid,
            displayName = doc.getString("displayName") ?: "",
            avatarColor = doc.getString("avatarColor") ?: "#FF7A00",
            countryFlag = doc.getString("countryFlag") ?: "🏁"
        )
    }

    suspend fun saveProfile(profile: UserProfile) {
        val ref = db.collection("users").document(profile.id)
        val exists = ref.get().await().exists()
        val fields = mutableMapOf<String, Any>(
            "id" to profile.id,
            "displayName" to profile.displayName.take(40),
            "avatarColor" to profile.avatarColor,
            "countryFlag" to profile.countryFlag,
            "premiumUnlocked" to true,
            "updatedAt" to FieldValue.serverTimestamp()
        )
        if (!exists) fields["createdAt"] = FieldValue.serverTimestamp()
        ref.set(fields, com.google.firebase.firestore.SetOptions.merge()).await()
    }

    suspend fun startFast(profile: UserProfile, contest: Contest? = null): FastingSession {
        val existing = db.collection("fastingSessions")
            .whereEqualTo("userId", profile.id).whereEqualTo("status", "active").get().await()
        if (existing.documents.any { doc ->
                val session = doc.data?.toSession(doc.id)
                session != null && session.liveElapsed() < CHALLENGE_SECONDS
            }) error("You already have an active 72H fast.")

        val ref = db.collection("fastingSessions").document()
        val fields = mutableMapOf<String, Any>(
            "id" to ref.id,
            "userId" to profile.id,
            "displayName" to profile.displayName,
            "avatarColor" to profile.avatarColor,
            "countryFlag" to profile.countryFlag,
            "startTime" to FieldValue.serverTimestamp(),
            "status" to "active",
            "elapsedSeconds" to 0,
            "createdAt" to FieldValue.serverTimestamp(),
            "updatedAt" to FieldValue.serverTimestamp()
        )
        contest?.let {
            fields["contestId"] = it.id
            fields["contestCode"] = it.contestCode
        }
        ref.set(fields).await()
        val snapshot = ref.get(com.google.firebase.firestore.Source.SERVER).await()
        return snapshot.data?.toSession(snapshot.id) ?: error("Server start time was unavailable.")
    }

    suspend fun stopFast(session: FastingSession) {
        val seconds = session.liveElapsed().coerceAtMost(CHALLENGE_SECONDS - 1)
        db.collection("fastingSessions").document(session.id).update(
            mapOf(
                "status" to "stopped",
                "elapsedSeconds" to seconds,
                "endTime" to Timestamp.now(),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    suspend fun completeFast(session: FastingSession) {
        db.collection("fastingSessions").document(session.id).update(
            mapOf(
                "status" to "completed",
                "elapsedSeconds" to CHALLENGE_SECONDS,
                "endTime" to Timestamp(session.startTime.seconds + CHALLENGE_SECONDS, session.startTime.nanoseconds),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    suspend fun createContest(title: String, uid: String) {
        val ref = db.collection("contests").document()
        var code: String
        do {
            code = "FAST-" + (1..6).joinToString("") { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Random.nextInt(32)].toString() }
        } while (!db.collection("contests").whereEqualTo("contestCode", code).limit(1).get().await().isEmpty)
        ref.set(
            mapOf(
                "id" to ref.id,
                "title" to title.trim().ifEmpty { "Private 72H Contest" }.take(80),
                "contestCode" to code,
                "creatorUserId" to uid,
                "isPrivate" to true,
                "participantIds" to listOf(uid),
                "createdAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    suspend fun joinContest(code: String, uid: String) {
        val result = db.collection("contests")
            .whereEqualTo("contestCode", code.trim().uppercase()).limit(1).get().await()
        val ref = result.documents.firstOrNull()?.reference ?: error("Contest code not found.")
        ref.update(
            "participantIds", FieldValue.arrayUnion(uid),
            "updatedAt", FieldValue.serverTimestamp()
        ).await()
    }

    fun listen(uid: String, onSessions: (List<FastingSession>) -> Unit, onLeaderboard: (List<FastingSession>) -> Unit,
               onContests: (List<Contest>) -> Unit, onError: (Throwable) -> Unit) {
        userSessionsListener?.remove()
        leaderboardListener?.remove()
        contestsListener?.remove()

        userSessionsListener = db.collection("fastingSessions").whereEqualTo("userId", uid)
            .addSnapshotListener { snap, error ->
                if (error != null) return@addSnapshotListener onError(error)
                onSessions(snap?.documents?.mapNotNull { it.data?.toSession(it.id) }
                    ?.sortedByDescending { it.createdAt } ?: emptyList())
            }

        // Match iOS: observe the complete collection. An unordered limit can omit a
        // newly-created Android session when the collection contains older records.
        leaderboardListener = db.collection("fastingSessions")
            .addSnapshotListener { snap, error ->
                if (error != null) return@addSnapshotListener onError(error)
                onLeaderboard(snap?.documents?.mapNotNull { it.data?.toSession(it.id) }
                    ?.filter {
                        val effectiveStatus = it.leaderboardStatus()
                        effectiveStatus == SessionStatus.ACTIVE || effectiveStatus == SessionStatus.COMPLETED
                    }
                    ?: emptyList())
            }

        contestsListener = db.collection("contests").whereArrayContains("participantIds", uid)
            .addSnapshotListener { snap, error ->
                if (error != null) return@addSnapshotListener onError(error)
                onContests(snap?.documents?.mapNotNull { it.data?.toContest(it.id) }
                    ?.sortedByDescending { it.createdAt } ?: emptyList())
            }
    }

    fun close() {
        userSessionsListener?.remove(); leaderboardListener?.remove(); contestsListener?.remove()
    }
}
