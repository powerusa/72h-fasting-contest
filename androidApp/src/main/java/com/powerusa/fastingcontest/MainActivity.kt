package com.powerusa.fastingcontest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.powerusa.fastingcontest.data.*
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.util.Date

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { FastingContestTheme { FastingContestApp() } }
    }
}

private val Orange = Color(0xFFFF7A00)
private val Indigo = Color(0xFF5856D6)
private val Background = Color(0xFFF5F5F7)

@Composable
private fun FastingContestTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(primary = Orange, secondary = Indigo, background = Background),
        content = content
    )
}

@Composable
private fun FastingContestApp(vm: FastingViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    when {
        state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        !state.onboardingComplete -> OnboardingScreen(vm::finishOnboarding)
        !state.safetyAccepted -> SafetyScreen(vm::acceptSafety)
        state.profile == null -> ProfileScreen(vm::saveProfile)
        else -> MainTabs(state, vm)
    }

    state.error?.let { message ->
        AlertDialog(
            onDismissRequest = vm::clearError,
            confirmButton = { TextButton(onClick = vm::clearError) { Text("OK") } },
            title = { Text("72H Fasting Contest") },
            text = { Text(message) }
        )
    }
}

@Composable
private fun OnboardingScreen(onContinue: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(Background).padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(Icons.Default.LocalFireDepartment, null, tint = Orange, modifier = Modifier.size(84.dp))
        Spacer(Modifier.height(24.dp))
        Text("72Hour Fasting\nLeaderboard", fontSize = 38.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        Text("Track your 72-hour challenge, celebrate milestones, and fast alongside the same community on Android and iPhone.", textAlign = TextAlign.Center, color = Color.DarkGray)
        Spacer(Modifier.height(32.dp))
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth().height(54.dp)) { Text("Continue") }
    }
}

@Composable
private fun SafetyScreen(onAccept: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item { Spacer(Modifier.height(28.dp)) }
        item { Text("Safety first", fontSize = 34.sp, fontWeight = FontWeight.Bold) }
        item { Icon(Icons.Default.HealthAndSafety, null, tint = Orange, modifier = Modifier.size(64.dp)) }
        item { Card { Text(SAFETY_TEXT, Modifier.padding(20.dp), lineHeight = 23.sp) } }
        item { Text("Do not use this app if you are under 18. Stop fasting if you feel dizzy, faint, confused, or otherwise unwell.", fontWeight = FontWeight.SemiBold) }
        item { Button(onClick = onAccept, Modifier.fillMaxWidth().height(54.dp)) { Text("I understand and agree") } }
    }
}

private const val SAFETY_TEXT = "This app is for tracking, motivation, and friendly competition only. It does not provide medical advice, diagnosis, or treatment. Fasting may not be appropriate for everyone. Consult a healthcare professional before fasting, especially if you have any medical condition, are pregnant, or take medication."

