import Foundation
import SwiftUI

let safetyDisclaimer = "This app is for tracking, motivation, and friendly competition only. It does not provide medical advice, diagnosis, or treatment. Fasting may not be appropriate for everyone. Consult a healthcare professional before fasting, especially if you have any medical condition, are pregnant, are under 18, or take medication. Stop fasting if you feel unwell."

enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted = "Not Started"
    case active = "Active"
    case completed = "Completed"
    case stopped = "Stopped"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .notStarted: return "hourglass"
        case .active: return "flame.fill"
        case .completed: return "checkmark.seal.fill"
        case .stopped: return "stop.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notStarted: return .secondary
        case .active: return .orange
        case .completed: return .green
        case .stopped: return .red
        }
    }
}

enum ContestType: String, Codable, CaseIterable, Identifiable {
    case global = "Global"
    case `private` = "Private"

    var id: String { rawValue }
}

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case firstStart = "First Start"
    case warrior12 = "12H Warrior"
    case hero24 = "24H Hero"
    case halfway36 = "36H Halfway Hero"
    case strong48 = "48H Strong Mind"
    case stretch60 = "60H Final Stretch"
    case finisher72 = "72H Finisher"
    case threeTimeFinisher = "3-Time Finisher"
    case top10 = "Top 10 Leaderboard"
    case privateWinner = "Private Contest Winner"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .firstStart: return "flag.checkered"
        case .warrior12: return "bolt.heart.fill"
        case .hero24: return "sun.max.fill"
        case .halfway36: return "circle.lefthalf.filled"
        case .strong48: return "brain.head.profile"
        case .stretch60: return "figure.run"
        case .finisher72: return "trophy.fill"
        case .threeTimeFinisher: return "medal.fill"
        case .top10: return "list.number"
        case .privateWinner: return "crown.fill"
        }
    }
}

struct UserProfile: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var avatarColorHex: String
    var countryFlag: String
    var createdAt: Date
    var premiumUnlocked: Bool
}

struct FastingSession: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var contestId: String?
    var startTime: Date
    var endTime: Date?
    var elapsedSeconds: TimeInterval
    var status: SessionStatus
    var createdAt: Date
    var updatedAt: Date
    var contestType: ContestType
    var rank: Int?

    var isLocked: Bool {
        status == .completed || status == .stopped
    }
}

struct Contest: Codable, Identifiable, Equatable {
    var id: String
    var contestCode: String
    var creatorUserId: String
    var title: String
    var createdAt: Date
    var participantIds: [String]
    var sessionIds: [String]
    var isPrivate: Bool
}

struct UnlockedBadge: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var badgeType: BadgeType
    var unlockedAt: Date
}

struct UserStats: Codable, Equatable {
    var completedChallenges: Int
    var bestFastingSeconds: TimeInterval
    var totalFastingSeconds: TimeInterval
    var currentRank: Int
    var bestRank: Int
    var currentStreak: Int
    var longestStreak: Int
    var badgesUnlocked: Int

    static let empty = UserStats(
        completedChallenges: 0,
        bestFastingSeconds: 0,
        totalFastingSeconds: 0,
        currentRank: 0,
        bestRank: 0,
        currentStreak: 0,
        longestStreak: 0,
        badgesUnlocked: 0
    )
}

struct Milestone: Identifiable, Equatable {
    var id: Int { hour }
    let hour: Int
    let title: String
    let symbolName: String

    static let all = [
        Milestone(hour: 12, title: "Started Strong", symbolName: "sparkles"),
        Milestone(hour: 24, title: "One Day Complete", symbolName: "sun.max.fill"),
        Milestone(hour: 36, title: "Halfway There", symbolName: "circle.lefthalf.filled"),
        Milestone(hour: 48, title: "Deep Focus", symbolName: "scope"),
        Milestone(hour: 60, title: "Final Stretch", symbolName: "figure.run"),
        Milestone(hour: 72, title: "Finisher", symbolName: "trophy.fill")
    ]
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let userId: String
    let rank: Int
    let displayName: String
    let avatarColorHex: String
    let countryFlag: String
    let fastingSeconds: TimeInterval
    let status: SessionStatus
    let isCurrentUser: Bool
}

struct NotificationPreferences: Codable, Equatable {
    var remindersEnabled: Bool
    var reminderIntervalHours: Int
    var milestoneNotificationsEnabled: Bool

    static let `default` = NotificationPreferences(
        remindersEnabled: true,
        reminderIntervalHours: 6,
        milestoneNotificationsEnabled: true
    )
}

struct AppSnapshot: Codable {
    var hasCompletedOnboarding: Bool = false
    var hasAcceptedSafety: Bool = false
    var profile: UserProfile?
    var activeSession: FastingSession?
    var history: [FastingSession] = []
    var contests: [Contest] = []
    var unlockedBadges: [UnlockedBadge] = []
    var notificationPreferences: NotificationPreferences = .default
}

extension TimeInterval {
    var hourMinuteSecondString: String {
        let seconds = max(0, Int(self.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    var compactHoursString: String {
        let hours = Int(self / 3600)
        let minutes = Int(self.truncatingRemainder(dividingBy: 3600) / 60)
        if hours == 0 {
            return "\(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
