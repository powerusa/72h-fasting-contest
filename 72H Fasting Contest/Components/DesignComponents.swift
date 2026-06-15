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
                Text(entry.fastingSeconds.compactHoursString)
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

struct PremiumGateLabel: View {
    var body: some View {
        Label("Premium", systemImage: "sparkles")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.yellow.opacity(0.18), in: Capsule())
            .foregroundStyle(.orange)
    }
}