@Composable
private fun ProfileScreen(onSave: (String, String, String) -> Unit) {
    var name by remember { mutableStateOf("") }
    var flag by remember { mutableStateOf("🇺🇸") }
    Column(Modifier.fillMaxSize().background(Background).padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("Create your profile", fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Text("Your profile and fasting score are shared to Firebase so Android and iPhone participants appear together.")
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(name, { name = it.take(40) }, label = { Text("Display name") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(flag, { flag = it.take(8) }, label = { Text("Country flag") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(24.dp))
        Button(onClick = { onSave(name, "#FF7A00", flag) }, modifier = Modifier.fillMaxWidth().height(54.dp)) { Text("Join the shared leaderboard") }
    }
}

private enum class AppTab(val title: String) { Challenge("Challenge"), Leaderboard("Leaders"), Contests("Contests"), Stats("Stats"), History("History") }

@Composable
private fun MainTabs(state: AppState, vm: FastingViewModel) {
    var tab by rememberSaveable { mutableStateOf(AppTab.Challenge) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                AppTab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item, onClick = { tab = item },
                        icon = { Icon(tabIcon(item), item.title) }, label = { Text(item.title, fontSize = 10.sp) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                AppTab.Challenge -> ChallengeScreen(state, vm)
                AppTab.Leaderboard -> LeaderboardScreen(state)
                AppTab.Contests -> ContestsScreen(state, vm)
                AppTab.Stats -> StatsScreen(state)
                AppTab.History -> HistoryScreen(state)
            }
        }
    }
}

private fun tabIcon(tab: AppTab) = when (tab) {
    AppTab.Challenge -> Icons.Default.Timer
    AppTab.Leaderboard -> Icons.Default.Leaderboard
    AppTab.Contests -> Icons.Default.Groups
    AppTab.Stats -> Icons.Default.BarChart
    AppTab.History -> Icons.Default.History
}

@Composable
private fun ChallengeScreen(state: AppState, vm: FastingViewModel) {
    val now by produceState(System.currentTimeMillis()) {
        while (true) { value = System.currentTimeMillis(); delay(1000) }
    }
    val elapsed = state.activeSession?.liveElapsed(now) ?: 0
    val remaining = (CHALLENGE_SECONDS - elapsed).coerceAtLeast(0)
    LaunchedEffect(elapsed) {
        if (elapsed >= CHALLENGE_SECONDS) vm.completeFastIfDue()
    }
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { Spacer(Modifier.height(12.dp)) }
        item { Text("72Hour Fasting\nLeaderboard", Modifier.fillMaxWidth(), fontSize = 32.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, lineHeight = 35.sp) }
        item { TimerCard(elapsed, remaining, state.activeSession != null) }
        item {
            if (state.activeSession == null) Button(onClick = { vm.startFast() }, Modifier.fillMaxWidth().height(54.dp)) { Icon(Icons.Default.PlayArrow, null); Spacer(Modifier.width(8.dp)); Text("Start 72H Fast") }
            else Button(onClick = vm::stopFast, Modifier.fillMaxWidth().height(54.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD83B3B))) { Icon(Icons.Default.Stop, null); Spacer(Modifier.width(8.dp)); Text("End Fast") }
        }
        item { Text("Milestones", fontSize = 22.sp, fontWeight = FontWeight.Bold) }
        items(listOf(12, 24, 36, 48, 60, 72)) { hour -> MilestoneRow(hour, elapsed >= hour * 3600L) }
        item { InfoCard("Fair Play Rules", "One active session at a time. Start time cannot be edited. Stopped sessions are locked. Firebase server timestamps keep the Android and iPhone leaderboard fair.") }
        item { Spacer(Modifier.height(8.dp)) }
    }
}

@Composable
private fun TimerCard(elapsed: Long, remaining: Long, active: Boolean) {
    Card(shape = RoundedCornerShape(24.dp)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(240.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    drawArc(Color(0xFFE2E2E7), -90f, 360f, false, style = Stroke(18.dp.toPx(), cap = StrokeCap.Round))
                    drawArc(Orange, -90f, 360f * elapsed / CHALLENGE_SECONDS, false, style = Stroke(18.dp.toPx(), cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    AssistChip(onClick = {}, label = { Text(if (active) "Active" else "Not Started") })
                    Text(formatDuration(remaining), fontSize = 29.sp, fontWeight = FontWeight.Bold)
                    Text("${(elapsed * 100 / CHALLENGE_SECONDS)}% complete", color = Color.Gray)
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                Metric("Elapsed", shortDuration(elapsed)); Metric("Remaining", shortDuration(remaining)); Metric("Goal", "72H")
            }
        }
    }
}

@Composable private fun Metric(label: String, value: String) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Text(value, fontWeight = FontWeight.Bold); Text(label, fontSize = 12.sp, color = Color.Gray) } }

@Composable
private fun MilestoneRow(hour: Int, reached: Boolean) {
    Card { Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(if (reached) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked, null, tint = if (reached) Color(0xFF2F9E44) else Color.Gray)
        Spacer(Modifier.width(14.dp)); Column { Text("${hour}H", fontWeight = FontWeight.Bold); Text(milestoneTitle(hour), color = Color.Gray) }
    } }
}

@Composable
private fun LeaderboardScreen(state: AppState) {
    val now by produceState(System.currentTimeMillis()) {
        while (true) { value = System.currentTimeMillis(); delay(1000) }
    }
    val currentEntry = state.leaderboard.firstOrNull { it.isCurrentUser }
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { ScreenHeader("Leaderboard", if (state.connected) "Live Firebase list • Android + iPhone" else "Connecting to Firebase…") }
        if (state.activeSession != null && currentEntry == null) {
            item { InfoCard("Syncing your active session", "Your current Android fast was saved and is being added to the live leaderboard.") }
        }
        if (state.leaderboard.isEmpty()) item { InfoCard("No leaderboard entries", "The list will fill when someone starts a 72H fast.") }
        items(state.leaderboard, key = { it.session.id }) { entry ->
            Card(colors = CardDefaults.cardColors(containerColor = if (entry.isCurrentUser) Color(0xFFFFF0DE) else Color.White)) {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("#${entry.rank}", fontWeight = FontWeight.Bold, modifier = Modifier.width(46.dp))
                    Box(Modifier.size(40.dp).background(parseColor(entry.session.avatarColor), CircleShape), contentAlignment = Alignment.Center) { Text(entry.session.countryFlag) }
                    Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(entry.session.displayName + if (entry.isCurrentUser) " (You)" else "", fontWeight = FontWeight.SemiBold); Text(entry.session.leaderboardStatus(now).wireValue.replaceFirstChar { it.uppercase() }, color = Color.Gray) }
                    Text(shortDuration(entry.session.liveElapsed(now)), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun ContestsScreen(state: AppState, vm: FastingViewModel) {
    var title by remember { mutableStateOf("") }; var code by remember { mutableStateOf("") }
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ScreenHeader("Private contests", "Create or join with the same FAST code on either platform") }
        item { Card { Column(Modifier.padding(16.dp)) {
            Text("Create a contest", fontWeight = FontWeight.Bold); OutlinedTextField(title, { title = it }, label = { Text("Contest title") }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp)); Button(onClick = { vm.createContest(title); title = "" }, Modifier.fillMaxWidth()) { Text("Create") }
        } } }
        item { Card { Column(Modifier.padding(16.dp)) {
            Text("Join a contest", fontWeight = FontWeight.Bold); OutlinedTextField(code, { code = it.uppercase() }, label = { Text("FAST-XXXXXX") }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp)); Button(onClick = { vm.joinContest(code); code = "" }, Modifier.fillMaxWidth()) { Text("Join") }
        } } }
        items(state.contests, key = { it.id }) { contest ->
            Card { Column(Modifier.fillMaxWidth().padding(16.dp)) {
                Text(contest.title, fontSize = 18.sp, fontWeight = FontWeight.Bold); Text(contest.contestCode, color = Indigo, fontWeight = FontWeight.SemiBold)
                Text("${contest.participantIds.size} participant${if (contest.participantIds.size == 1) "" else "s"}", color = Color.Gray)
                Spacer(Modifier.height(8.dp)); OutlinedButton(onClick = { vm.startFast(contest) }, enabled = state.activeSession == null) { Text("Start fast in this contest") }
            } }
        }
    }
}

