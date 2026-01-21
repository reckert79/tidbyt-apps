//
//  ContentView.swift
//  VisualMemory - With Overdue Section
//  Main dashboard with overdue tasks access
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    
    @State private var showingAllTasks = false
    @State private var showingAddTask = false
    @State private var showingSettings = false
    @State private var showingOverdue = false
    @State private var showingVoiceInput = false
    @State private var selectedUserId: UUID? = nil
    @State private var currentTime: Date = Date.now
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var filteredTasks: [VisualTask] {
        if let userId = selectedUserId {
            return dataManager.tasks(for: userId)
        }
        return dataManager.urgentTasks
    }
    
    var overdueCount: Int {
        // Exclude low priority recurring tasks from overdue count
        dataManager.tasks.filter { task in
            !task.isCompleted &&
            task.isOverdue &&
            !(task.isRecurring && task.basePriority == .low)
        }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                        Color(red: 0.1, green: 0.08, blue: 0.18),
                        Color(red: 0.08, green: 0.06, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        selectedUserId: $selectedUserId,
                        showingSettings: $showingSettings,
                        userManager: userManager
                    )
                    
                    // Task list
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if filteredTasks.isEmpty {
                                EmptyDashboardView()
                            } else {
                                ForEach(filteredTasks) { task in
                                    HorizontalHealthBarTaskRow(
                                        task: task,
                                        dayStartTime: userManager.currentUser?.dayStartTime ?? dataManager.settings.dayStartTime
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                    }
                }
                
                // Floating buttons - voice button on right
                VStack {
                    Spacer()
                    
                    // Bottom bar with all buttons
                    HStack(spacing: 12) {
                        // All Tasks button
                        Button(action: { showingAllTasks = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("All")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        
                        // Overdue button (if any overdue)
                        if overdueCount > 0 {
                            Button(action: { showingOverdue = true }) {
                                HStack(spacing: 5) {
                                    Text("✕")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.red)
                                    
                                    Text("\(overdueCount)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.25))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        Spacer()
                        
                        // Stats button
                        Button(action: { /* TODO: Show statistics */ }) {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Text("\(dataManager.userStats.currentStreak)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                HStack(spacing: 3) {
                                    Text("Lv")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.cyan)
                                    Text("\(dataManager.userStats.level)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                        
                        // Manual Add Task button
                        Button(action: { showingAddTask = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .cyan.opacity(0.4), radius: 6, y: 3)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Voice Input button (larger, with glow ring)
                        Button(action: { showingVoiceInput = true }) {
                            ZStack {
                                // Outer glow ring
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.5), .pink.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .purple.opacity(0.6), radius: 12, y: 4)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAllTasks) {
                AllTasksView()
                    .environmentObject(dataManager)
                    .environmentObject(userManager)
            }
            .fullScreenCover(isPresented: $showingAddTask) {
                AddTaskView()
                    .environmentObject(dataManager)
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(dataManager)
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showingOverdue) {
                OverdueTasksView()
                    .environmentObject(dataManager)
            }
            .fullScreenCover(isPresented: $showingVoiceInput) {
                EnhancedVoiceInputView()
                    .environmentObject(dataManager)
                    .environmentObject(userManager)
            }
            .onReceive(timer) { _ in
                currentTime = Date.now
                dataManager.checkVoiceAlerts()
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Binding var selectedUserId: UUID?
    @Binding var showingSettings: Bool
    @ObservedObject var userManager: UserManager
    
    var body: some View {
        HStack {
            WatermarkLogo()
            
            Spacer()
            
            // User Filter
            Menu {
                Button(action: { selectedUserId = nil }) {
                    Label("Everyone", systemImage: selectedUserId == nil ? "checkmark" : "")
                }
                Divider()
                ForEach(userManager.users) { user in
                    Button(action: { selectedUserId = user.id }) {
                        Label("\(user.avatarEmoji) \(user.name)", systemImage: selectedUserId == user.id ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let userId = selectedUserId,
                       let user = userManager.users.first(where: { $0.id == userId }) {
                        Text(user.avatarEmoji)
                        Text(user.name)
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14))
                        Text("All")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Watermark Logo
struct WatermarkLogo: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("VisualMemory")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .white, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Horizontal Health Bar Task Row
struct HorizontalHealthBarTaskRow: View {
    let task: VisualTask
    let dayStartTime: Date
    
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @State private var showingDetail = false
    @State private var isBlinking = false
    
    var healthProgress: Double {
        task.healthBarProgress(dayStartTime: dayStartTime)
    }
    
    // Color based on time remaining percentage
    var barColor: Color {
        if task.isOverdue { return .red }
        let progress = healthProgress
        if progress < 0.10 { return .red }       // Less than 10% - RED
        else if progress < 0.50 { return .yellow } // 10-49% - YELLOW
        else { return .green }                    // 50%+ - GREEN
    }
    
    var shouldBlink: Bool {
        !task.isOverdue && healthProgress < 0.05 && healthProgress > 0
    }
    
    var barGradient: LinearGradient {
        LinearGradient(
            colors: [barColor, barColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(spacing: 6) {
                // Main task bar with full title centered
                ZStack {
                    // Background bar
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 50)
                    
                    // Progress bar fill
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(barGradient)
                            .frame(width: max(0, geometry.size.width * healthProgress), height: 50)
                            .opacity(isBlinking ? 0.4 : 1.0)
                            .shadow(color: barColor.opacity(0.6), radius: 4, x: 0, y: 0)
                            .animation(.linear(duration: 1), value: healthProgress)
                    }
                    .frame(height: 50)
                    
                    // Full title centered in bar
                    VStack(spacing: 2) {
                        Text(task.fullScheduleDescription)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text(task.timeRemainingFormatted)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 50)
                
                // Info row below bar (simplified - no time here anymore)
                HStack(spacing: 8) {
                    // User Avatar
                    Text(task.userAvatar)
                        .font(.system(size: 16))
                    
                    Text(task.userName)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Priority indicator
                    HStack(spacing: 3) {
                        if task.isOverdue {
                            Text("✕")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(task.effectivePriorityLevel.color)
                        } else {
                            Circle()
                                .fill(task.effectivePriorityLevel.color)
                                .frame(width: 5, height: 5)
                        }
                        Text(task.effectivePriorityLevel.name)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(task.effectivePriorityLevel.color)
                    
                    if task.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    // Deadline date only (time is now in the bar)
                    Text(task.deadlineFormatted)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                task.isOverdue ? Color.red.opacity(0.5) :
                                    healthProgress < 0.10 ? Color.red.opacity(0.3) :
                                    Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
                .environmentObject(dataManager)
        }
        .onAppear {
            if shouldBlink {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
        }
        .onChange(of: shouldBlink) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            } else {
                isBlinking = false
            }
        }
    }
}

// MARK: - Empty Dashboard View
struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.cyan)
            }
            
            Text("All Clear!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Tap + to add a task")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: VisualTask
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showCompletionAnimation = false
    @State private var selectedPriority: PriorityLevel
    
    init(task: VisualTask) {
        self.task = task
        _selectedPriority = State(initialValue: task.effectivePriorityLevel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(task.userAvatar)
                            .font(.system(size: 60))
                        
                        Text(task.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Assigned to \(task.userName)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    
                    // Info Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Due")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(task.deadlineFormatted)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Time Remaining")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(task.timeRemainingFormatted)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(task.isOverdue ? .red : .cyan)
                            }
                        }
                        
                        // Schedule info
                        if task.isRecurring {
                            HStack {
                                Image(systemName: "repeat")
                                    .foregroundColor(.cyan)
                                Text(task.recurringDaysDescription)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Priority Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Priority")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 10) {
                                PriorityButton(
                                    priority: .low,
                                    isSelected: selectedPriority == .low,
                                    action: { updatePriority(.low) }
                                )
                                
                                PriorityButton(
                                    priority: .medium,
                                    isSelected: selectedPriority == .medium,
                                    action: { updatePriority(.medium) }
                                )
                                
                                PriorityButton(
                                    priority: .high,
                                    isSelected: selectedPriority == .high,
                                    action: { updatePriority(.high) }
                                )
                            }
                        }
                        
                        if task.voiceAlertsEnabled {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.purple)
                                Text("Siri voice alerts enabled")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                            }
                        }
                        
                        if task.reminderEnabled {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.orange)
                                Text("Reminder: \(task.reminderMinutesBefore) min before")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Action Buttons - More separated, Complete larger
                    VStack(spacing: 24) {
                        // Complete Button - Large and prominent
                        Button(action: {
                            showCompletionAnimation = true
                            
                            // Delay dismiss to show animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                dataManager.completeTask(task)
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                Text("Mark Complete")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 20)
                        
                        // Delete Button - Smaller and subtle
                        Button(action: {
                            dataManager.deleteTask(task)
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                Text("Delete Task")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                    .padding(.bottom, 30)
                }
                
                // Completion Animation Overlay
                if showCompletionAnimation {
                    TaskCompletionAnimationView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func updatePriority(_ priority: PriorityLevel) {
        selectedPriority = priority
        // Calculate adjustment needed from base priority
        let adjustment = priority.rawValue - task.basePriority.rawValue
        dataManager.setPriority(for: task, adjustment: adjustment)
    }
}

// MARK: - Priority Button
struct PriorityButton: View {
    let priority: PriorityLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(priority.color)
                    .frame(width: 10, height: 10)
                
                Text(priority.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? priority.color.opacity(0.3) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Completion Animation
struct TaskCompletionAnimationView: View {
    @State private var showCheckmark = false
    @State private var showRing = false
    @State private var showConfetti = false
    @State private var ringScale: CGFloat = 0.5
    @State private var checkmarkScale: CGFloat = 0.3
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Confetti particles
            if showConfetti {
                ForEach(0..<20, id: \.self) { i in
                    ConfettiParticle(index: i)
                }
            }
            
            // Ring animation
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
                .frame(width: 120, height: 120)
                .scaleEffect(ringScale)
                .opacity(showRing ? 1 : 0)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(checkmarkScale)
                .opacity(showCheckmark ? 1 : 0)
            
            // Text
            VStack {
                Spacer()
                
                Text("Task Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showCheckmark ? 1 : 0)
                    .offset(y: showCheckmark ? 0 : 20)
                
                Spacer()
                    .frame(height: 200)
            }
        }
        .onAppear {
            // Ring animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showRing = true
                ringScale = 1.0
            }
            
            // Checkmark animation (slightly delayed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    showCheckmark = true
                    checkmarkScale = 1.0
                }
            }
            
            // Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

struct ConfettiParticle: View {
    let index: Int
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    let colors: [Color] = [.green, .cyan, .yellow, .pink, .purple, .orange, .blue]
    
    var randomColor: Color {
        colors[index % colors.count]
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(randomColor)
            .frame(width: CGFloat.random(in: 8...14), height: CGFloat.random(in: 8...14))
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                let randomX = CGFloat.random(in: -150...150)
                let randomDelay = Double.random(in: 0...0.2)
                
                withAnimation(.easeOut(duration: 1.0).delay(randomDelay)) {
                    yOffset = CGFloat.random(in: 100...300)
                    xOffset = randomX
                    rotation = Double.random(in: 180...720)
                    opacity = 0
                }
            }
    }
}

// MARK: - Overdue Tasks View

struct OverdueTasksView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @Environment(\.dismiss) var dismiss
    
    var overdueTasks: [VisualTask] {
        dataManager.tasks.filter { !$0.isCompleted && $0.isOverdue }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()
                
                if overdueTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No Overdue Tasks!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("You're all caught up")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(overdueTasks) { task in
                                OverdueTaskRow(task: task)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Overdue Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct OverdueTaskRow: View {
    let task: VisualTask
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(task.deadlineFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: {
                dataManager.completeTask(task)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
