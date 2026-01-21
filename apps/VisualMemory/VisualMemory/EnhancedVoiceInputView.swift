//
//  EnhancedVoiceInputView.swift
//  VisualMemory
//  Voice input - UPDATED VERSION
//

import SwiftUI
import Speech
import AVFoundation

// MARK: - Conversation State

enum EnhancedConversationState {
    case greeting
    case listening
    case processing
    case confirming
    case askingWeekend
    case reviewing
    case complete
    case error
}

// MARK: - Enhanced Voice Input View

struct EnhancedVoiceInputView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject private var speechManager = SpeechManager.shared
    @ObservedObject private var voiceManager = VoiceInputManager.shared
    
    @State private var conversationState: EnhancedConversationState = .greeting
    @State private var pendingTasks: [PendingTask] = []
    @State private var currentTaskForWeekendQuestion: PendingTask?
    @State private var showingReview = false
    @State private var assistantMessage = ""
    @State private var showWaveform = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.14),
                    Color(red: 0.10, green: 0.08, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if showingReview {
                TaskReviewView(
                    tasks: $pendingTasks,
                    onConfirm: confirmAllTasks,
                    onAddMore: addMoreTasks,
                    onCancel: cancelAll
                )
                .transition(.move(edge: .trailing))
            } else {
                mainLayout
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startConversation()
        }
        .onDisappear {
            speechManager.stop()
            voiceManager.reset()
        }
    }
    
    // MARK: - Main Layout
    
    var mainLayout: some View {
        VStack(spacing: 0) {
            // HEADER
            headerBar
                .padding(.top, 16)
            
            // TASK LIST (at top, if tasks exist)
            if !pendingTasks.isEmpty {
                taskListArea
                    .padding(.top, 16)
            }
            
            Spacer()
            
            // CENTER: MIC BUTTON
            micButtonArea
            
            // "TRY SAYING" HINTS (below mic)
            if pendingTasks.isEmpty && conversationState != .processing && conversationState != .askingWeekend {
                trySayingHints
                    .padding(.top, 20)
            }
            
            Spacer()
            
            // BOTTOM: DONE BUTTON
            bottomArea
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header Bar
    
    var headerBar: some View {
        HStack {
            Button(action: cancelAll) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Add Tasks")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                if pendingTasks.count > 0 {
                    Text("\(pendingTasks.count) task\(pendingTasks.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
            }
            
            Spacer()
            
            if pendingTasks.count > 0 {
                Button(action: { showingReview = true }) {
                    Text("Review")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Task List Area (TOP)
    
    var taskListArea: some View {
        VStack(spacing: 10) {
            HStack {
                Text("YOUR TASKS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    .tracking(1)
                
                Spacer()
                
                Text("\(sortedPendingTasks.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.3)))
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(Array(sortedPendingTasks.enumerated()), id: \.element.id) { index, task in
                    HStack(spacing: 12) {
                        // Number in circle
                        ZStack {
                            Circle()
                                .fill(task.priority.color)
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // Task details
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan)
                                Text(task.formattedTime)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.cyan)
                                
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text(task.isRecurring ? task.scheduleDescription : "One-time")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                        
                        // Checkmark
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
    
    var sortedPendingTasks: [PendingTask] {
        pendingTasks.sorted { $0.deadline < $1.deadline }
    }
    
    // MARK: - Mic Button Area (CENTER)
    
    var micButtonArea: some View {
        VStack(spacing: 16) {
            // Processing state
            if conversationState == .processing {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.5)
                    Text("Processing...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            // Weekend question
            else if conversationState == .askingWeekend {
                VStack(spacing: 16) {
                    Text(assistantMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    HStack(spacing: 12) {
                        Button(action: { answerWeekendQuestion(includeWeekends: false) }) {
                            Text("Weekdays only")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.blue.opacity(0.4)))
                        }
                        
                        Button(action: { answerWeekendQuestion(includeWeekends: true) }) {
                            Text("Include weekends")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                }
            }
            // Error state
            else if conversationState == .error {
                VStack(spacing: 12) {
                    Text(assistantMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: retryAfterError) {
                        Text("Try Again")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.purple))
                    }
                }
            }
            // Normal mic button
            else {
                Button(action: micTapped) {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.6), .pink.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(voiceManager.isListening ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voiceManager.isListening)
                        
                        // Inner circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: voiceManager.isListening ? [.red, .red.opacity(0.8)] : [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .shadow(color: voiceManager.isListening ? .red.opacity(0.5) : .purple.opacity(0.5), radius: 15)
                        
                        // Icon
                        Image(systemName: voiceManager.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }
                
                // Label under mic
                Text(voiceManager.isListening ? "Tap when done" : (pendingTasks.isEmpty ? "Tap to start" : "Tap to add more"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                
                // Transcribed text
                if voiceManager.isListening && !voiceManager.transcribedText.isEmpty {
                    Text("\"\(voiceManager.transcribedText)\"")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        .padding(.horizontal, 30)
                }
            }
        }
    }
    
    func micTapped() {
        if voiceManager.isListening {
            stopAndProcess()
        } else {
            startListening()
        }
    }
    
    // MARK: - Try Saying Hints
    
    var trySayingHints: some View {
        VStack(spacing: 6) {
            Text("Try saying:")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Text("\"Brush teeth at 7 AM every day\"")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Bottom Area
    
    var bottomArea: some View {
        VStack(spacing: 12) {
            if !pendingTasks.isEmpty && !voiceManager.isListening && conversationState != .processing && conversationState != .askingWeekend {
                Button(action: { showingReview = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done - Review \(pendingTasks.count) Task\(pendingTasks.count == 1 ? "" : "s")")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.green)
                            .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    
    func startConversation() {
        conversationState = .greeting
        showWaveform = true
        speechManager.speak("Let me know what you have to do and when.") {
            self.startListening()
        }
    }
    
    func startListening() {
        conversationState = .listening
        Task {
            await voiceManager.startListening()
        }
    }
    
    func stopAndProcess() {
        voiceManager.stopListening()
        conversationState = .processing
        
        guard !voiceManager.transcribedText.isEmpty else {
            handleError("I didn't hear anything.")
            return
        }
        
        Task {
            await voiceManager.processTranscription()
            
            if let parsedTask = voiceManager.parsedTask,
               let taskTitle = parsedTask.title {
                await MainActor.run {
                    let deadline = calculateDeadline(from: parsedTask)
                    
                    let pending = PendingTask(
                        title: taskTitle,
                        deadline: deadline,
                        isRecurring: parsedTask.isRecurring ?? false,
                        includeWeekdays: parsedTask.recurringDays?.contains {
                            ["monday", "tuesday", "wednesday", "thursday", "friday"].contains($0.lowercased())
                        } ?? false,
                        includeWeekends: parsedTask.recurringDays?.contains {
                            ["saturday", "sunday"].contains($0.lowercased())
                        } ?? false,
                        priority: PriorityLevel(rawValue: priorityValue(parsedTask.priority)) ?? .low
                    )
                    
                    pendingTasks.append(pending)
                    
                    if pending.isRecurring && pending.includeWeekdays && !pending.includeWeekends {
                        currentTaskForWeekendQuestion = pending
                        askWeekendQuestion(for: pending)
                    } else {
                        taskAdded()
                    }
                }
            } else {
                await MainActor.run {
                    handleError("I couldn't understand that. Try again.")
                }
            }
        }
    }
    
    func calculateDeadline(from taskData: ParsedTaskData) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        
        if let timeStr = taskData.dueTime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            if let time = timeFormatter.date(from: timeStr) {
                let tc = calendar.dateComponents([.hour, .minute], from: time)
                components.hour = tc.hour
                components.minute = tc.minute
            } else {
                timeFormatter.dateFormat = "h:mm a"
                if let time = timeFormatter.date(from: timeStr) {
                    let tc = calendar.dateComponents([.hour, .minute], from: time)
                    components.hour = tc.hour
                    components.minute = tc.minute
                } else {
                    components.hour = 9
                    components.minute = 0
                }
            }
        } else {
            components.hour = 9
            components.minute = 0
        }
        
        if let date = calendar.date(from: components) {
            return date <= Date() ? calendar.date(byAdding: .day, value: 1, to: date) ?? date : date
        }
        return Date()
    }
    
    func priorityValue(_ priority: String?) -> Int {
        switch priority?.lowercased() {
        case "high": return 3
        case "medium": return 2
        default: return 1
        }
    }
    
    func askWeekendQuestion(for task: PendingTask) {
        conversationState = .askingWeekend
        assistantMessage = "Should '\(task.title)' apply to weekends too?"
        speechManager.speak("Include weekends?")
    }
    
    func answerWeekendQuestion(includeWeekends: Bool) {
        if let idx = pendingTasks.firstIndex(where: { $0.id == currentTaskForWeekendQuestion?.id }) {
            pendingTasks[idx].includeWeekends = includeWeekends
        }
        currentTaskForWeekendQuestion = nil
        speechManager.speak(includeWeekends ? "Weekends included." : "Weekdays only.")
        taskAdded()
    }
    
    func taskAdded() {
        conversationState = .confirming
        speechManager.speak("Added.")
        voiceManager.reset()
    }
    
    func handleError(_ message: String) {
        conversationState = .error
        assistantMessage = message
        speechManager.speak("Try again.")
    }
    
    func retryAfterError() {
        voiceManager.reset()
        startListening()
    }
    
    func addMoreTasks() {
        showingReview = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startListening()
        }
    }
    
    func confirmAllTasks() {
        guard let user = userManager.currentUser else { return }
        
        for pending in pendingTasks where pending.isSelected {
            let task = VisualTask(
                title: pending.title,
                deadlineTime: pending.deadline,
                isRecurring: pending.isRecurring,
                recurringDays: pending.recurringDays,
                userId: user.id,
                userName: user.name,
                userAvatar: user.avatarEmoji,
                userColor: user.color,
                basePriority: pending.priority
            )
            dataManager.addTask(task)
        }
        
        let count = pendingTasks.filter { $0.isSelected }.count
        speechManager.speak("\(count) task\(count == 1 ? "" : "s") added.")
        dismiss()
    }
    
    func cancelAll() {
        speechManager.stop()
        voiceManager.reset()
        dismiss()
    }
}

#Preview {
    EnhancedVoiceInputView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
