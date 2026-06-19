import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var displayName = ""
    @State private var selectedColor = "#0A84FF"
    @State private var countryFlag = "🇺🇸"
    @State private var acceptsLeaderboardDataSharing = false

    private let colors = ["#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#AF52DE", "#64D2FF"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(hex: selectedColor, initials: displayName.isEmpty ? "72" : String(displayName.prefix(1)))
                            .scaleEffect(1.55)
                            .padding(24)
                        Spacer()
                    }
                    TextField("Display name", text: $displayName)
                    CountryFlagPicker(selectedFlag: $countryFlag)
                } header: {
                    Text("Profile")
                } footer: {
                    Text("No email login is required. Your anonymous ID is created on this device.")
                }

                Section("Avatar Color") {
                    HStack {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if selectedColor == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Leaderboard Privacy") {
                    Text(leaderboardDataSharingDisclosure)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SafetyCheckboxRow(
                        title: "I consent to uploading my leaderboard profile and fasting score so they can appear in the global leaderboard.",
                        isChecked: $acceptsLeaderboardDataSharing
                    )
                }

                Section {
                    PrimaryButton(title: "Create Profile", systemImage: "person.crop.circle.badge.checkmark") {
                        Task {
                            await viewModel.saveProfile(
                                displayName: displayName,
                                avatarColorHex: selectedColor,
                                countryFlag: countryFlag,
                                acceptsLeaderboardDataSharing: acceptsLeaderboardDataSharing
                            )
                        }
                    }
                    .opacity(acceptsLeaderboardDataSharing ? 1 : 0.45)
                    .disabled(!acceptsLeaderboardDataSharing)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Set Up Profile")
        }
    }
}
