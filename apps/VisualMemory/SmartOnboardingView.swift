//
//  SmartOnboardingView.swift
//  VisualMemory
//  AI-powered smart onboarding UI
//

import SwiftUI

struct SmartOnboardingView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var manager = SmartOnboardingManager.shared
    @Environment(\.dismiss) var dismiss
    
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.15),
                    Color(red: 0.10, green: 0.06, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated background orbs
            GeometryReader { geo in
                Circle()
                    .fill(manager.currentStep.color.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -80, y: -150)
                
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: geo.size.width - 100, y: geo.size.height - 250)
            }
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Progress bar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // Main content
                contentSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    var headerSection: some View {
        HStack {
            if manager.canGoBack {
                Button(action: { manager.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(manager.currentStep.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                onComplete?()
                dismiss()
            }) {
                Text("Skip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Progress Bar
    
    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [manager.currentStep.color, manager.currentStep.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * manager.progress, height: 6)
                    .animation(.spring(response: 0.4), value: manager.progress)
            }
        }
        .frame(height: 6)
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    var contentSection: some View {
        switch manager.currentStep {
        case .welcome:
            welcomeView
        case .generating:
            generatingView
        case .review:
            reviewView
        case .complete:
            completeView
        default:
            questionView
        }
    }
    
    // MARK: - Welcome View
    
    var welcomeView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 16) {
                Text("Let's Build Your Routine")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                Text("I'll ask a few simple questions about your typical day, then create a personalized task list just for you.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Features
            VStack(spacing: 12) {
                FeatureItem(icon: "clock.fill", text: "Based on your actual schedule", color: .orange)
                FeatureItem(icon: "person.2.fill", text: "Accounts for kids & pets", color: .pink)
                FeatureItem(icon: "figure.run", text: "Includes exercise & hobbies", color: .green)
                FeatureItem(icon: "brain.head.profile", text: "AI fills in the gaps", color: .cyan)
            }
            .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Question View
    
    var questionView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Step icon
            ZStack {
                Circle()
                    .fill(manager.currentStep.color.opacity(0.2))
                    .frame(width: 90, height: 90)
                
                Image(systemName: manager.currentStep.icon)
                    .font(.system(size: 40))
                    .foregroundColor(manager.currentStep.color)
            }
            
            // Question
            Text(manager.currentStep.question)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Mic button
            VStack(spacing: 12) {
                Button(action: {
                    if manager.isListening {
                        manager.stopListening()
                    } else {
                        Task {
                            await manager.startListening()
                        }
                    }
                }) {
                    ZStack {
                        // Pulsing ring
                        if manager.isListening {
                            Circle()
                                .stroke(manager.currentStep.color.opacity(0.4), lineWidth: 4)
                                .frame(width: 110, height: 110)
                                .scaleEffect(manager.isListening ? 1.2 : 1.0)
                                .opacity(manager.isListening ? 0 : 1)
                                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: manager.isListening)
                        }
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: manager.isListening ? [.red, .red.opacity(0.8)] : [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 85, height: 85)
                            .shadow(color: manager.isListening ? Color.red.opacity(0.5) : Color.purple.opacity(0.5), radius: 15, y: 5)
                        
                        if manager.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.3)
                        } else {
                            Image(systemName: manager.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(manager.isProcessing)
                
                Text(manager.isListening ? "Tap when done" : "Tap to answer")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Transcript
            if !manager.transcript.isEmpty {
                Text("\"\(manager.transcript)\"")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    .padding(.horizontal, 30)
            }
            
            // Example answers
            exampleAnswers
                .padding(.top, 8)
            
            Spacer()
        }
    }
    
    var exampleAnswers: some View {
        VStack(spacing: 6) {
            Text("Try saying:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Text(exampleForStep)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    var exampleForStep: String {
        switch manager.currentStep {
        case .wakeUpTime: return "\"I wake up at 7 AM\""
        case .leaveHouseTime: return "\"I leave at 8:30\" or \"I work from home\""
        case .workOrSchool: return "\"I work in an office\" or \"I'm a student\""
        case .returnHomeTime: return "\"I get home around 6 PM\""
        case .bedtime: return "\"I go to bed at 10:30\""
        case .lifestyle: return "\"I have 2 kids and a dog, I exercise in the morning\""
        default: return ""
        }
    }
    
    // MARK: - Generating View
    
    var generatingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated sparkles
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.0 + Double(i) * 0.3)
                        .opacity(0.5 - Double(i) * 0.15)
                }
                
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 12) {
                Text("Building Your Routine")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Using AI to create your personalized daily schedule...")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.5)
                .padding(.top, 20)
            
            // Show what we know
            VStack(alignment: .leading, spacing: 8) {
                if !manager.userProfile.wakeUpTime.isEmpty {
                    InfoChip(icon: "sunrise.fill", text: "Wake: \(formatTime(manager.userProfile.wakeUpTime))", color: .orange)
                }
                if let leave = manager.userProfile.leaveHouseTime {
                    InfoChip(icon: "door.left.hand.open", text: "Leave: \(formatTime(leave))", color: .blue)
                }
                if !manager.userProfile.returnHomeTime.isEmpty {
                    InfoChip(icon: "house.fill", text: "Home: \(formatTime(manager.userProfile.returnHomeTime))", color: .green)
                }
                if manager.userProfile.hasKids {
                    InfoChip(icon: "figure.2.and.child.holdinghands", text: "\(manager.userProfile.numberOfKids) kid(s)", color: .pink)
                }
                if manager.userProfile.hasPets {
                    InfoChip(icon: "pawprint.fill", text: manager.userProfile.petTypes.joined(separator: ", "), color: .brown)
                }
            }
            .padding(.top, 30)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Review View
    
    var reviewView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Daily Routine")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(manager.selectedTasks.count) tasks selected")
                        .font(.system(size: 13))
                        .foregroundColor(.cyan)
                }
                
                Spacer()
                
                // Select all / none
                Button(action: {
                    let allSelected = manager.selectedTasks.count == manager.generatedTasks.count
                    for i in manager.generatedTasks.indices {
                        manager.generatedTasks[i].isSelected = !allSelected
                    }
                }) {
                    Text(manager.selectedTasks.count == manager.generatedTasks.count ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Task list by category
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(["morning", "afternoon", "evening", "night"], id: \.self) { category in
                        let categoryTasks = manager.generatedTasks.filter { $0.category == category }
                        if !categoryTasks.isEmpty {
                            TaskCategorySection(
                                category: category,
                                tasks: categoryTasks,
                                onToggle: { task in manager.toggleTask(task) },
                                onRemove: { task in manager.removeTask(task) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Complete View
    
    var completeView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(manager.selectedTasks.count) tasks have been added to your routine")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Quick stats
            HStack(spacing: 30) {
                SmartStatBubble(value: "\(taskCount(for: "morning"))", label: "Morning", color: .orange)
                SmartStatBubble(value: "\(taskCount(for: "afternoon"))", label: "Afternoon", color: .cyan)
                SmartStatBubble(value: "\(taskCount(for: "evening"))", label: "Evening", color: .green)
            }
            .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
    }
    
    func taskCount(for category: String) -> Int {
        manager.selectedTasks.filter { $0.category == category }.count
    }
    
    // MARK: - Bottom Buttons
    
    @ViewBuilder
    var bottomButtons: some View {
        switch manager.currentStep {
        case .welcome:
            Button(action: { manager.nextStep() }) {
                HStack(spacing: 12) {
                    Text("Let's Go!")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
            }
            
        case .generating:
            EmptyView()
            
        case .review:
            Button(action: {
                manager.createTasksInApp(dataManager: dataManager, userManager: userManager)
                manager.nextStep()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Add \(manager.selectedTasks.count) Tasks")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
            }
            
        case .complete:
            Button(action: {
                onComplete?()
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                    Text("Start Using App")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
            }
            
        default:
            HStack(spacing: 16) {
                Button(action: { manager.nextStep() }) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                }
                
                Button(action: { manager.nextStep() }) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(manager.currentStep.color))
                }
            }
        }
    }
    
    func formatTime(_ time: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return time
    }
}

// MARK: - Supporting Views

struct FeatureItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

struct SmartStatBubble: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 80)
    }
}

struct TaskCategorySection: View {
    let category: String
    let tasks: [GeneratedTask]
    let onToggle: (GeneratedTask) -> Void
    let onRemove: (GeneratedTask) -> Void
    
    var categoryTitle: String {
        switch category {
        case "morning": return "🌅 Morning"
        case "afternoon": return "☀️ Afternoon"
        case "evening": return "🌆 Evening"
        case "night": return "🌙 Night"
        default: return category.capitalized
        }
    }
    
    var categoryColor: Color {
        switch category {
        case "morning": return .orange
        case "afternoon": return .cyan
        case "evening": return .green
        case "night": return .indigo
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(categoryTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(categoryColor)
            
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 12) {
                    // Toggle
                    Button(action: { onToggle(task) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(task.isSelected ? Color.green : Color.white.opacity(0.1))
                                .frame(width: 24, height: 24)
                            
                            if task.isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Task info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(task.isSelected ? .white : .white.opacity(0.4))
                            .strikethrough(!task.isSelected)
                        
                        HStack(spacing: 6) {
                            Text(task.formattedTime)
                                .font(.system(size: 11))
                                .foregroundColor(.cyan.opacity(0.8))
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.2))
                            
                            Text(task.recurringDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    Spacer()
                    
                    // Delete
                    Button(action: { onRemove(task) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            }
        }
    }
}

#Preview {
    SmartOnboardingView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
