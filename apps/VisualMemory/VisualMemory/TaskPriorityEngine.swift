import SwiftUI
import Combine

// MARK: - Task Model for Main App

struct AppTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var category: String
    var categoryIcon: String
    var categoryColor: String
    var frequency: String  // daily, weekly, monthly, yearly, once
    var basePriority: String  // high, medium, low
    var dueDate: Date?
    var dueTime: String?  // "HH:mm" format, nil if no specific time
    var duration: Int  // minutes
    var isCompleted: Bool
    var completedAt: Date?
    var lastRankPosition: Int?  // For tracking movement
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String = "Personal",
        categoryIcon: String = "circle.fill",
        categoryColor: String = "blue",
        frequency: String = "once",
        basePriority: String = "medium",
        dueDate: Date? = nil,
        dueTime: String? = nil,
        duration: Int = 30,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        lastRankPosition: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.categoryIcon = categoryIcon
        self.categoryColor = categoryColor
        self.frequency = frequency
        self.basePriority = basePriority
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.duration = duration
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.lastRankPosition = lastRankPosition
        self.createdAt = createdAt
    }
    
    // Computed: Full due datetime
    var fullDueDate: Date? {
        guard let date = dueDate else { return nil }
        guard let time = dueTime, !time.isEmpty else { return date }
        
        let parts = time.components(separatedBy: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return date }
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? date
    }
    
    // Computed: Time remaining
    var timeRemaining: TimeInterval? {
        guard let due = fullDueDate else { return nil }
        return due.timeIntervalSince(Date())
    }
    
    // Computed: Is overdue
    var isOverdue: Bool {
        guard let remaining = timeRemaining else { return false }
        return remaining < 0
    }
    
    // Computed: Urgency level for coloring
    var urgencyLevel: UrgencyLevel {
        guard let remaining = timeRemaining else { return .none }
        
        if remaining < 0 { return .overdue }
        if remaining < 15 * 60 { return .critical }  // < 15 min
        if remaining < 60 * 60 { return .urgent }    // < 1 hour
        if remaining < 4 * 60 * 60 { return .soon }  // < 4 hours
        return .later
    }
    
    // Computed: Human readable time
    var timeRemainingDisplay: String {
        guard let remaining = timeRemaining else { return "No due date" }
        
        if remaining < 0 {
            let overdue = abs(remaining)
            if overdue < 60 { return "OVERDUE" }
            if overdue < 3600 { return "\(Int(overdue / 60))m overdue" }
            if overdue < 86400 { return "\(Int(overdue / 3600))h overdue" }
            return "\(Int(overdue / 86400))d overdue"
        }
        
        if remaining < 60 { return "< 1 min" }
        if remaining < 3600 { return "\(Int(remaining / 60)) min" }
        if remaining < 86400 {
            let hours = Int(remaining / 3600)
            let mins = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            if mins == 0 { return "\(hours)h" }
            return "\(hours)h \(mins)m"
        }
        let days = Int(remaining / 86400)
        return "\(days) day\(days == 1 ? "" : "s")"
    }
    
    // Computed: Fun relative time (for time blindness)
    var relativeTimeDisplay: String? {
        guard let remaining = timeRemaining, remaining > 0 else { return nil }
        
        let minutes = remaining / 60
        
        if minutes < 5 { return "Less than a song" }
        if minutes < 15 { return "≈ 1 YouTube video" }
        if minutes < 30 { return "≈ A quick shower" }
        if minutes < 45 { return "≈ Half a TV episode" }
        if minutes < 60 { return "≈ 1 TV episode" }
        if minutes < 90 { return "≈ A workout session" }
        if minutes < 120 { return "≈ A movie" }
        if minutes < 180 { return "≈ A long movie" }
        if minutes < 240 { return "≈ A short flight" }
        return nil
    }
}

// MARK: - Urgency Level

enum UrgencyLevel: Int, CaseIterable {
    case overdue = 0
    case critical = 1  // < 15 min
    case urgent = 2    // < 1 hour
    case soon = 3      // < 4 hours
    case later = 4     // 4+ hours
    case none = 5      // no due date
    
    var color: Color {
        switch self {
        case .overdue: return .red
        case .critical: return .red
        case .urgent: return .orange
        case .soon: return .yellow
        case .later: return .green
        case .none: return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .overdue: return Color.red.opacity(0.3)
        case .critical: return Color.red.opacity(0.25)
        case .urgent: return Color.orange.opacity(0.2)
        case .soon: return Color.yellow.opacity(0.15)
        case .later: return Color.green.opacity(0.1)
        case .none: return Color.gray.opacity(0.1)
        }
    }
    
