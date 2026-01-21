import SwiftUI
import Combine

// MARK: - Display Mode

enum TaskDisplayMode: String, CaseIterable {
    case top3 = "Top 3"
    case top10 = "Top 10"
    case all = "All"
    
    var count: Int? {
        switch self {
        case .top3: return 3
        case .top10: return 10
        case .all: return nil
        }
    }
}

// MARK: - Main Task View

struct MainTaskView: View {
    @StateObject private var engine = TaskPriorityEngine()
    @State private var displayMode: TaskDisplayMode = .all
    @State private var showingAddTask: Bool = false
    
    var displayedTasks: [RankedTask] {
        // Get incomplete tasks
        var tasks: [RankedTask]
        if let count = displayMode.count {
            tasks = engine.topTasks(count)
        } else {
            tasks = engine.rankedTasks
        }
        
        // Add today's completed tasks at the bottom (as RankedTask with low score)
        let completedRanked = engine.completedToday.map { task in
            RankedTask(task: task, score: -1, rank: 999, movement: 0)
        }
        
        return tasks + completedRanked
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.1, green: 0.08, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Danger Zone (if tasks due < 30 min)
                        if !engine.dangerZoneTasks.isEmpty {
                            dangerZoneSection
                        }
                        
                        // Display mode selector
                        displayModeSelector
                        
                        // Main task list (includes completed tasks with strikethrough)
                        taskListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            
            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addTaskButton
                }
            }
            .padding(20)
            
            // Add task sheet
            if showingAddTask {
                QuickAddTaskOverlay(engine: engine, isShowing: $showingAddTask)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Settings / Onboarding access
                Button(action: { /* Open settings/onboarding */ }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            
            // Score Legend
            scoreLegend
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    var scoreLegend: some View {
        HStack(spacing: 6) {
            ScoreLegendItem(label: "800+", color: .red, description: "CRITICAL")
            ScoreLegendItem(label: "500+", color: Color(red: 1.0, green: 0.2, blue: 0.2), description: "DO NOW")
            ScoreLegendItem(label: "300+", color: .orange, description: "URGENT")
            ScoreLegendItem(label: "150+", color: .yellow, description: "SOON")
            ScoreLegendItem(label: "<150", color: .green, description: "LATER")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Danger Zone
    
    var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                Text("DO NOW")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.red)
                Spacer()
                Text("\(engine.dangerZoneTasks.count) urgent")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.7))
            }
            
            ForEach(engine.dangerZoneTasks) { ranked in
                DangerZoneCard(ranked: ranked, onComplete: {
                    withAnimation { engine.completeTask(ranked.task.id) }
                })
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                )
        )
        .modifier(PulseModifier())
    }
    
    // MARK: - Display Mode Selector
    
    var displayModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TaskDisplayMode.allCases, id: \.self) { mode in
                Button(action: { withAnimation { displayMode = mode } }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(displayMode == mode ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(displayMode == mode ? Color.purple : Color.white.opacity(0.1))
                        )
                }
            }
            
            Spacer()
            
            Text("Updated \(timeAgo(engine.lastUpdated))")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        return "\(Int(seconds / 60))m ago"
    }
    
    // MARK: - Task List
    
    var taskListSection: some View {
        VStack(spacing: 12) {
            ForEach(displayedTasks) { ranked in
                // Skip if already in danger zone (and not completed)
                if !ranked.task.isCompleted && engine.dangerZoneTasks.contains(where: { $0.id == ranked.id }) {
                    // Skip - shown in danger zone
                } else {
                    TaskCard(
                        ranked: ranked,
                        onComplete: {
                            withAnimation(.spring()) { engine.completeTask(ranked.task.id) }
                        },
                        onUncomplete: {
                            withAnimation(.spring()) { engine.uncompleteTask(ranked.task.id) }
                        }
                    )
                }
            }
            
            if displayedTasks.isEmpty && engine.dangerZoneTasks.isEmpty {
                emptyState
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            Text("All caught up!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("No tasks need your attention right now")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(40)
    }
    
    // MARK: - Add Task Button
    
    var addTaskButton: some View {
        Button(action: { showingAddTask = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
                )
        }
    }
}

// MARK: - Danger Zone Card (for critical tasks)

struct DangerZoneCard: View {
    let ranked: RankedTask
    let onComplete: () -> Void
    @State private var timeRemaining: String = ""
    @State private var currentScore: Double
    @State private var pulseScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(ranked: RankedTask, onComplete: @escaping () -> Void) {
        self.ranked = ranked
        self.onComplete = onComplete
        self._currentScore = State(initialValue: ranked.score)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Big flashing score
            VStack(spacing: 0) {
                Text("\(Int(currentScore))")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .red, radius: 10)
                Text("PTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
            }
            .frame(width: 75)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.25)))
            .scaleEffect(pulseScale)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ranked.task.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(timeRemaining)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                    
                    if let relative = ranked.task.relativeTimeDisplay {
                        Text("• \(relative)")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Complete button
            Button(action: onComplete) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.2)))
        .onReceive(timer) { _ in
            timeRemaining = ranked.task.timeRemainingDisplay
            recalculateScore()
        }
        .onAppear {
            timeRemaining = ranked.task.timeRemainingDisplay
            currentScore = ranked.score
            // Pulsing animation
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
    
    func recalculateScore() {
        let basePriorityScore: Double
        switch ranked.task.basePriority.lowercased() {
        case "high": basePriorityScore = 100
        case "medium": basePriorityScore = 60
        case "low": basePriorityScore = 30
        default: basePriorityScore = 50
        }
        
        let frequencyWeight: Double
        switch ranked.task.frequency.lowercased() {
        case "daily": frequencyWeight = 0.7
        case "weekly": frequencyWeight = 1.0
        case "monthly": frequencyWeight = 1.3
        default: frequencyWeight = 1.0
        }
        
        let urgencyMultiplier: Double
        if let remaining = ranked.task.timeRemaining {
            if remaining < 0 {
                let overdueMinutes = abs(remaining) / 60
                urgencyMultiplier = 10.0 + min(overdueMinutes / 10, 20)
            } else if remaining < 5 * 60 {
                urgencyMultiplier = 8.0
            } else if remaining < 15 * 60 {
                urgencyMultiplier = 5.0
            } else if remaining < 30 * 60 {
                urgencyMultiplier = 3.5
            } else {
                urgencyMultiplier = 2.5
            }
        } else {
            urgencyMultiplier = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentScore = basePriorityScore * urgencyMultiplier * frequencyWeight
        }
    }
}

