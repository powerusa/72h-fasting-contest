import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var displayName = ""
    @State private var selectedColor = "#0A84FF"
    @State private var countryFlag = "🇺🇸"

    private let colors = ["#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#AF52DE", "#64D2FF"]
    private let flags = ["🇺🇸", "🇨🇦", "🇬🇧", "🇩🇰", "🇯🇵", "🇦🇺", "🏁"]

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
                    Picker("Country", selection: $countryFlag) {
                        ForEach(flags, id: \.self) { flag in
                            Text(flag).tag(flag)
                        }
                    }
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

                Section {
                    PrimaryButton(title: "Create Profile", systemImage: "person.crop.circle.badge.checkmark") {
                        Task {
                            await viewModel.saveProfile(displayName: displayName, avatarColorHex: selectedColor, countryFlag: countryFlag)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Set Up Profile")
        }
    }
}
