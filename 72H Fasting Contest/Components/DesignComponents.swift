import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .accentColor
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct ProgressRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .mint, .green, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
        }
    }
}

struct CountdownTimerView: View {
    let remainingSeconds: TimeInterval

    var body: some View {
        VStack(spacing: 6) {
            Text(remainingSeconds.hourMinuteSecondString)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
            Text("remaining")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusBadge: View {
    let status: SessionStatus

    var body: some View {
        Label(status.rawValue, systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(status.tint)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.headline.monospacedDigit())
                .frame(width: 44, alignment: .leading)
            AvatarView(hex: entry.avatarColorHex, initials: String(entry.displayName.prefix(1)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.headline)
                    Text(entry.countryFlag)
                }
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                StatusBadge(status: entry.status)
                if entry.status == .completed {
                    Label("Finished", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(14)
        .background(entry.isCurrentUser ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var detailText: String {
        guard entry.status == .completed, let completedAt = entry.completedAt else {
            return entry.fastingSeconds.compactHoursString
        }
        return "Finished \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

struct MilestoneCard: View {
    let milestone: Milestone
    let isReached: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.symbolName)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(isReached ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12), in: Circle())
                .foregroundStyle(isReached ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(milestone.hour)H")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Image(systemName: isReached ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isReached ? Color.green : Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct BadgeCard: View {
    let badgeType: BadgeType
    let unlockedBadge: UnlockedBadge?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: badgeType.symbolName)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background((unlockedBadge == nil ? Color.secondary : Color.yellow).opacity(0.18), in: Circle())
                .foregroundStyle(unlockedBadge == nil ? Color.secondary : Color.yellow)
            Text(badgeType.rawValue)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(unlockedBadge.map { $0.unlockedAt.formatted(date: .abbreviated, time: .omitted) } ?? "Locked")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 134)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, minHeight: 260)
    }
}

struct CountryFlagPicker: View {
    @Binding var selectedFlag: String

    private var options: [CountryFlagOption] {
        CountryFlagOption.all
    }

    var body: some View {
        Picker("Country", selection: $selectedFlag) {
            ForEach(options) { option in
                Text("\(option.flag) \(option.name)")
                    .tag(option.flag)
            }
        }
        .pickerStyle(.navigationLink)
    }
}

private struct CountryFlagOption: Identifiable {
    let code: String
    let name: String
    let flag: String

    var id: String { code }

    static let all: [CountryFlagOption] = {
        let currentLocale = Locale.current
        let regionCodes = Locale.Region.isoRegions.map(\.identifier)
        let countryOptions = regionCodes.compactMap { code -> CountryFlagOption? in
            guard code.count == 2,
                  code.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }),
                  let flag = flagEmoji(for: code) else {
                return nil
            }
            let name = currentLocale.localizedString(forRegionCode: code) ?? code
            return CountryFlagOption(code: code, name: name, flag: flag)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return [CountryFlagOption(code: "ZZ", name: "Global", flag: "🏁")] + countryOptions
    }()

    private static func flagEmoji(for code: String) -> String? {
        let scalars = code.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            let value = scalar.value
            guard value >= 65, value <= 90 else { return nil }
            return UnicodeScalar(127397 + Int(value))
        }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }
}

struct SafetyCheckboxRow: View {
    let title: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? .green : .secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LeaderboardConsentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasConsented = false
    var onAccepted: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Label("Leaderboard Data Sharing", systemImage: "list.number")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(leaderboardDataSharingDisclosure)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    SafetyCheckboxRow(
                        title: "I consent to uploading my leaderboard profile and fasting score to Firebase so they can appear to other app users.",
                        isChecked: $hasConsented
                    )

                    Link("Privacy Policy", destination: URL(string: "https://github.com/powerusa/72h-fasting-contest/blob/main/PRIVACY_POLICY.md")!)

                    PrimaryButton(title: "Accept and Continue", systemImage: "checkmark.shield.fill") {
                        viewModel.acceptLeaderboardDataSharing()
                        dismiss()
                        onAccepted()
                    }
                    .opacity(hasConsented ? 1 : 0.45)
                    .disabled(!hasConsented)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Consent")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AvatarView: View {
    let hex: String
    let initials: String

    var body: some View {
        Text(initials.uppercased())
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color(hex: hex).gradient, in: Circle())
    }
}