    var label: String {
        switch self {
        case .overdue: return "OVERDUE"
        case .critical: return "DO NOW"
        case .urgent: return "URGENT"
        case .soon: return "SOON"
        case .later: return "LATER"
        case .none: return ""
        }
    }
    
    var shouldPulse: Bool {
        self == .overdue || self == .critical
    }
}

// MARK: - Ranked Task (with computed score)

struct RankedTask: Identifiable {
    let task: AppTask
    let score: Double
    let rank: Int
    let movement: Int  // +/- from last position
    
    var id: UUID { task.id }
    
    var movementDisplay: String {
        if movement > 0 { return "▲+\(movement)" }
        if movement < 0 { return "▼\(movement)" }
        return "━"
    }
    
    var movementColor: Color {
        if movement > 0 { return .red }  // Moving up = more urgent = red
        if movement < 0 { return .green }  // Moving down = less urgent = green
        return .gray
    }
    
    // Score display (rounded)
    var scoreDisplay: String {
        return "\(Int(score))"
    }
    
    // Score-based urgency level (for colors/flashing)
    var scoreUrgency: ScoreUrgency {
        if score >= 800 { return .critical }
        if score >= 500 { return .veryHigh }
        if score >= 300 { return .high }
        if score >= 150 { return .medium }
        if score >= 50 { return .low }
        return .minimal
    }
}

// MARK: - Score-Based Urgency

enum ScoreUrgency: Int, CaseIterable {
    case critical = 0   // 800+ (FLASHING RED)
    case veryHigh = 1   // 500-799 (solid red)
    case high = 2       // 300-499 (orange)
    case medium = 3     // 150-299 (yellow)
    case low = 4        // 50-149 (green)
    case minimal = 5    // <50 (gray)
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .veryHigh: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .minimal: return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .critical: return Color.red.opacity(0.35)
        case .veryHigh: return Color.red.opacity(0.25)
        case .high: return Color.orange.opacity(0.2)
        case .medium: return Color.yellow.opacity(0.15)
        case .low: return Color.green.opacity(0.1)
        case .minimal: return Color.gray.opacity(0.1)
        }
    }
    
    var glowColor: Color {
        switch self {
        case .critical: return .red
        case .veryHigh: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .minimal: return .clear
        }
    }
    
    var label: String {
        switch self {
        case .critical: return "🔥 CRITICAL"
        case .veryHigh: return "DO NOW"
        case .high: return "URGENT"
        case .medium: return "SOON"
        case .low: return "LATER"
        case .minimal: return ""
        }
    }
    
    var shouldPulse: Bool {
        self == .critical
    }
    
    var shouldGlow: Bool {
        self == .critical || self == .veryHigh
    }
}

// MARK: - Priority Engine

@MainActor
class TaskPriorityEngine: ObservableObject {
    @Published var allTasks: [AppTask] = []
    @Published var rankedTasks: [RankedTask] = []
    @Published var dangerZoneTasks: [RankedTask] = []  // Tasks < 30 min
    @Published var lastUpdated: Date = Date()
    
    private var timer: Timer?
    private var previousRanks: [UUID: Int] = [:]
    
