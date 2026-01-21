//
//  OnboardingFlowView.swift
//  VisualMemory - Advanced Onboarding
//  Beautiful voice-enabled onboarding experience
//

import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.dismiss) var dismiss
    
    var onComplete: (() -> Void)? = nil
    
    @State private var showSkipConfirmation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.12, green: 0.08, blue: 0.24),
                    Color(red: 0.06, green: 0.04, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background circles
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(onboardingManager.currentStep.color.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: -100, y: -200)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width - 150, y: geometry.size.height - 300)
                }
            }
            
            VStack(spacing: 0) {
                // Header with progress
                OnboardingHeader(
                    step: onboardingManager.currentStep,
                    progress: onboardingManager.progress,
                    canGoBack: onboardingManager.canGoBack,
                    onBack: { onboardingManager.previousStep() },
                    onSkip: { showSkipConfirmation = true }
                )
                
                // Main content
                TabView(selection: $onboardingManager.currentStep) {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        stepView(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: onboardingManager.currentStep)
                
                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Skip Onboarding?", isPresented: $showSkipConfirmation) {
            Button("Continue Setup", role: .cancel) { }
            Button("Skip", role: .destructive) {
                onComplete?()
                dismiss()
            }
        } message: {
            Text("You can always set up tasks later from the main screen.")
        }
        .alert("Error", isPresented: $onboardingManager.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(onboardingManager.errorMessage ?? "Something went wrong")
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .review:
            ReviewStepView(tasks: onboardingManager.generatedTasks)
        case .complete:
            CompleteStepView(taskCount: onboardingManager.selectedTasks.count)
        default:
            QuestionStepView(
                step: step,
                assistantMessage: onboardingManager.assistantMessage,
                transcript: onboardingManager.currentTranscript,
                isListening: onboardingManager.isListening,
                isProcessing: onboardingManager.isProcessing
            )
        }
    }
    
    // MARK: - Bottom Buttons
    
    @ViewBuilder
    var bottomButtons: some View {
        switch onboardingManager.currentStep {
        case .welcome:
            Button(action: { onboardingManager.nextStep() }) {
                HStack(spacing: 12) {
                    Text("Let's Get Started")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
            }
            
        case .review:
            VStack(spacing: 12) {
                Button(action: {
                    onboardingManager.createTasksInApp(dataManager: dataManager, userManager: userManager)
                    onboardingManager.nextStep()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Add \(onboardingManager.selectedTasks.count) Tasks")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                }
                
                if onboardingManager.generatedTasks.isEmpty {
                    Button(action: { onboardingManager.previousStep() }) {
                        Text("Go Back & Add Tasks")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
        case .complete:
            Button(action: {
                onComplete?()
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                    Text("Start Using VisualMemory")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
            }
            
        default:
            // Question step - just Skip and Continue buttons (mic is now centered)
            HStack(spacing: 16) {
                Button(action: { onboardingManager.skipStep() }) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                Button(action: { onboardingManager.nextStep() }) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(onboardingManager.currentStep.color)
                        )
                }
            }
        }
    }
}

// MARK: - Onboarding Header

struct OnboardingHeader: View {
    let step: OnboardingStep
    let progress: Double
    let canGoBack: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                if canGoBack {
                    Button(action: onBack) {
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
                
                Text(step.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [step.color, step.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text("Welcome to VisualMemory")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Let's set up your tasks together.\nI'll ask a few questions to understand your routine and automatically create tasks for you.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 30)
            
            // Features list
            VStack(spacing: 16) {
                FeatureRow(icon: "mic.fill", text: "Voice-powered setup", color: .cyan)
                FeatureRow(icon: "brain.head.profile", text: "AI understands your routine", color: .purple)
                FeatureRow(icon: "clock.fill", text: "Tasks created automatically", color: .orange)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                )
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - Question Step View

struct QuestionStepView: View {
    let step: OnboardingStep
    let assistantMessage: String
    let transcript: String
    let isListening: Bool
    let isProcessing: Bool
    @ObservedObject var onboardingManager = OnboardingManager.shared
    
    // Tasks for current category, sorted by time
    var tasksForCurrentStep: [OnboardingTask] {
        onboardingManager.generatedTasks
            .filter { $0.category == step }
            .sorted { $0.time < $1.time }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Step title
            HStack(spacing: 10) {
                Image(systemName: step.icon)
                    .font(.system(size: 20))
                    .foregroundColor(step.color)
                Text(step.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            // Task list (if tasks exist for this step)
            if !tasksForCurrentStep.isEmpty {
                taskListSection
            }
            
            Spacer()
            
            // MIC BUTTON (CENTERED)
            VStack(spacing: 12) {
                Button(action: {
                    if isListening {
                        onboardingManager.stopListening()
                    } else {
                        Task {
                            await onboardingManager.startListening()
                        }
                    }
                }) {
                    ZStack {
                        // Outer pulsing ring
                        if isListening {
                            Circle()
                                .stroke(step.color.opacity(0.4), lineWidth: 4)
                                .frame(width: 110, height: 110)
                                .scaleEffect(isListening ? 1.2 : 1.0)
                                .opacity(isListening ? 0 : 1)
                                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isListening)
                        }
                        
                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isListening ? [.red, .red.opacity(0.8)] : [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .shadow(color: isListening ? Color.red.opacity(0.5) : Color.purple.opacity(0.5), radius: 15, y: 6)
                        
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.3)
                        } else {
                            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isProcessing)
                
                // Status text under mic
                Text(isListening ? "Tap when done" : (isProcessing ? "Processing..." : "Tap to speak"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Transcript display
            if !transcript.isEmpty {
                Text("\"\(transcript)\"")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 20)
            }
            
            // Example hints (below mic)
            ExampleHints(step: step)
                .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Task List Section
    
    var taskListSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("TASKS ADDED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(step.color)
                    .tracking(1)
                
                Spacer()
                
                Text("\(tasksForCurrentStep.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(step.color.opacity(0.3)))
            }
            .padding(.horizontal, 24)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(tasksForCurrentStep.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 12) {
                            // Number badge
                            ZStack {
                                Circle()
                                    .fill(priorityColor(task.priority))
                                    .frame(width: 26, height: 26)
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Task details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 9))
                                        .foregroundColor(.cyan)
                                    Text(formatTime(task.time))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.cyan)
                                    
                                    if task.isRecurring {
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.3))
                                        Text(task.recurringDescription)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: min(CGFloat(tasksForCurrentStep.count) * 58, 175))
        }
    }
    
    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .yellow
        default: return .green
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

struct ExampleHints: View {
    let step: OnboardingStep
    
    var examples: [String] {
        switch step {
        case .morningRoutine:
            return ["\"I wake up at 7am\"", "\"Brush teeth and take vitamins\""]
        case .dailyHabits:
            return ["\"Exercise at 6pm\"", "\"Meditate every morning\""]
        case .workSchedule:
            return ["\"Work Monday to Friday\"", "\"Meeting at 2pm on Tuesdays\""]
        case .chores:
            return ["\"Trash goes out on Thursdays\"", "\"Laundry every Sunday\""]
        case .bills:
            return ["\"Rent on the 1st\"", "\"Electric bill on the 15th\""]
        case .custom:
            return ["\"Call mom every Sunday\"", "\"Water plants weekly\""]
        default:
            return []
        }
    }
    
    var body: some View {
        if !examples.isEmpty {
            VStack(spacing: 8) {
                Text("Try saying:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Text(example)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
    }
}

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Voice Input Button

struct VoiceInputButton: View {
    let isListening: Bool
    let isProcessing: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer ring when listening
                if isListening {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 3)
                        .frame(width: 90, height: 90)
                        .scaleEffect(isListening ? 1.2 : 1.0)
                        .opacity(isListening ? 0 : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isListening)
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isListening ? [color, color.opacity(0.8)] : [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: (isListening ? color : .purple).opacity(0.5), radius: 12, y: 6)
                
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isProcessing)
    }
}

// MARK: - Review Step View

struct ReviewStepView: View {
    let tasks: [OnboardingTask]
    @ObservedObject var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Review Your Tasks")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Tap to select or deselect tasks")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
            
            if tasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No tasks created yet")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Go back and tell me about your routine!")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(OnboardingStep.allCases.filter { step in
                            tasks.contains { $0.category == step }
                        }, id: \.self) { category in
                            CategorySection(
                                category: category,
                                tasks: tasks.filter { $0.category == category }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            
            Spacer()
        }
    }
}

struct CategorySection: View {
    let category: OnboardingStep
    let tasks: [OnboardingTask]
    @ObservedObject var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(category.color)
                
                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
            }
            .padding(.leading, 4)
            
            ForEach(tasks) { task in
                ReviewTaskRow(task: task)
            }
        }
    }
}

struct ReviewTaskRow: View {
    let task: OnboardingTask
    @ObservedObject var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        Button(action: {
            onboardingManager.toggleTask(task)
        }) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(task.isSelected ? task.category.color : Color.white.opacity(0.1))
                        .frame(width: 26, height: 26)
                    
                    if task.isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(task.isSelected ? .white : .white.opacity(0.4))
                        .strikethrough(!task.isSelected)
                    
                    HStack(spacing: 8) {
                        Text(task.formattedTime)
                            .font(.system(size: 12))
                        
                        if task.isRecurring {
                            Text("•")
                            Text(task.recurringDescription)
                                .font(.system(size: 12))
                        }
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(task.isSelected ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(task.isSelected ? task.category.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Complete Step View

struct CompleteStepView: View {
    let taskCount: Int
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Celebration animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                if taskCount > 0 {
                    Text("\(taskCount) tasks have been added to your schedule")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                } else {
                    Text("You can add tasks anytime from the main screen")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 30)
            
            // Stats
            if taskCount > 0 {
                HStack(spacing: 30) {
                    StatBubble(value: "\(taskCount)", label: "Tasks", color: .cyan)
                    StatBubble(value: "0", label: "Streak", color: .orange)
                    StatBubble(value: "1", label: "Level", color: .purple)
                }
                .padding(.top, 20)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(0.3)) {
                showConfetti = true
            }
        }
    }
}

struct StatBubble: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