// MARK: - Task Card

struct TaskCard: View {
    let ranked: RankedTask
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    @State private var timeRemaining: String = ""
    @State private var currentScore: Double
    @State private var pulseScale: CGFloat = 1.0
    
    // Real-time update timer (every 5 seconds for score)
    let scoreTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let displayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(ranked: RankedTask, onComplete: @escaping () -> Void, onUncomplete: @escaping () -> Void) {
        self.ranked = ranked
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self._currentScore = State(initialValue: ranked.score)
    }
    
    var isCompleted: Bool { ranked.task.isCompleted }
    
    var currentScoreUrgency: ScoreUrgency {
        if currentScore >= 800 { return .critical }
        if currentScore >= 500 { return .veryHigh }
        if currentScore >= 300 { return .high }
        if currentScore >= 150 { return .medium }
        if currentScore >= 50 { return .low }
        return .minimal
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Big Score Display
            scoreDisplay
            
            // CENTER: Task Info
            VStack(spacing: 8) {
                // Task title - large and centered
                Text(ranked.task.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isCompleted ? .gray : .white)
                    .strikethrough(isCompleted, color: .gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                
                // Time remaining - LARGE and centered
                if !isCompleted {
                    Text(timeRemaining)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(currentScoreUrgency.color)
                        .frame(maxWidth: .infinity)
                }
                
                // Bottom info row - smaller
                HStack(spacing: 10) {
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: ranked.task.categoryIcon)
                            .font(.system(size: 10))
                        Text(ranked.task.category)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(isCompleted ? .gray : categoryColor.opacity(0.7))
                    
                    // Movement
                    if !isCompleted {
                        Text(ranked.movementDisplay)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ranked.movementColor)
                    }
                    
                    // Urgency label
                    if !isCompleted && !currentScoreUrgency.label.isEmpty && currentScoreUrgency != .low {
                        Text(currentScoreUrgency.label)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(currentScoreUrgency.color))
                    }
                    
                    if isCompleted {
                        Text("COMPLETED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.2)))
                    }
                }
            }
            
            Spacer()
            