@Composable
private fun StatsScreen(state: AppState) {
    val completed = state.history.count { it.status == SessionStatus.COMPLETED }
    val all = state.history + listOfNotNull(state.activeSession)
    val best = all.maxOfOrNull { it.liveElapsed() } ?: 0
    val total = all.sumOf { it.liveElapsed() }
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ScreenHeader("Your stats", "Progress synced from your Firebase account") }
        item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { StatCard("Completed", "$completed", Modifier.weight(1f)); StatCard("Best", shortDuration(best), Modifier.weight(1f)) } }
        item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { StatCard("Total fasting", shortDuration(total), Modifier.weight(1f)); StatCard("Current rank", state.leaderboard.firstOrNull { it.isCurrentUser }?.rank?.let { "#$it" } ?: "—", Modifier.weight(1f)) } }
        item { InfoCard("Milestone badges", "12H Warrior • 24H Hero • 36H Halfway Hero • 48H Strong Mind • 60H Final Stretch • 72H Finisher") }
    }
}

@Composable
private fun HistoryScreen(state: AppState) {
    LazyColumn(Modifier.fillMaxSize().background(Background).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { ScreenHeader("History", "Your finished and stopped fasting sessions") }
        if (state.history.isEmpty()) item { InfoCard("No history yet", "Completed or stopped sessions will appear here.") }
        items(state.history, key = { it.id }) { session ->
            Card { Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(if (session.status == SessionStatus.COMPLETED) Icons.Default.EmojiEvents else Icons.Default.StopCircle, null, tint = if (session.status == SessionStatus.COMPLETED) Orange else Color.Gray)
                Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(session.status.wireValue.replaceFirstChar { it.uppercase() }, fontWeight = FontWeight.Bold); Text(DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(session.startTime.toDate()), color = Color.Gray, fontSize = 13.sp) }
                Text(shortDuration(session.elapsedSeconds), fontWeight = FontWeight.Bold)
            } }
        }
    }
}

@Composable private fun ScreenHeader(title: String, subtitle: String) { Column(Modifier.padding(top = 18.dp, bottom = 6.dp)) { Text(title, fontSize = 32.sp, fontWeight = FontWeight.Bold); Text(subtitle, color = Color.Gray) } }
@Composable private fun InfoCard(title: String, body: String) { Card { Column(Modifier.fillMaxWidth().padding(18.dp)) { Text(title, fontWeight = FontWeight.Bold); Spacer(Modifier.height(5.dp)); Text(body, color = Color.DarkGray) } } }
@Composable private fun StatCard(title: String, value: String, modifier: Modifier) { Card(modifier) { Column(Modifier.fillMaxWidth().padding(18.dp)) { Text(value, fontSize = 24.sp, fontWeight = FontWeight.Bold); Text(title, color = Color.Gray) } } }

private fun formatDuration(seconds: Long): String = "%02d:%02d:%02d".format(seconds / 3600, seconds % 3600 / 60, seconds % 60)
private fun shortDuration(seconds: Long): String = if (seconds >= 3600) "${seconds / 3600}h ${seconds % 3600 / 60}m" else "${seconds / 60}m"
private fun milestoneTitle(hour: Int) = mapOf(12 to "Started Strong", 24 to "One Day Complete", 36 to "Halfway There", 48 to "Deep Focus", 60 to "Final Stretch", 72 to "Finisher")[hour] ?: "Milestone"
private fun parseColor(hex: String) = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Orange)
