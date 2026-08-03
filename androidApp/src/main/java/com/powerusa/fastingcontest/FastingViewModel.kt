package com.powerusa.fastingcontest

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.powerusa.fastingcontest.data.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class FastingViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = FirebaseContestRepository()
    private val preferences = application.getSharedPreferences("fasting_contest", 0)
    private val _state = MutableStateFlow(AppState(
        onboardingComplete = preferences.getBoolean("onboardingComplete", false),
        safetyAccepted = preferences.getBoolean("safetyAccepted", false),
        sharingAccepted = preferences.getBoolean("sharingAccepted", false)
    ))
    val state: StateFlow<AppState> = _state.asStateFlow()

    init { bootstrap() }

    private fun bootstrap() = viewModelScope.launch {
        runCatching {
            val uid = repository.signIn()
            val profile = repository.loadProfile(uid)
            _state.update { it.copy(loading = false, uid = uid, profile = profile, connected = true) }
            repository.listen(
                uid = uid,
                onSessions = { sessions ->
                    _state.update { state ->
                        state.copy(
                            activeSession = sessions.firstOrNull { it.status == SessionStatus.ACTIVE },
                            history = sessions.filter { it.status != SessionStatus.ACTIVE }, connected = true
                        )
                    }
                },
                onLeaderboard = { sessions ->
                    val now = System.currentTimeMillis()
                    val currentEntryPerUser = sessions.groupBy { it.userId }.values.mapNotNull { userSessions ->
                        userSessions.sortedWith(
                            compareBy<FastingSession> { if (it.leaderboardStatus(now) == SessionStatus.ACTIVE) 0 else 1 }
                                .thenByDescending { if (it.leaderboardStatus(now) == SessionStatus.COMPLETED) it.completedAtMillis() else it.liveElapsed(now) }
                        ).firstOrNull()
                    }
                    val sorted = currentEntryPerUser.sortedWith(
                        compareBy<FastingSession> { if (it.leaderboardStatus(now) == SessionStatus.ACTIVE) 0 else 1 }
                            .thenComparator { left, right ->
                                if (left.leaderboardStatus(now) == SessionStatus.ACTIVE) {
                                    right.liveElapsed(now).compareTo(left.liveElapsed(now))
                                } else {
                                    right.completedAtMillis().compareTo(left.completedAtMillis())
                                }
                            }
                    )
                    _state.update { state ->
                        state.copy(leaderboard = sorted.mapIndexed { index, session ->
                            LeaderboardEntry(session, index + 1, session.userId == uid)
                        }, connected = true)
                    }
                },
                onContests = { contests -> _state.update { it.copy(contests = contests, connected = true) } },
                onError = { showError(it) }
            )
        }.onFailure { showError(it, loading = false) }
    }

    fun finishOnboarding() {
        preferences.edit().putBoolean("onboardingComplete", true).apply()
        _state.update { it.copy(onboardingComplete = true) }
    }

    fun acceptSafety() {
        preferences.edit().putBoolean("safetyAccepted", true).apply()
        _state.update { it.copy(safetyAccepted = true) }
    }

    fun saveProfile(name: String, color: String, flag: String) = viewModelScope.launch {
        if (name.trim().isEmpty()) return@launch showError(IllegalArgumentException("Add a display name to continue."))
        val profile = UserProfile(_state.value.uid, name.trim(), color, flag.ifBlank { "🏁" })
        runCatching { repository.saveProfile(profile) }
            .onSuccess {
                preferences.edit().putBoolean("sharingAccepted", true).apply()
                _state.update { it.copy(profile = profile, sharingAccepted = true, error = null) }
            }.onFailure(::showError)
    }

    fun startFast(contest: Contest? = null) = viewModelScope.launch {
        val profile = _state.value.profile ?: return@launch showError(IllegalStateException("Create your profile first."))
        if (!_state.value.safetyAccepted) return@launch showError(IllegalStateException("Accept the fasting safety agreement first."))
        runCatching { repository.startFast(profile, contest) }
            .onSuccess { session -> _state.update { it.copy(activeSession = session, error = null) } }
            .onFailure(::showError)
    }

    fun stopFast() = viewModelScope.launch {
        val session = _state.value.activeSession ?: return@launch
        runCatching { repository.stopFast(session) }.onFailure(::showError)
    }

    fun completeFastIfDue() = viewModelScope.launch {
        val session = _state.value.activeSession ?: return@launch
        if (session.liveElapsed() >= CHALLENGE_SECONDS) {
            runCatching { repository.completeFast(session) }.onFailure(::showError)
        }
    }

    fun createContest(title: String) = viewModelScope.launch {
        runCatching { repository.createContest(title, _state.value.uid) }.onFailure(::showError)
    }

    fun joinContest(code: String) = viewModelScope.launch {
        runCatching { repository.joinContest(code, _state.value.uid) }.onFailure(::showError)
    }

    fun clearError() = _state.update { it.copy(error = null) }

    private fun showError(error: Throwable, loading: Boolean = _state.value.loading) {
        _state.update { it.copy(error = error.localizedMessage ?: "Something went wrong.", loading = loading, connected = false) }
    }

    override fun onCleared() {
        repository.close()
        super.onCleared()
    }
}
