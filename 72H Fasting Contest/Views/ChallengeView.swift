import SwiftUI

struct ChallengeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var showingSafety = false
    @State private var showingLeaderboard = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    screenTitle
                    heroTimer
                    actionButtons
                    milestoneGrid
                    rulesCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openSettings.callAsFunction) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onReceive(timer) { _ in
                viewModel.tick()
            }
            .sheet(isPresented: $showingSafety) {
                SafetyAgreementView()
            }
            .navigationDestination(isPresented: $showingLeaderboard) {
                LeaderboardView()
            }
            .alert("72Hour Fasting Leaderbord", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var screenTitle: some View {
        VStack(spacing: 2) {
            Text("72Hour Fasting")
            Text("Leaderbord")
        }
        .font(.system(size: 34, weight: .bold, design: .default))
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
    }

    private var heroTimer: some View {
        VStack(spacing: 18) {
            ZStack {
                ProgressRingView(progress: viewModel.progress)
                    .frame(width: 260, height: 260)
                VStack(spacing: 10) {
                    StatusBadge(status: viewModel.status)
                    CountdownTimerView(remainingSeconds: viewModel.remainingSeconds)
                    Text("\(Int(viewModel.progress * 100))% complete")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            }
            .padding(.top, 12)

            HStack(spacing: 12) {
                metric("Elapsed", value: viewModel.elapsedSeconds.compactHoursString)
                metric("Remaining", value: viewModel.remainingSeconds.compactHoursString)
                metric("Start", value: viewModel.activeSession?.startTime.formatted(date: .omitted, time: .shortened) ?? "--")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if viewModel.status == .active {
                PrimaryButton(title: "End Fast", systemImage: "stop.fill", tint: .red) {
                    Task { await viewModel.stopFast() }
                }
            } else {
                PrimaryButton(title: "Start 72H Fast", systemImage: "play.fill") {
                    if viewModel.hasAcceptedSafety {
                        Task { await viewModel.startFast() }
                    } else {
                        showingSafety = true
                    }
                }
            }
            PrimaryButton(title: "View Leaderboard", systemImage: "list.number", tint: .indigo) {
                showingLeaderboard = true
            }
        }
    }

    private var milestoneGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.title3.bold())
            ForEach(Milestone.all) { milestone in
                MilestoneCard(
                    milestone: milestone,
                    isReached: viewModel.elapsedSeconds >= TimeInterval(milestone.hour * 3600)
                )
            }
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Fair Play Rules", systemImage: "checkmark.shield.fill")
                .font(.headline)
            Text("One active session at a time. Start time cannot be edited. Stopped sessions are locked. Leaderboard time is recalculated from the saved start time when the app opens.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
