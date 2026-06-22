import SwiftUI
import MessageUI

struct ContestsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title = ""
    @State private var code = ""
    @State private var inviteSheet: InviteSheet?
    @State private var pendingStartContest: Contest?
    @State private var showingSafety = false
    @State private var showingLeaderboardConsent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    createCard
                    joinCard
                    contestsList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Private Contests")
            .sheet(item: $inviteSheet) { sheet in
                switch sheet {
                case .message(let contest):
                    MessageInviteSheet(messageBody: inviteMessage(for: contest))
                case .share(let contest):
                    ActivityInviteSheet(items: [inviteMessage(for: contest)])
                }
            }
            .sheet(isPresented: $showingSafety) {
                SafetyAgreementView {
                    startPendingContestFast()
                }
            }
            .sheet(isPresented: $showingLeaderboardConsent) {
                LeaderboardConsentView {
                    if viewModel.hasAcceptedSafety {
                        startPendingContestFast()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingSafety = true
                        }
                    }
                }
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

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Create Private Contest", systemImage: "plus.circle.fill")
                .font(.headline)
            TextField("Contest title", text: $title)
                .textFieldStyle(.roundedBorder)
            PrimaryButton(title: "Create Contest", systemImage: "person.3.fill") {
                Task {
                    await viewModel.createPrivateContest(title: title)
                    title = ""
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Join With Code", systemImage: "number")
                .font(.headline)
            TextField("Invite code", text: $code)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)
            PrimaryButton(title: "Join Contest", systemImage: "arrow.right.circle.fill", tint: .green) {
                Task {
                    await viewModel.joinContest(code: code)
                    code = ""
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var contestsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Contests")
                .font(.title3.bold())
            if viewModel.contests.isEmpty {
                EmptyStateView(title: "No private contests", message: "Create one or join with an invite code.", systemImage: "person.3")
            } else {
                ForEach(viewModel.contests) { contest in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(contest.title)
                                .font(.headline)
                            Spacer()
                            Text(contest.contestCode)
                                .font(.headline.monospaced())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.15), in: Capsule())
                        }
                        Text("\(contest.participantIds.count) participants")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            ForEach(viewModel.contestParticipantRows(for: contest)) { participant in
                                ContestParticipantRowView(participant: participant)
                            }
                        }
                        .padding(.vertical, 4)

                        Text("Not Started means the person joined this contest but has not tapped Start Contest Fast yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        contestFastAction(for: contest)

                        PrimaryButton(title: "Invite Friends", systemImage: "square.and.arrow.up", tint: .indigo) {
                            inviteSheet = MFMessageComposeViewController.canSendText() ? .message(contest) : .share(contest)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func inviteMessage(for contest: Contest) -> String {
        """
        Join my 72Hour Fasting Leaderbord private contest.

        Invite code: \(contest.contestCode)

        Open the app, go to Contests, enter the code under Join With Code, then tap Start Contest Fast in the contest card.
        Download the app from the App Store: https://apps.apple.com/us/search?term=72Hour%20Fasting%20Leaderbord
        """
    }

    @ViewBuilder
    private func contestFastAction(for contest: Contest) -> some View {
        if viewModel.activeSession?.contestId == contest.id {
            Label("Contest fast is active", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if viewModel.status == .active {
            Label("Finish your current fast before starting this contest fast.", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            PrimaryButton(title: "Start Contest Fast", systemImage: "play.fill", tint: .orange) {
                pendingStartContest = contest
                if !viewModel.hasAcceptedLeaderboardDataSharing {
                    showingLeaderboardConsent = true
                } else if !viewModel.hasAcceptedSafety {
                    showingSafety = true
                } else {
                    startPendingContestFast()
                }
            }
        }
    }

    private func startPendingContestFast() {
        guard let contest = pendingStartContest else { return }
        Task {
            await viewModel.startFast(contestId: contest.id)
            pendingStartContest = nil
        }
    }
}

private enum InviteSheet: Identifiable {
    case message(Contest)
    case share(Contest)

    var id: String {
        switch self {
        case .message(let contest): return "message-\(contest.id)"
        case .share(let contest): return "share-\(contest.id)"
        }
    }
}

private struct MessageInviteSheet: UIViewControllerRepresentable {
    let messageBody: String

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = messageBody
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}

private struct ActivityInviteSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ContestParticipantRowView: View {
    let participant: ContestParticipantRow

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(hex: participant.avatarColorHex, initials: String(participant.displayName.prefix(1)))
                .scaleEffect(0.82)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(participant.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(participant.countryFlag)
                        .font(.subheadline)
                    if participant.isCurrentUser {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let status = participant.status {
                StatusBadge(status: status)
                    .scaleEffect(0.85)
                    .frame(width: 78, alignment: .trailing)
            } else {
                Label("Not Started", systemImage: "hourglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var detailText: String {
        guard participant.status == .completed, let completedAt = participant.completedAt else {
            return participant.fastingSeconds?.compactHoursString ?? (participant.isCurrentUser ? "Joined - start contest fast" : "Joined - not started")
        }
        return "Finished \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
