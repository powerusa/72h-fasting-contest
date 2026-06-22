import SwiftUI
import MessageUI

struct ContestsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title = ""
    @State private var code = ""
    @State private var inviteSheet: InviteSheet?

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

        Open the app, go to Contests, and enter the code under Join With Code.
        Download the app from the App Store: https://apps.apple.com/us/search?term=72Hour%20Fasting%20Leaderbord
        """
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
