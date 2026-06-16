import SwiftUI

struct ContestsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title = ""
    @State private var code = ""

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
                viewModel.joinContest(code: code)
                code = ""
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
                        PrimaryButton(title: "Invite Friends", systemImage: "square.and.arrow.up", tint: .indigo) {}
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}
