//
//  VisualMemoryDataManager.swift
//  VisualMemory - With Reminders
//

import SwiftUI
import Combine
import UserNotifications
import AVFoundation
import AudioToolbox

@MainActor
class VisualMemoryDataManager: ObservableObject {
    static let shared = VisualMemoryDataManager()
    
    @Published var tasks: [VisualTask] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var userStats: UserStats = UserStats()
    
    // Track which alerts have been spoken
    @Published var spokenAlerts: Set<String> = []
    
    private let tasksKey = "visualmemory_tasks"
    private let settingsKey = "visualmemory_settings"
    private let statsKey = "visualmemory_stats"
    
    init() {
        loadTasks()
        loadSettings()
        loadStats()
        setupNotificationCategories()
        requestNotificationPermission()
    }
    
    // MARK: - Permission & Setup
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification error: \(error)")
            }
        }
    }
    
    func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "✓ Done!",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Not Yet",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // MARK: - Task Management
    
    func addTask(_ task: VisualTask) {
        tasks.append(task)
        saveTasks()
        
        // Voice announcement if enabled
        if task.voiceAlertsEnabled {
            let announcement = "\(task.userName), task added: \(task.title), due \(task.deadlineFormatted)"
            SpeechManager.shared.speak(announcement)
        }
        
        // Schedule reminders
        scheduleReminders(for: task)
    }
    
    func scheduleReminders(for task: VisualTask) {
        let center = UNUserNotificationCenter.current()
        
        // Reminder before deadline
        if task.reminderEnabled {
            let reminderTime = task.reminderTime
            
            if reminderTime > Date() {
                let content = UNMutableNotificationContent()
                content.title = "⏰ \(task.reminderMinutesBefore) min Reminder"
                content.body = "\(task.userName), \(task.reminderMinutesBefore) minutes until: \(task.title)"
                content.categoryIdentifier = "TASK_REMINDER"
                content.userInfo = ["taskId": task.id.uuidString, "type": "reminder", "userName": task.userName, "taskTitle": task.title]
                
                // Set sound based on reminder type
                if task.reminderType == "Sound" {
                    // Use custom sound if available
                    content.sound = UNNotificationSound.default
                } else {
                    content.sound = .default
                }
                
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminderTime),
                    repeats: false
                )
                
                let request = UNNotificationRequest(identifier: "\(task.id)-reminder", content: content, trigger: trigger)
                center.add(request) { error in
                    if let error = error {
                        print("❌ Reminder scheduling error: \(error)")
                    } else {
                        print("✅ Reminder scheduled for \(task.title)")
                    }
                }
            }
        }
        
        // Time's up notification
        if task.deadlineTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "⏱️ Time's Up!"
            content.body = "\(task.userName), deadline reached for: \(task.title)"
            content.categoryIdentifier = "TASK_REMINDER"
            content.sound = .default
            content.userInfo = ["taskId": task.id.uuidString, "type": "deadline"]
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.deadlineTime),
                repeats: false
            )
            
            let request = UNNotificationRequest(identifier: "\(task.id)-deadline", content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    func updateTask(_ task: VisualTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: VisualTask) {
        cancelNotifications(for: task)
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func completeTask(_ task: VisualTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = true
            tasks[index].completedAt = Date()
            
            cancelNotifications(for: task)
            
            if task.voiceAlertsEnabled {
                SpeechManager.shared.speak("Great job \(task.userName)! \(task.title) marked complete.")
                SoundManager.shared.playComplete()
            }
            
            updateStatsOnCompletion(task: tasks[index])
            saveTasks()
        }
    }
    
    func cancelNotifications(for task: VisualTask) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(task.id)-start",
            "\(task.id)-reminder",
            "\(task.id)-warning",
            "\(task.id)-deadline",
            "\(task.id)-complete"
        ])
    }
    
    func uncompleteTask(_ task: VisualTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = false
            tasks[index].completedAt = nil
            saveTasks()
        }
    }
    
    func toggleTask(_ task: VisualTask) {
        if task.isCompleted {
            uncompleteTask(task)
        } else {
            completeTask(task)
        }
    }
    
    // MARK: - Voice Alert Checking
    
    func checkVoiceAlerts() {
        for task in tasks where task.voiceAlertsEnabled && !task.isCompleted {
            let remaining = task.timeRemaining
            let taskId = task.id.uuidString
            
            // Custom reminder time warning
            if task.reminderEnabled {
                let reminderSeconds = Double(task.reminderMinutesBefore * 60)
                if remaining > (reminderSeconds - 5) && remaining <= reminderSeconds {
                    let alertKey = "\(taskId)-reminder-\(task.reminderMinutesBefore)min"
                    if !spokenAlerts.contains(alertKey) {
                        if task.reminderType == "Siri" {
                            SpeechManager.shared.speak("\(task.userName), you have \(task.reminderMinutesBefore) minutes left to finish \(task.title)")
                        }
                        spokenAlerts.insert(alertKey)
                    }
                }
            }
            
            // Time's up
            if remaining > -5 && remaining <= 0 {
                let alertKey = "\(taskId)-done"
                if !spokenAlerts.contains(alertKey) {
                    SpeechManager.shared.speak("\(task.userName), time is up for \(task.title). Have you finished?")
                    SoundManager.shared.playAlert()
                    spokenAlerts.insert(alertKey)
                }
            }
        }
    }
    
    // MARK: - Priority Adjustment
    
    func increasePriority(for task: VisualTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let currentPriority = tasks[index].effectivePriority
            if currentPriority < 3 {
                let currentAdjustment = tasks[index].userAdjustedPriority ?? 0
                tasks[index].userAdjustedPriority = currentAdjustment + 1
                saveTasks()
            }
        }
    }
    
    func decreasePriority(for task: VisualTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let currentPriority = tasks[index].effectivePriority
            if currentPriority > 1 {
                let currentAdjustment = tasks[index].userAdjustedPriority ?? 0
                tasks[index].userAdjustedPriority = currentAdjustment - 1
                saveTasks()
            }
        }
    }
    
    func setPriority(for task: VisualTask, adjustment: Int) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].userAdjustedPriority = adjustment
            saveTasks()
        }
    }
    
    // MARK: - Sorted/Filtered Lists
    
    var urgentTasks: [VisualTask] {
        tasks.filter { !$0.isCompleted }.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    var todaysTasks: [VisualTask] {
        tasks.filter { !$0.isCompleted && $0.timeFilter == .today }.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    var overdueTasks: [VisualTask] {
        tasks.filter { !$0.isCompleted && $0.isOverdue }.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    func tasks(for filter: TimeFilter) -> [VisualTask] {
        tasks.filter { !$0.isCompleted && $0.timeFilter == filter }.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    func tasks(for userId: UUID) -> [VisualTask] {
        tasks.filter { !$0.isCompleted && $0.userId == userId }.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    var completedTasks: [VisualTask] {
        tasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }
    
    func taskCount(for filter: TimeFilter) -> Int {
        tasks.filter { !$0.isCompleted && $0.timeFilter == filter }.count
    }
    
    // MARK: - Stats
    
    var totalActiveTasks: Int { tasks.filter { !$0.isCompleted }.count }
    
    var totalCompletedToday: Int {
        let calendar = Calendar.current
        return tasks.filter { $0.isCompleted && calendar.isDateInToday($0.completedAt ?? Date.distantPast) }.count
    }
    
    private func updateStatsOnCompletion(task: VisualTask) {
        userStats.tasksCompleted += 1
        
        if !task.isOverdue {
            userStats.tasksCompletedOnTime += 1
            userStats.totalPoints += 10
        } else {
            userStats.totalPoints += 5
        }
        
        updateStreak()
        checkLevelUp()
        checkAchievements(task: task)
        saveStats()
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        let completedYesterday = tasks.contains {
            $0.isCompleted && calendar.isDate($0.completedAt ?? Date.distantPast, inSameDayAs: yesterday)
        }
        
        if completedYesterday {
            userStats.currentStreak += 1
            userStats.longestStreak = max(userStats.longestStreak, userStats.currentStreak)
        } else {
            let completedToday = tasks.filter {
                $0.isCompleted && calendar.isDateInToday($0.completedAt ?? Date.distantPast)
            }.count
            
            if completedToday == 1 { userStats.currentStreak = 1 }
        }
    }
    
    private func checkLevelUp() {
        let newLevel = (userStats.totalPoints / 100) + 1
        if newLevel > userStats.level { userStats.level = newLevel }
    }
    
    private func checkAchievements(task: VisualTask) {
        if userStats.tasksCompleted == 1 { userStats.achievements.insert("first_task") }
        
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { userStats.achievements.insert("early_bird") }
        if hour >= 22 { userStats.achievements.insert("night_owl") }
        
        if userStats.currentStreak >= 3 { userStats.achievements.insert("streak_3") }
        if userStats.currentStreak >= 7 { userStats.achievements.insert("streak_7") }
        if userStats.currentStreak >= 30 { userStats.achievements.insert("streak_30") }
        if userStats.tasksCompleted >= 100 { userStats.achievements.insert("centurion") }
    }
    
    // MARK: - Persistence
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([VisualTask].self, from: data) {
            tasks = decoded
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(userStats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            userStats = decoded
        }
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func clearAllTasks() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        tasks = []
        spokenAlerts = []
        saveTasks()
    }
    
    func resetStats() {
        userStats = UserStats()
        saveStats()
    }
}

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()
    
    func playAlert() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func playComplete() {
        AudioServicesPlaySystemSound(1004)
    }
    
    func playSound(named name: String) {
        // Map sound names to system sound IDs
        let soundMap: [String: SystemSoundID] = [
            "Radar": 1005,
            "Beacon": 1006,
            "Chimes": 1007,
            "Circuit": 1008,
            "Cosmic": 1009,
            "Crystals": 1010,
            "Hillside": 1011,
            "Illuminate": 1012,
            "Night Owl": 1013,
            "Playtime": 1014,
            "Presto": 1015,
            "Radiate": 1016,
            "Ripples": 1017,
            "Sencha": 1018,
            "Signal": 1019,
            "Silk": 1020,
            "Slow Rise": 1021,
            "Stargaze": 1022,
            "Summit": 1023,
            "Twinkle": 1024,
            "Uplift": 1025,
            "Waves": 1026
        ]
        
        if let soundID = soundMap[name] {
            AudioServicesPlaySystemSound(soundID)
        } else {
            AudioServicesPlaySystemSound(1005) // Default to Radar
        }
    }
}
