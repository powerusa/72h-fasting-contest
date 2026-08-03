package com.powerusa.fastingcontest.data

import com.google.firebase.Timestamp

const val CHALLENGE_SECONDS = 72 * 60 * 60L

enum class SessionStatus(val wireValue: String) {
    ACTIVE("active"), COMPLETED("completed"), STOPPED("stopped"), NOT_STARTED("notStarted");

    companion object {
        fun from(value: String?) = entries.firstOrNull { it.wireValue == value } ?: NOT_STARTED
    }
}

data class UserProfile(
    val id: String = "",
    val displayName: String = "",
    val avatarColor: String = "#FF7A00",
    val countryFlag: String = "🏁"
)

data class FastingSession(
    val id: String = "",
    val userId: String = "",
    val displayName: String = "",
    val avatarColor: String = "#FF7A00",
    val countryFlag: String = "🏁",
    val startTime: Timestamp = Timestamp.now(),
    val endTime: Timestamp? = null,
    val elapsedSeconds: Long = 0,
    val status: SessionStatus = SessionStatus.NOT_STARTED,
    val contestId: String? = null,
    val contestCode: String? = null,
    val createdAt: Timestamp = Timestamp.now()
) {
    fun liveElapsed(nowMillis: Long = System.currentTimeMillis()): Long = when (status) {
        SessionStatus.ACTIVE -> ((nowMillis - startTime.toDate().time) / 1000).coerceIn(0, CHALLENGE_SECONDS)
        else -> elapsedSeconds.coerceIn(0, CHALLENGE_SECONDS)
    }

    fun leaderboardStatus(nowMillis: Long = System.currentTimeMillis()): SessionStatus = when {
        status == SessionStatus.STOPPED -> SessionStatus.STOPPED
        endTime != null || status == SessionStatus.COMPLETED -> SessionStatus.COMPLETED
        status == SessionStatus.ACTIVE && liveElapsed(nowMillis) >= CHALLENGE_SECONDS -> SessionStatus.COMPLETED
        else -> status
    }

    fun completedAtMillis(): Long = endTime?.toDate()?.time
        ?: (startTime.toDate().time + CHALLENGE_SECONDS * 1000)
}

data class Contest(
    val id: String = "",
    val title: String = "",
    val contestCode: String = "",
    val creatorUserId: String = "",
    val participantIds: List<String> = emptyList(),
    val createdAt: Timestamp = Timestamp.now(),
    val isPrivate: Boolean = true
)

data class LeaderboardEntry(
    val session: FastingSession,
    val rank: Int,
    val isCurrentUser: Boolean
)

data class AppState(
    val loading: Boolean = true,
    val onboardingComplete: Boolean = false,
    val safetyAccepted: Boolean = false,
    val sharingAccepted: Boolean = false,
    val uid: String = "",
    val profile: UserProfile? = null,
    val activeSession: FastingSession? = null,
    val history: List<FastingSession> = emptyList(),
    val leaderboard: List<LeaderboardEntry> = emptyList(),
    val contests: List<Contest> = emptyList(),
    val error: String? = null,
    val connected: Boolean = false
)

fun Map<String, Any?>.toSession(id: String): FastingSession? {
    val userId = this["userId"] as? String ?: return null
    val start = this["startTime"] as? Timestamp ?: return null
    return FastingSession(
        id = id,
        userId = userId,
        displayName = this["displayName"] as? String ?: "Faster",
        avatarColor = this["avatarColor"] as? String ?: "#FF7A00",
        countryFlag = this["countryFlag"] as? String ?: "🏁",
        startTime = start,
        endTime = this["endTime"] as? Timestamp,
        elapsedSeconds = (this["elapsedSeconds"] as? Number)?.toLong() ?: 0,
        status = SessionStatus.from(this["status"] as? String),
        contestId = this["contestId"] as? String,
        contestCode = this["contestCode"] as? String,
        createdAt = this["createdAt"] as? Timestamp ?: start
    )
}

fun Map<String, Any?>.toContest(id: String) = Contest(
    id = id,
    title = this["title"] as? String ?: "Private 72H Contest",
    contestCode = this["contestCode"] as? String ?: "",
    creatorUserId = this["creatorUserId"] as? String ?: "",
    participantIds = (this["participantIds"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
    createdAt = this["createdAt"] as? Timestamp ?: Timestamp.now(),
    isPrivate = this["isPrivate"] as? Boolean ?: true
)
