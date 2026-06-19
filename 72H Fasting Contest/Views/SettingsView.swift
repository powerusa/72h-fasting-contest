import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var countryFlag = ""
    @State private var avatarColor = "#0A84FF"
    @State private var remindersEnabled = true
    @State private var interval = 6
    @State private var milestonesEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Profile") {
                    TextField("Display name", text: $displayName)
                    CountryFlagPicker(selectedFlag: $countryFlag)
                    ColorPickerRow(selectedHex: $avatarColor)
                    Button("Save Profile") {
                        Task {
                            await viewModel.saveProfile(
                                displayName: displayName,
                                avatarColorHex: avatarColor,
                                countryFlag: countryFlag,
                                acceptsLeaderboardDataSharing: viewModel.hasAcceptedLeaderboardDataSharing
                            )
                        }
                    }
                }

                Section("Leaderboard Privacy") {
                    Label(
                        viewModel.hasAcceptedLeaderboardDataSharing ? "Leaderboard sharing accepted" : "Leaderboard sharing not accepted",
                        systemImage: viewModel.hasAcceptedLeaderboardDataSharing ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(viewModel.hasAcceptedLeaderboardDataSharing ? .green : .orange)

                    Text(leaderboardDataSharingDisclosure)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !viewModel.hasAcceptedLeaderboardDataSharing {
                        Button("Accept Leaderboard Sharing") {
                            viewModel.acceptLeaderboardDataSharing()
                        }
                    }
                }

                Section("Notification Settings") {
                    Toggle("Enable reminders", isOn: $remindersEnabled)
                    Stepper("Every \(interval) hours", value: $interval, in: 2...12, step: 2)
                    Toggle("Milestone notifications", isOn: $milestonesEnabled)
                    Button("Save Notifications") {
                        viewModel.updateNotificationPreferences(
                            NotificationPreferences(
                                remindersEnabled: remindersEnabled,
                                reminderIntervalHours: interval,
                                milestoneNotificationsEnabled: milestonesEnabled
                            )
                        )
                    }
                }

                Section("App Store Purchase") {
                    HStack {
                        Text("All features unlocked")
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    Text("This is a one-time paid app on the App Store. There are no subscriptions, no in-app purchases, and no locked feature tiers inside the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Safety Disclaimer") {
                    Text(safetyDisclaimer)
                        .font(.footnote)
                }

                Section("App Rules") {
                    Text("Only one active session is allowed. Start times cannot be edited after a challenge begins. The leaderboard shows only real users who are currently fasting.")
                        .font(.footnote)
                }

                Section("Support") {
                    Link("Privacy Policy", destination: URL(string: "https://github.com/powerusa/72h-fasting-contest/blob/main/PRIVACY_POLICY.md")!)
                    Link("Terms Placeholder", destination: URL(string: "https://example.com/terms")!)
                    Link("Contact Support Placeholder", destination: URL(string: "mailto:support@example.com")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                displayName = viewModel.profile?.displayName ?? ""
                countryFlag = viewModel.profile?.countryFlag ?? ""
                avatarColor = viewModel.profile?.avatarColorHex ?? "#0A84FF"
                remindersEnabled = viewModel.notificationPreferences.remindersEnabled
                interval = viewModel.notificationPreferences.reminderIntervalHours
                milestonesEnabled = viewModel.notificationPreferences.milestoneNotificationsEnabled
            }
        }
    }
}

private struct ColorPickerRow: View {
    @Binding var selectedHex: String
    private let colors = ["#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#AF52DE", "#64D2FF"]

    var body: some View {
        HStack {
            Text("Avatar color")
            Spacer()
            ForEach(colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if selectedHex == hex {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedHex = hex }
            }
        }
    }
}