    init() {
        loadTasks()
        startAutoUpdate()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Auto Update (every 30 seconds)
    
    func startAutoUpdate() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recalculateRanks()
            }
        }
        recalculateRanks()
    }
    
    // MARK: - Dynamic Priority Score (DPS) Algorithm
    
    func calculateDPS(for task: AppTask) -> Double {
        // Base Priority Score
        let basePriorityScore: Double
        switch task.basePriority.lowercased() {
        case "high": basePriorityScore = 100
        case "medium": basePriorityScore = 60
        case "low": basePriorityScore = 30
        default: basePriorityScore = 50
        }
        
        // Frequency Weight (less frequent = bigger deal to miss)
        let frequencyWeight: Double
        switch task.frequency.lowercased() {
        case "daily": frequencyWeight = 0.7
        case "weekly": frequencyWeight = 1.0
        case "monthly": frequencyWeight = 1.3
        case "yearly": frequencyWeight = 1.5
        case "once": frequencyWeight = 1.4
        default: frequencyWeight = 1.0
        }
        
        // Urgency Multiplier (exponential as deadline approaches)
        let urgencyMultiplier: Double
        if let remaining = task.timeRemaining {
            if remaining < 0 {
                // Overdue - massive boost
                let overdueMinutes = abs(remaining) / 60
                urgencyMultiplier = 10.0 + min(overdueMinutes / 10, 20)  // Up to 30x for very overdue
            } else if remaining < 5 * 60 {
                // < 5 minutes
                urgencyMultiplier = 8.0
            } else if remaining < 15 * 60 {
                // < 15 minutes
                urgencyMultiplier = 5.0
            } else if remaining < 30 * 60 {
                // < 30 minutes
                urgencyMultiplier = 3.5
            } else if remaining < 60 * 60 {
                // < 1 hour
                urgencyMultiplier = 2.5
            } else if remaining < 2 * 60 * 60 {
                // < 2 hours
                urgencyMultiplier = 1.8
            } else if remaining < 4 * 60 * 60 {
                // < 4 hours
                urgencyMultiplier = 1.4
            } else if remaining < 24 * 60 * 60 {
                // < 24 hours
                urgencyMultiplier = 1.1
            } else {
                // 24+ hours away
                urgencyMultiplier = 1.0
            }
        } else {
            // No due date - lowest urgency
            urgencyMultiplier = 0.5
        }
        
        // Calculate final DPS
        let dps = basePriorityScore * urgencyMultiplier * frequencyWeight
        
        return dps
    }
    
    // MARK: - Recalculate Rankings
    
    func recalculateRanks() {
        // Store previous ranks for movement calculation
        for ranked in rankedTasks {
            previousRanks[ranked.task.id] = ranked.rank
        }
        
        // Filter incomplete tasks and calculate scores
        let incompleteTasks = allTasks.filter { !$0.isCompleted }
        
        var scored: [(task: AppTask, score: Double)] = incompleteTasks.map { task in
            (task: task, score: calculateDPS(for: task))
        }
        
        // Sort by score descending (highest = most urgent)
        scored.sort { $0.score > $1.score }
        
        // Create ranked tasks with movement
        rankedTasks = scored.enumerated().map { index, item in
            let previousRank = previousRanks[item.task.id] ?? index + 1
            let movement = previousRank - (index + 1)  // Positive = moved up
            
            return RankedTask(
                task: item.task,
                score: item.score,
                rank: index + 1,
                movement: movement
            )
        }
        
        // Danger zone: tasks due in < 30 minutes (EXCLUDING low priority routine tasks)
        dangerZoneTasks = rankedTasks.filter { ranked in
            // Skip low priority routine tasks
            let title = ranked.task.title.lowercased()
            let isRoutineTask = title.contains("bathroom") || title.contains("brush teeth") ||
                               title.contains("watch tv") || title.contains("shower") ||
                               title.contains("bath") || title.contains("wash face") ||
                               title.contains("floss") || title.contains("use restroom") ||
                               title.contains("get dressed") || title.contains("wake up") ||
                               title.contains("go to bed") || title.contains("skincare") ||
                               title.contains("meditate") || title.contains("relax")
            
            if isRoutineTask || ranked.task.basePriority.lowercased() == "low" {
                return false
            }
            
            if let remaining = ranked.task.timeRemaining {
                return remaining < 30 * 60 && remaining > -24 * 60 * 60  // < 30 min but not more than 24h overdue
            }
            return false
        }
        
        lastUpdated = Date()
        
        // Update last positions in tasks
        for ranked in rankedTasks {
            if let index = allTasks.firstIndex(where: { $0.id == ranked.task.id }) {
                allTasks[index].lastRankPosition = ranked.rank
            }
        }
        
        saveTasks()
    }
    
    // MARK: - Task Management
    
    func addTask(_ task: AppTask) {
        allTasks.append(task)
        recalculateRanks()
    }
    
    func completeTask(_ taskId: UUID) {
        if let index = allTasks.firstIndex(where: { $0.id == taskId }) {
            allTasks[index].isCompleted = true
            allTasks[index].completedAt = Date()
            recalculateRanks()
        }
    }
    
    func uncompleteTask(_ taskId: UUID) {
        if let index = allTasks.firstIndex(where: { $0.id == taskId }) {
            allTasks[index].isCompleted = false
            allTasks[index].completedAt = nil
            recalculateRanks()
        }
    }
    
    func deleteTask(_ taskId: UUID) {
        allTasks.removeAll { $0.id == taskId }
        recalculateRanks()
    }
    
    func updateTask(_ task: AppTask) {
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[index] = task
            recalculateRanks()
        }
    }
    
    // MARK: - Filtered Lists
    
    func topTasks(_ count: Int) -> [RankedTask] {
        Array(rankedTasks.prefix(count))
    }
    
    var completedToday: [AppTask] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay
        }
    }
    
    // MARK: - Persistence
    
    private let tasksKey = "appTasks_v1"
    
    func saveTasks() {
        if let encoded = try? JSONEncoder().encode(allTasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let tasks = try? JSONDecoder().decode([AppTask].self, from: data) {
            allTasks = tasks
        } else {
            // Start with empty tasks - user will add via onboarding or quick add
            allTasks = []
        }
        recalculateRanks()
    }
    
    // Call this manually if you want sample data for testing
    func loadSampleTasksForDemo() {
        loadSampleTasks()
        saveTasks()
        recalculateRanks()
    }
    
    // MARK: - Sample Tasks for Demo
    
    func loadSampleTasks() {
        let now = Date()
        let calendar = Calendar.current
        
        allTasks = [
            AppTask(
                title: "Pick up Emma from school",
                category: "Kids",
                categoryIcon: "figure.and.child.holdinghands",
                categoryColor: "cyan",
                frequency: "daily",
                basePriority: "high",
                dueDate: calendar.date(byAdding: .minute, value: 25, to: now),
                dueTime: formatTime(calendar.date(byAdding: .minute, value: 25, to: now)!),
                duration: 20
            ),
            AppTask(
                title: "Take blood pressure medication",
                category: "Health",
                categoryIcon: "heart.fill",
                categoryColor: "red",
                frequency: "daily",
                basePriority: "high",
                dueDate: calendar.date(byAdding: .minute, value: 45, to: now),
                dueTime: formatTime(calendar.date(byAdding: .minute, value: 45, to: now)!),
                duration: 2
            ),
            AppTask(
                title: "Team standup meeting",
                category: "Work",
                categoryIcon: "briefcase.fill",
                categoryColor: "blue",
                frequency: "daily",
                basePriority: "high",
                dueDate: calendar.date(byAdding: .hour, value: 2, to: now),
                dueTime: formatTime(calendar.date(byAdding: .hour, value: 2, to: now)!),
                duration: 15
            ),
            AppTask(
                title: "Call dentist to schedule checkup",
                category: "Health",
                categoryIcon: "heart.fill",
                categoryColor: "red",
                frequency: "once",
                basePriority: "medium",
                dueDate: calendar.date(byAdding: .hour, value: 3, to: now),
                dueTime: nil,
                duration: 10
            ),
            AppTask(
                title: "Grocery shopping",
                category: "Errands",
                categoryIcon: "cart.fill",
                categoryColor: "pink",
                frequency: "weekly",
                basePriority: "medium",
                dueDate: calendar.date(byAdding: .hour, value: 5, to: now),
                dueTime: nil,
                duration: 60
            ),
            AppTask(
                title: "Walk the dog",
                category: "Pets",
                categoryIcon: "pawprint.fill",
                categoryColor: "brown",
                frequency: "daily",
                basePriority: "medium",
                dueDate: calendar.date(byAdding: .hour, value: 1, to: now),
                dueTime: formatTime(calendar.date(byAdding: .hour, value: 1, to: now)!),
                duration: 20
            ),
            AppTask(
                title: "Pay electric bill",
                category: "Finance",
                categoryIcon: "dollarsign.circle.fill",
                categoryColor: "yellow",
                frequency: "monthly",
                basePriority: "high",
                dueDate: calendar.date(byAdding: .day, value: 2, to: now),
                dueTime: nil,
                duration: 10
            ),
            AppTask(
                title: "Finish project presentation",
                category: "Work",
                categoryIcon: "briefcase.fill",
                categoryColor: "blue",
                frequency: "once",
                basePriority: "high",
                dueDate: calendar.date(byAdding: .day, value: 1, to: now),
                dueTime: "17:00",
                duration: 120
            ),
            AppTask(
                title: "Yoga class",
                category: "Health",
                categoryIcon: "figure.yoga",
                categoryColor: "purple",
                frequency: "weekly",
                basePriority: "low",
                dueDate: calendar.date(byAdding: .hour, value: 8, to: now),
                dueTime: formatTime(calendar.date(byAdding: .hour, value: 8, to: now)!),
                duration: 60
            ),
            AppTask(
                title: "Read 30 pages of book",
                category: "Personal",
                categoryIcon: "book.fill",
                categoryColor: "indigo",
                frequency: "daily",
                basePriority: "low",
                dueDate: calendar.date(byAdding: .hour, value: 12, to: now),
                dueTime: nil,
                duration: 30
            ),
            AppTask(
                title: "Water plants",
                category: "Home",
                categoryIcon: "leaf.fill",
                categoryColor: "green",
                frequency: "weekly",
                basePriority: "low",
                dueDate: calendar.date(byAdding: .day, value: 3, to: now),
                dueTime: nil,
                duration: 10
            ),
            AppTask(
                title: "Oil change for car",
                category: "Errands",
                categoryIcon: "car.fill",
                categoryColor: "orange",
                frequency: "monthly",
                basePriority: "medium",
                dueDate: calendar.date(byAdding: .day, value: 5, to: now),
                dueTime: nil,
                duration: 45
            )
        ]
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Import from Onboarding
    
    func importFromOnboarding(_ onboardingTasks: [SOTask]) {
        let today = Date()
        
        for soTask in onboardingTasks where soTask.isSelected {
            // Convert SOTask to AppTask
            let dueDate: Date?
            let dueTime: String?
            
            switch soTask.frequency {
            case .daily:
                dueDate = today
                dueTime = soTask.time.isEmpty ? nil : soTask.time
            case .weekly:
                dueDate = nextOccurrence(daysOfWeek: soTask.daysOfWeek) ?? today
                dueTime = soTask.time.isEmpty ? nil : soTask.time
            case .monthly:
                dueDate = nextMonthlyOccurrence(day: soTask.dayOfMonth ?? 1)
                dueTime = soTask.time.isEmpty ? nil : soTask.time
            case .yearly:
                dueDate = nextYearlyOccurrence(month: soTask.monthOfYear ?? 1, day: soTask.dayOfMonth ?? 1)
                dueTime = soTask.time.isEmpty ? nil : soTask.time
            case .once:
                dueDate = soTask.dueDate ?? today
                dueTime = soTask.time.isEmpty ? nil : soTask.time
            }
            
            let appTask = AppTask(
                id: soTask.id,
                title: soTask.title,
                category: soTask.category.rawValue,
                categoryIcon: categoryIcon(for: soTask.category),
                categoryColor: categoryColorName(for: soTask.category),
                frequency: soTask.frequency.rawValue.lowercased(),
                basePriority: soTask.priority.rawValue.lowercased(),
                dueDate: dueDate,
                dueTime: dueTime,
                duration: soTask.duration
            )
            
            // Only add if not already exists
            if !allTasks.contains(where: { $0.id == appTask.id }) {
                allTasks.append(appTask)
            }
        }
        
        recalculateRanks()
        saveTasks()
    }
    
    private func nextOccurrence(daysOfWeek: [String]) -> Date? {
        guard !daysOfWeek.isEmpty else { return nil }
        let dayMap = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
                      "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]
        let today = Calendar.current.component(.weekday, from: Date())
        
        for dayName in daysOfWeek {
            if let targetDay = dayMap[dayName.lowercased()] {
                var daysToAdd = targetDay - today
                if daysToAdd <= 0 { daysToAdd += 7 }
                return Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())
            }
        }
        return nil
    }
    
    private func nextMonthlyOccurrence(day: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.day = min(day, 28)
        if let date = Calendar.current.date(from: components), date > Date() {
            return date
        }
        components.month! += 1
        return Calendar.current.date(from: components)
    }
    
    private func nextYearlyOccurrence(month: Int, day: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.month = month
        components.day = min(day, 28)
        if let date = Calendar.current.date(from: components), date > Date() {
            return date
        }
        components.year! += 1
        return Calendar.current.date(from: components)
    }
    
    private func categoryIcon(for category: SOCategory) -> String {
        return category.icon
    }
    
    private func categoryColorName(for category: SOCategory) -> String {
        switch category {
        case .morning: return "orange"
        case .health: return "red"
        case .kids: return "cyan"
        case .pets: return "brown"
        case .elderCare: return "purple"
        case .home: return "green"
        case .work: return "blue"
        case .finance: return "yellow"
        case .errands: return "pink"
        case .social: return "indigo"
        case .personal: return "gray"
        case .night: return "purple"
        }
    }
    
    // Clear sample tasks and start fresh
    func clearAllTasks() {
        allTasks = []
        previousRanks = [:]
        // Remove from UserDefaults completely
        UserDefaults.standard.removeObject(forKey: tasksKey)
        recalculateRanks()
    }
}
