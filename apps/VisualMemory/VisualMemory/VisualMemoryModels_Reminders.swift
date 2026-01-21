//
//  VisualMemoryModels.swift
//  VisualMemory - 3 Priorities + Reminders
//

import SwiftUI
import CloudKit

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Weekday Enum
enum Weekday: String, CaseIterable, Codable, Identifiable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: String { rawValue }
    
    var shortName: String {
        String(rawValue.prefix(3)).capitalized
    }
    
    var fullName: String {
        rawValue.capitalized
    }
    
    var dayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    static var today: Weekday {
        let dayNumber = Calendar.current.component(.weekday, from: Date())
        return Weekday.allCases[dayNumber - 1]
    }
}

// MARK: - Priority Level (3 Levels: Green, Yellow, Red)
enum PriorityLevel: Int, CaseIterable, Codable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3
    
    var id: Int { rawValue }
    
    var name: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle.fill"
        case .medium: return "circle.fill"
        case .high: return "circle.fill"
        }
    }
}

// MARK: - Time Filter
enum TimeFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case later = "Later"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.circle"
        case .thisYear: return "calendar.badge.clock"
        case .later: return "clock.badge.questionmark"
        }
    }
    
    var color: Color {
        switch self {
        case .today: return .orange
        case .tomorrow: return .yellow
        case .thisWeek: return .blue
        case .thisMonth: return .purple
        case .thisYear: return .indigo
        case .later: return .gray
        }
    }
}