            // RIGHT: Complete button (only if NOT overdue and NOT completed)
            if !ranked.task.isOverdue {
                Button(action: { isCompleted ? onUncomplete() : onComplete() }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 36))
                        .foregroundColor(isCompleted ? .green : .white.opacity(0.3))
                }
            } else if isCompleted {
                // Show checkmark only if completed (even if was overdue)
                Button(action: { onUncomplete() }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCompleted ? Color.white.opacity(0.03) : currentScoreUrgency.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCompleted ? Color.green.opacity(0.3) : currentScoreUrgency.color.opacity(0.5), lineWidth: currentScoreUrgency.shouldGlow ? 2 : 1)
                )
                .shadow(color: currentScoreUrgency.shouldGlow && !isCompleted ? currentScoreUrgency.glowColor.opacity(0.5) : .clear, radius: 10)
        )
        .scaleEffect(pulseScale)
        .opacity(isCompleted ? 0.6 : 1.0)
        .onReceive(displayTimer) { _ in
            timeRemaining = ranked.task.timeRemainingDisplay
            // Update score based on time
            if !isCompleted {
                recalculateScore()
            }
        }
        .onReceive(scoreTimer) { _ in
            if !isCompleted {
                recalculateScore()
            }
        }
        .onAppear {
            timeRemaining = ranked.task.timeRemainingDisplay
            currentScore = ranked.score
            
            // Start pulsing animation if critical AND not low priority
            if currentScoreUrgency.shouldPulse && !isCompleted && !isLowPriorityTask {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.03
                }
            }
        }
        .onChange(of: currentScoreUrgency.shouldPulse) { shouldPulse in
            if shouldPulse && !isCompleted && !isLowPriorityTask {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.03
                }
            } else {
                withAnimation(.default) {
                    pulseScale = 1.0
                }
            }
        }
    }
    
    // Check if this is a low-priority routine task that shouldn't flash red
    var isLowPriorityTask: Bool {
        let title = ranked.task.title.lowercased()
        let lowPriorityKeywords = ["bathroom", "brush teeth", "watch tv", "shower", "bath",
                                    "wash face", "floss", "use restroom", "get dressed",
                                    "wake up", "go to bed", "skincare", "meditate", "relax"]
        for keyword in lowPriorityKeywords {
            if title.contains(keyword) { return true }
        }
        return ranked.task.basePriority.lowercased() == "low"
    }
    
    // MARK: - Score Display (Hero Element)
    
    var scoreDisplay: some View {
        VStack(spacing: 2) {
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
            } else {
                // Big score number only (no PTS label)
                Text("\(Int(currentScore))")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(currentScoreUrgency.color)
                    .shadow(color: currentScoreUrgency.shouldGlow ? currentScoreUrgency.glowColor : .clear, radius: 8)
            }
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.green.opacity(0.15) : currentScoreUrgency.color.opacity(0.15))
        )
    }
    
    // MARK: - Recalculate Score in Real-time
    
    func recalculateScore() {
        // Base priority
        let basePriorityScore: Double
        switch ranked.task.basePriority.lowercased() {
        case "high": basePriorityScore = 100
        case "medium": basePriorityScore = 60
        case "low": basePriorityScore = 30
        default: basePriorityScore = 50
        }
        
        // Frequency weight
        let frequencyWeight: Double
        switch ranked.task.frequency.lowercased() {
        case "daily": frequencyWeight = 0.7
        case "weekly": frequencyWeight = 1.0
        case "monthly": frequencyWeight = 1.3
        case "yearly": frequencyWeight = 1.5
        case "once": frequencyWeight = 1.4
        default: frequencyWeight = 1.0
        }
        
        // Urgency multiplier based on time remaining
        let urgencyMultiplier: Double
        if let remaining = ranked.task.timeRemaining {
            if remaining < 0 {
                let overdueMinutes = abs(remaining) / 60
                urgencyMultiplier = 10.0 + min(overdueMinutes / 10, 20)
            } else if remaining < 5 * 60 {
                urgencyMultiplier = 8.0
            } else if remaining < 15 * 60 {
                urgencyMultiplier = 5.0
            } else if remaining < 30 * 60 {
                urgencyMultiplier = 3.5
            } else if remaining < 60 * 60 {
                urgencyMultiplier = 2.5
            } else if remaining < 2 * 60 * 60 {
                urgencyMultiplier = 1.8
            } else if remaining < 4 * 60 * 60 {
                urgencyMultiplier = 1.4
            } else if remaining < 24 * 60 * 60 {
                urgencyMultiplier = 1.1
            } else {
                urgencyMultiplier = 1.0
            }
        } else {
            urgencyMultiplier = 0.5
        }
        
        // Animate score change
        let newScore = basePriorityScore * urgencyMultiplier * frequencyWeight
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScore = newScore
        }
    }
    
    var categoryColor: Color {
        switch ranked.task.categoryColor {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "brown": return .brown
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Score Legend Item

struct ScoreLegendItem: View {
    let label: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(description)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Add Task Overlay

struct QuickAddTaskOverlay: View {
    @ObservedObject var engine: TaskPriorityEngine
    @Binding var isShowing: Bool
    
    @State private var title: String = ""
    @State private var selectedPriority: String = "medium"
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Date()
    @State private var hasTime: Bool = true
    @State private var dueTime: Date = Date()
    @State private var duration: Int = 30
    @State private var isListening: Bool = false
    @State private var voiceTranscript: String = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { isShowing = false }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { isShowing = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text("Add Task")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    // Balance
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.clear)
                }
                .padding(16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Voice Input Button
                        Button(action: toggleVoiceInput) {
                            HStack(spacing: 10) {
                                Image(systemName: isListening ? "waveform.circle.fill" : "mic.circle.fill")
                                    .font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isListening ? "Listening..." : "Tap to speak your task")
                                        .font(.system(size: 14, weight: .medium))
                                    if !voiceTranscript.isEmpty {
                                        Text("\"\(voiceTranscript)\"")
                                            .font(.system(size: 12))
                                            .foregroundColor(.cyan)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isListening ? Color.red.opacity(0.3) : Color.purple.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isListening ? Color.red : Color.purple, lineWidth: 2)
                                    )
                            )
                        }
                        
                        // Divider with "or"
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                            Text("or type").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                        }
                        
                        // Title
                        TextField("What needs to be done?", text: $title)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                            .foregroundColor(.white)
                            .onChange(of: title) { newValue in
                                // Auto-detect priority
                                selectedPriority = autoPriority(for: newValue)
                            }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Priority").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text("Auto-detected").font(.system(size: 10)).foregroundColor(.cyan.opacity(0.7))
                            }
                            HStack(spacing: 10) {
                                MTVPriorityButton(label: "Low", color: .green, isSelected: selectedPriority == "low") {
                                    selectedPriority = "low"
                                }
                                MTVPriorityButton(label: "Medium", color: .orange, isSelected: selectedPriority == "medium") {
                                    selectedPriority = "medium"
                                }
                                MTVPriorityButton(label: "High", color: .red, isSelected: selectedPriority == "high") {
                                    selectedPriority = "high"
                                }
                            }
                        }
                        
                        // Due Date
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Due Date").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Button(action: { hasDueDate.toggle() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: hasDueDate ? "checkmark.circle.fill" : "circle")
                                        Text(hasDueDate ? "On" : "Off")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(hasDueDate ? .cyan : .white.opacity(0.5))
                                }
                            }
                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .frame(height: 120)
                                    .clipped()
                                    .colorScheme(.dark)
                            }
                        }
                        
                        // Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Time").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Button(action: { hasTime.toggle() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: hasTime ? "checkmark.circle.fill" : "circle")
                                        Text(hasTime ? "On" : "Off")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(hasTime ? .cyan : .white.opacity(0.5))
                                }
                            }
                            if hasTime {
                                DatePicker("", selection: $dueTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .frame(height: 120)
                                    .clipped()
                                    .colorScheme(.dark)
                            }
                        }
                        
                        // Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                            Picker("", selection: $duration) {
                                Text("5 min").tag(5)
                                Text("15 min").tag(15)
                                Text("30 min").tag(30)
                                Text("45 min").tag(45)
                                Text("1 hr").tag(60)
                                Text("1.5 hr").tag(90)
                                Text("2 hr").tag(120)
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Add button
                Button(action: addTask) {
                    Text("Add Task")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .disabled(title.isEmpty)
                .opacity(title.isEmpty ? 0.5 : 1)
            }
            .background(Color(red: 0.08, green: 0.06, blue: 0.14))
            .cornerRadius(24)
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
        }
    }
    
    func toggleVoiceInput() {
        isListening.toggle()
        if isListening {
            // Start speech recognition
            // This would integrate with the SpeechRecognizer from onboarding
            // For now, simulate with placeholder
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if isListening {
                    // Simulated response - in real app, this comes from speech recognition
                    isListening = false
                }
            }
        }
    }
    
    func autoPriority(for taskTitle: String) -> String {
        let title = taskTitle.lowercased()
        
        // Low priority keywords
        let lowKeywords = ["brush", "teeth", "shower", "bath", "wash face", "meditate", "journal", "read", "relax", "tidy", "organize", "water plant"]
        for keyword in lowKeywords {
            if title.contains(keyword) { return "low" }
        }
        
        // High priority keywords
        let highKeywords = ["doctor", "dentist", "appointment", "medication", "medicine", "deadline", "urgent", "pay", "bill", "pick up", "drop off", "meeting"]
        for keyword in highKeywords {
            if title.contains(keyword) { return "high" }
        }
        
        return "medium"
    }
    
    func addTask() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let newTask = AppTask(
            title: title,
            category: "Personal",
            categoryIcon: "circle.fill",
            categoryColor: "gray",
            frequency: "once",
            basePriority: selectedPriority,
            dueDate: hasDueDate ? dueDate : nil,
            dueTime: hasTime ? formatter.string(from: dueTime) : nil,
            duration: duration
        )
        
        engine.addTask(newTask)
        isShowing = false
    }
}

struct MTVPriorityButton: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? color.opacity(0.35) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color : Color.clear, lineWidth: 1.5))
        }
    }
}

// MARK: - Preview

#Preview {
    MainTaskView()
}