// MARK: - Visual Task (Core Model)
struct VisualTask: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var deadlineTime: Date
    var isCompleted: Bool
    var completedAt: Date?
    
    // Recurring
    var isRecurring: Bool
    var recurringDays: Set<Weekday>
    
    // User Assignment
    var userId: UUID
    var userName: String
    var userAvatar: String
    var userColor: String
    
    // Priority
    var basePriority: PriorityLevel
    var userAdjustedPriority: Int?
    
    // Duration
    var estimatedMinutes: Int?
    
    // Voice Alerts (Siri)
    var voiceAlertsEnabled: Bool
    var voiceAlertMinutesBefore: Int
    
    // Reminder
    var reminderEnabled: Bool
    var reminderMinutesBefore: Int
    var reminderType: String // "Siri", "Sound", "Notification"
    var reminderSound: String // Alarm sound name
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        deadlineTime: Date,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isRecurring: Bool = false,
        recurringDays: Set<Weekday> = [],
        userId: UUID,
        userName: String,
        userAvatar: String,
        userColor: String,
        basePriority: PriorityLevel = .medium,
        userAdjustedPriority: Int? = nil,
        estimatedMinutes: Int? = nil,
        voiceAlertsEnabled: Bool = false,
        voiceAlertMinutesBefore: Int = 2,
        reminderEnabled: Bool = false,
        reminderMinutesBefore: Int = 5,
        reminderType: String = "Notification",
        reminderSound: String = "Radar"
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.deadlineTime = deadlineTime
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isRecurring = isRecurring
        self.recurringDays = recurringDays
        self.userId = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.userColor = userColor
        self.basePriority = basePriority
        self.userAdjustedPriority = userAdjustedPriority
        self.estimatedMinutes = estimatedMinutes
        self.voiceAlertsEnabled = voiceAlertsEnabled
        self.voiceAlertMinutesBefore = voiceAlertMinutesBefore
        self.reminderEnabled = reminderEnabled
        self.reminderMinutesBefore = reminderMinutesBefore
        self.reminderType = reminderType
        self.reminderSound = reminderSound
    }
    
    // MARK: - Computed Properties
    
    var timeRemaining: TimeInterval {
        deadlineTime.timeIntervalSince(Date())
    }
    
    var isOverdue: Bool {
        timeRemaining < 0 && !isCompleted
    }
    
    var timeRemainingFormatted: String {
        let remaining = timeRemaining
        
        if remaining < 0 {
            return "Overdue"
        } else if remaining < 60 {
            return "< 1 min"
        } else if remaining < 3600 {
            let mins = Int(remaining / 60)
            return "\(mins) min"
        } else if remaining < 86400 {
            let hours = Int(remaining / 3600)
            let mins = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours) hr"
        } else {
            let days = Int(remaining / 86400)
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
    
    var deadlineFormatted: String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(deadlineTime) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: deadlineTime))"
        } else if Calendar.current.isDateInTomorrow(deadlineTime) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: deadlineTime))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: deadlineTime)
        }
    }
    
    // Full schedule description for task bar (e.g., "Wake up Kristen - Weekdays at 7:00 AM")
    var fullScheduleDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: deadlineTime)
        
        if isRecurring && !recurringDays.isEmpty {
            let scheduleText = recurringDaysDescription
            return "\(title) - \(scheduleText) at \(timeString)"
        } else {
            // One-time task
            if Calendar.current.isDateInToday(deadlineTime) {
                return "\(title) - Today at \(timeString)"
            } else if Calendar.current.isDateInTomorrow(deadlineTime) {
                return "\(title) - Tomorrow at \(timeString)"
            } else {
                formatter.dateFormat = "MMM d"
                let dateString = formatter.string(from: deadlineTime)
                formatter.dateFormat = "h:mm a"
                return "\(title) - \(dateString) at \(timeString)"
            }
        }
    }
    
    // Description of recurring days (e.g., "Weekdays", "Every day", "Mon, Wed, Fri")
    var recurringDaysDescription: String {
        guard isRecurring && !recurringDays.isEmpty else { return "" }
        
        let allDays: Set<Weekday> = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<Weekday> = [.saturday, .sunday]
        
        if recurringDays == allDays {
            return "Every day"
        } else if recurringDays == weekdays {
            return "Weekdays"
        } else if recurringDays == weekends {
            return "Weekends"
        } else if recurringDays.count == 1, let day = recurringDays.first {
            return "Every \(day.fullName)"
        } else {
            // Sort by day order and show short names
            let orderedDays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let sortedDays = orderedDays.filter { recurringDays.contains($0) }
            return sortedDays.map { $0.shortName }.joined(separator: ", ")
        }
    }
    
    var effectivePriority: Int {
        let base = basePriority.rawValue
        let adjustment = userAdjustedPriority ?? 0
        return max(1, min(3, base + adjustment))
    }
    
    var effectivePriorityLevel: PriorityLevel {
        PriorityLevel(rawValue: effectivePriority) ?? .medium
    }
    
    var urgencyScore: Double {
        let remaining = max(0, timeRemaining)
        let hoursRemaining = remaining / 3600
        
        let priorityMultiplier = 1.0 + (Double(effectivePriority) - 1) * 0.5
        
        let timeUrgency: Double
        if hoursRemaining <= 0 {
            timeUrgency = 1000
        } else if hoursRemaining < 1 {
            timeUrgency = 100 / hoursRemaining
        } else if hoursRemaining < 24 {
            timeUrgency = 50 / hoursRemaining
        } else {
            timeUrgency = 10 / hoursRemaining
        }
        
        return timeUrgency * priorityMultiplier
    }
    
    func healthBarProgress(dayStartTime: Date) -> Double {
        let now = Date()
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: dayStartTime)
        startComponents.hour = startTimeComponents.hour
        startComponents.minute = startTimeComponents.minute
        
        guard let todayStart = calendar.date(from: startComponents) else { return 0 }
        
        if deadlineTime <= now { return 0 }
        
        let totalDuration = deadlineTime.timeIntervalSince(todayStart)
        let elapsed = now.timeIntervalSince(todayStart)
        
        if elapsed < 0 { return 1.0 }
        
        let remaining = max(0, totalDuration - elapsed)
        return min(1.0, max(0, remaining / totalDuration))
    }
    
    var urgencyColor: Color {
        let remaining = timeRemaining
        
        if remaining < 0 { return .red }
        else if remaining < 900 { return .red }
        else if remaining < 1800 { return .orange }
        else if remaining < 3600 { return .yellow }
        else { return .green }
    }
    
    var timeFilter: TimeFilter {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(deadlineTime) { return .today }
        else if calendar.isDateInTomorrow(deadlineTime) { return .tomorrow }
        else if let weekEnd = calendar.date(byAdding: .day, value: 7, to: now), deadlineTime < weekEnd { return .thisWeek }
        else if let monthEnd = calendar.date(byAdding: .month, value: 1, to: now), deadlineTime < monthEnd { return .thisMonth }
        else if let yearEnd = calendar.date(byAdding: .year, value: 1, to: now), deadlineTime < yearEnd { return .thisYear }
        else { return .later }
    }
    
    // Reminder time
    var reminderTime: Date {
        deadlineTime.addingTimeInterval(-Double(reminderMinutesBefore * 60))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VisualTask, rhs: VisualTask) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - User Profile
struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var avatarEmoji: String
    var color: String
    var isCurrentUser: Bool
    var dayStartTime: Date
    var alertThresholdMinutes: Int
    var audioAlertsEnabled: Bool
    var createdAt: Date
    var profileImageData: Data? // For photo avatar
    
    init(
        id: UUID = UUID(),
        name: String,
        avatarEmoji: String = "👤",
        color: String = "#007AFF",
        isCurrentUser: Bool = false,
        dayStartTime: Date? = nil,
        alertThresholdMinutes: Int = 15,
        audioAlertsEnabled: Bool = true,
        profileImageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.color = color
        self.isCurrentUser = isCurrentUser
        self.alertThresholdMinutes = alertThresholdMinutes
        self.audioAlertsEnabled = audioAlertsEnabled
        self.createdAt = Date()
        self.profileImageData = profileImageData
        
        if let startTime = dayStartTime {
            self.dayStartTime = startTime
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 6
            components.minute = 0
            self.dayStartTime = Calendar.current.date(from: components) ?? Date()
        }
    }
    
    var colorValue: Color {
        Color(hex: color)
    }
    
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "UserProfile", recordID: CKRecord.ID(recordName: id.uuidString))
        record["name"] = name
        record["avatarEmoji"] = avatarEmoji
        record["color"] = color
        record["alertThresholdMinutes"] = alertThresholdMinutes
        record["audioAlertsEnabled"] = audioAlertsEnabled ? 1 : 0
        return record
    }
    
    init?(from record: CKRecord) {
        guard let name = record["name"] as? String,
              let avatarEmoji = record["avatarEmoji"] as? String,
              let color = record["color"] as? String else { return nil }
        
        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.color = color
        self.isCurrentUser = false
        self.alertThresholdMinutes = record["alertThresholdMinutes"] as? Int ?? 15
        self.audioAlertsEnabled = (record["audioAlertsEnabled"] as? Int ?? 1) == 1
        self.createdAt = record.creationDate ?? Date()
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        self.dayStartTime = Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var defaultDayStartHour: Int
    var defaultDayStartMinute: Int
    var defaultAlertThresholdMinutes: Int
    var hueEnabled: Bool
    var hueBridgeIP: String?
    var showCompletedTasks: Bool
    var soundEnabled: Bool
    var hapticEnabled: Bool
    
    init() {
        self.defaultDayStartHour = 6
        self.defaultDayStartMinute = 0
        self.defaultAlertThresholdMinutes = 15
        self.hueEnabled = false
        self.hueBridgeIP = nil
        self.showCompletedTasks = false
        self.soundEnabled = true
        self.hapticEnabled = true
    }
    
    var dayStartTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = defaultDayStartHour
        components.minute = defaultDayStartMinute
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Gamification Models
struct UserStats: Codable {
    var tasksCompleted: Int
    var tasksCompletedOnTime: Int
    var currentStreak: Int
    var longestStreak: Int
    var totalPoints: Int
    var level: Int
    var achievements: Set<String>
    
    init() {
        self.tasksCompleted = 0
        self.tasksCompletedOnTime = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalPoints = 0
        self.level = 1
        self.achievements = []
    }
    
    var levelName: String {
        switch level {
        case 1: return "Beginner"
        case 2: return "Apprentice"
        case 3: return "Achiever"
        case 4: return "Pro"
        case 5: return "Expert"
        case 6...10: return "Master"
        default: return "Task Legend"
        }
    }
    
    var pointsToNextLevel: Int { level * 100 }
    
    var levelProgress: Double {
        Double(totalPoints % pointsToNextLevel) / Double(pointsToNextLevel)
    }
}

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    
    static let allAchievements: [Achievement] = [
        Achievement(id: "first_task", name: "Getting Started", description: "Complete your first task", icon: "star.fill", color: .yellow),
        Achievement(id: "early_bird", name: "Early Bird", description: "Complete a task before 9 AM", icon: "sunrise.fill", color: .orange),
        Achievement(id: "night_owl", name: "Night Owl", description: "Complete a task after 10 PM", icon: "moon.fill", color: .purple),
        Achievement(id: "streak_3", name: "On a Roll", description: "3 day completion streak", icon: "flame.fill", color: .red),
        Achievement(id: "streak_7", name: "Week Warrior", description: "7 day completion streak", icon: "flame.fill", color: .orange),
        Achievement(id: "streak_30", name: "Monthly Master", description: "30 day completion streak", icon: "crown.fill", color: .yellow),
        Achievement(id: "perfect_day", name: "Perfect Day", description: "Complete all tasks in a day", icon: "checkmark.seal.fill", color: .green),
        Achievement(id: "speed_demon", name: "Speed Demon", description: "Complete 5 tasks in one hour", icon: "bolt.fill", color: .blue),
        Achievement(id: "centurion", name: "Centurion", description: "Complete 100 tasks", icon: "100.circle.fill", color: .indigo),
    ]
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    func toHex() -> String {
        #if os(iOS) || os(tvOS)
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        #elseif os(macOS)
        let nsColor = NSColor(self)
        let components = [nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent]
        #endif
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
