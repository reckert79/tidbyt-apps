//
//  OnboardingManager.swift
//  VisualMemory - Advanced Onboarding
//  Voice-enabled conversational setup with Claude
//

import SwiftUI
import Combine
import Speech
import AVFoundation

// MARK: - Onboarding State

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case morningRoutine
    case dailyHabits
    case workSchedule
    case chores
    case bills
    case custom
    case review
    case complete
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .morningRoutine: return "Morning Routine"
        case .dailyHabits: return "Daily Habits"
        case .workSchedule: return "Work & School"
        case .chores: return "Chores & Errands"
        case .bills: return "Bills & Payments"
        case .custom: return "Custom Tasks"
        case .review: return "Review"
        case .complete: return "All Set!"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .morningRoutine: return "sunrise.fill"
        case .dailyHabits: return "heart.fill"
        case .workSchedule: return "briefcase.fill"
        case .chores: return "house.fill"
        case .bills: return "dollarsign.circle.fill"
        case .custom: return "plus.circle.fill"
        case .review: return "checkmark.circle.fill"
        case .complete: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .welcome: return .purple
        case .morningRoutine: return .orange
        case .dailyHabits: return .pink
        case .workSchedule: return .blue
        case .chores: return .green
        case .bills: return .yellow
        case .custom: return .cyan
        case .review: return .indigo
        case .complete: return .green
        }
    }
    
    var prompt: String {
        switch self {
        case .welcome:
            return "Welcome to VisualMemory! I'm going to help you set up your tasks. Let's start by talking about your morning routine."
        case .morningRoutine:
            return "What time do you usually wake up? And do you have any morning habits you'd like to track, like brushing teeth, taking vitamins, or making your bed?"
        case .dailyHabits:
            return "Do you have any daily habits you want to maintain? Things like exercise, meditation, reading, or drinking enough water?"
        case .workSchedule:
            return "Do you have work or school? What days and times? Any regular meetings or classes you need to remember?"
        case .chores:
            return "What about household chores? Things like taking out the trash, doing laundry, grocery shopping, or cleaning?"
        case .bills:
            return "Do you have any bills you need to pay regularly? Like rent, utilities, phone, subscriptions, or credit cards?"
        case .custom:
            return "Is there anything else you'd like me to help you track? Any other tasks or reminders?"
        case .review:
            return "Great! Here are the tasks I've created for you. Take a look and let me know if you'd like to make any changes."
        case .complete:
            return "You're all set! Your tasks have been added. Tap below to start using VisualMemory!"
        }
    }
}

// MARK: - Generated Task Model

struct OnboardingTask: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var time: String // "HH:mm" format
    var isRecurring: Bool
    var recurringDays: [String] // ["monday", "tuesday", ...] or ["monthly"]
    var dayOfMonth: Int? // For monthly tasks
    var priority: String // "low", "medium", "high"
    var category: OnboardingStep
    var isSelected: Bool = true // User can deselect tasks they don't want
    
    var recurringDescription: String {
        if recurringDays.contains("monthly") {
            if let day = dayOfMonth {
                return "Monthly on the \(day)\(daySuffix(day))"
            }
            return "Monthly"
        }
        
        let allDays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday"]
        let weekend = ["saturday", "sunday"]
        
        let sorted = recurringDays.sorted { d1, d2 in
            (allDays.firstIndex(of: d1.lowercased()) ?? 0) < (allDays.firstIndex(of: d2.lowercased()) ?? 0)
        }
        
        if Set(sorted.map { $0.lowercased() }) == Set(allDays) {
            return "Every day"
        } else if Set(sorted.map { $0.lowercased() }) == Set(weekdays) {
            return "Weekdays"
        } else if Set(sorted.map { $0.lowercased() }) == Set(weekend) {
            return "Weekends"
        } else if sorted.count == 1 {
            return "Every \(sorted[0].capitalized)"
        } else {
            return sorted.map { $0.prefix(3).capitalized }.joined(separator: ", ")
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let date = formatter.date(from: time) else { return time }
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Onboarding Manager

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    // State
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var currentTranscript = ""
    @Published var assistantMessage = ""
    @Published var generatedTasks: [OnboardingTask] = []
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var userName: String = ""
    @Published var wakeUpTime: String = "07:00"
    
    // Conversation history for context
    private var conversationHistory: [(step: OnboardingStep, userResponse: String, tasks: [OnboardingTask])] = []
    
    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Claude API - Use the SAME key as VoiceInputManager
    // Replace with your actual API key
    private let apiKey = "YOUR_ANTHROPIC_API_KEY_HERE"
    
    init() {
        assistantMessage = OnboardingStep.welcome.prompt
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else { return }
        
        currentStep = OnboardingStep.allCases[currentIndex + 1]
        assistantMessage = currentStep.prompt
        currentTranscript = ""
    }
    
    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        
        currentStep = OnboardingStep.allCases[currentIndex - 1]
        assistantMessage = currentStep.prompt
        currentTranscript = ""
    }
    
    func skipStep() {
        nextStep()
    }
    
    var progress: Double {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep) else { return 0 }
        return Double(currentIndex) / Double(OnboardingStep.allCases.count - 1)
    }
    
    var canGoBack: Bool {
        currentStep != .welcome && currentStep != .complete
    }
    
    var isQuestionStep: Bool {
        ![.welcome, .review, .complete].contains(currentStep)
    }
    
    // MARK: - Speech Recognition
    
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        // Request microphone permission
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        return speechStatus && micStatus
    }
    
    func startListening() async {
        guard !isListening else { return }
        
        // Check permissions
        guard await requestPermissions() else {
            errorMessage = "Please enable microphone and speech recognition in Settings"
            showError = true
            return
        }
        
        do {
            try startRecognition()
            isListening = true
        } catch {
            errorMessage = "Could not start listening: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        // Process the response if we have one
        if !currentTranscript.isEmpty {
            Task {
                await processUserResponse(currentTranscript)
            }
        }
    }
    
    private func startRecognition() throws {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "OnboardingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Add contextual strings for better recognition
        recognitionRequest.contextualStrings = [
            "brush teeth", "take vitamins", "make bed", "exercise", "meditation",
            "work", "school", "meeting", "class", "gym",
            "trash", "laundry", "groceries", "cleaning", "dishes",
            "rent", "utilities", "electric", "water", "phone", "internet",
            "every day", "everyday", "daily", "weekly", "monthly",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "morning", "afternoon", "evening", "night",
            "7 am", "8 am", "9 am", "6 pm", "7 pm"
        ]
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.currentTranscript = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.isListening = false
                }
            }
        }
    }
    
    // MARK: - Process Response with Claude
    
    func processUserResponse(_ response: String) async {
        guard !response.isEmpty else { return }
        
        isProcessing = true
        
        do {
            let tasks = try await parseResponseWithClaude(response, for: currentStep)
            
            // Add tasks to our list
            generatedTasks.append(contentsOf: tasks)
            
            // Store in history
            conversationHistory.append((step: currentStep, userResponse: response, tasks: tasks))
            
            // Provide feedback
            if tasks.isEmpty {
                assistantMessage = "Got it! Let's move on to the next section."
            } else {
                let taskNames = tasks.map { $0.title }.joined(separator: ", ")
                assistantMessage = "Great! I've added: \(taskNames). Ready for the next section?"
            }
            
        } catch {
            errorMessage = "Sorry, I had trouble understanding that. Could you try again?"
            showError = true
            assistantMessage = currentStep.prompt
        }
        
        isProcessing = false
        currentTranscript = ""
    }
    
    private func parseResponseWithClaude(_ response: String, for step: OnboardingStep) async throws -> [OnboardingTask] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let systemPrompt = buildSystemPrompt(for: step)
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1000,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": response]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "OnboardingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        return parseTasksFromJSON(text, category: step)
    }
    
    private func buildSystemPrompt(for step: OnboardingStep) -> String {
        let basePrompt = """
        You are a task parser for an onboarding flow. Extract tasks from the user's response.
        Current time context: Wake up time is \(wakeUpTime).
        
        The user is answering about: \(step.title)
        
        RULES:
        1. Extract ONLY tasks mentioned or implied by the user
        2. If user says "no", "none", "skip", or similar, return empty tasks array
        3. For daily tasks, set recurringDays to all 7 days
        4. For weekly tasks, set specific days mentioned
        5. For monthly tasks, set recurringDays to ["monthly"] and include dayOfMonth
        6. Use 24-hour format for times (e.g., "07:30", "18:00")
        7. Default priority is "low" unless user mentions urgent/important
        
        """
        
        let stepSpecific: String
        switch step {
        case .morningRoutine:
            stepSpecific = """
            CONTEXT: Morning routine tasks
            - Look for wake up time and morning habits
            - Common tasks: brush teeth, shower, make bed, breakfast, vitamins
            - Default time: 15-30 minutes after wake up time
            - These are typically DAILY tasks
            """
        case .dailyHabits:
            stepSpecific = """
            CONTEXT: Daily habits and wellness
            - Look for exercise, meditation, reading, hydration, etc.
            - Ask about preferred times if not specified
            - These are typically DAILY tasks
            """
        case .workSchedule:
            stepSpecific = """
            CONTEXT: Work or school schedule
            - Look for work hours, meetings, classes
            - These might be WEEKDAY only tasks
            - Include commute reminders if mentioned
            """
        case .chores:
            stepSpecific = """
            CONTEXT: Household chores
            - Look for trash, laundry, groceries, cleaning
            - Trash is often weekly (specific day)
            - Laundry might be weekly
            - Groceries might be weekly
            """
        case .bills:
            stepSpecific = """
            CONTEXT: Bill payments
            - Look for rent, utilities, phone, subscriptions
            - These are typically MONTHLY tasks
            - Extract the day of month if mentioned (e.g., "1st", "15th")
            - Default time for bills: 12:00 (noon)
            """
        case .custom:
            stepSpecific = """
            CONTEXT: Custom tasks
            - User may mention anything
            - Parse whatever they say into appropriate tasks
            """
        default:
            stepSpecific = ""
        }
        
        let jsonFormat = """
        
        Return ONLY a valid JSON array of tasks:
        [
            {
                "title": "Brush teeth",
                "time": "07:15",
                "isRecurring": true,
                "recurringDays": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
                "dayOfMonth": null,
                "priority": "low"
            }
        ]
        
        If no tasks found, return: []
        """
        
        return basePrompt + stepSpecific + jsonFormat
    }
    
    private func parseTasksFromJSON(_ jsonString: String, category: OnboardingStep) -> [OnboardingTask] {
        // Extract JSON from response (might have markdown or extra text)
        var cleanJSON = jsonString
        if let startIndex = jsonString.firstIndex(of: "["),
           let endIndex = jsonString.lastIndex(of: "]") {
            cleanJSON = String(jsonString[startIndex...endIndex])
        }
        
        guard let data = cleanJSON.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return jsonArray.compactMap { dict -> OnboardingTask? in
            guard let title = dict["title"] as? String,
                  let time = dict["time"] as? String else { return nil }
            
            let isRecurring = dict["isRecurring"] as? Bool ?? true
            let recurringDays = dict["recurringDays"] as? [String] ?? []
            let dayOfMonth = dict["dayOfMonth"] as? Int
            let priority = dict["priority"] as? String ?? "low"
            
            return OnboardingTask(
                title: title,
                time: time,
                isRecurring: isRecurring,
                recurringDays: recurringDays,
                dayOfMonth: dayOfMonth,
                priority: priority,
                category: category
            )
        }
    }
    
    // MARK: - Task Management
    
    func toggleTask(_ task: OnboardingTask) {
        if let index = generatedTasks.firstIndex(where: { $0.id == task.id }) {
            generatedTasks[index].isSelected.toggle()
        }
    }
    
    func removeTask(_ task: OnboardingTask) {
        generatedTasks.removeAll { $0.id == task.id }
    }
    
    func updateTask(_ task: OnboardingTask) {
        if let index = generatedTasks.firstIndex(where: { $0.id == task.id }) {
            generatedTasks[index] = task
        }
    }
    
    var selectedTasks: [OnboardingTask] {
        generatedTasks.filter { $0.isSelected }
    }
    
    var tasksByCategory: [OnboardingStep: [OnboardingTask]] {
        Dictionary(grouping: generatedTasks) { $0.category }
    }
    
    // MARK: - Create Real Tasks
    
    func createTasksInApp(dataManager: VisualMemoryDataManager, userManager: UserManager) {
        guard let currentUser = userManager.currentUser else { return }
        
        for task in selectedTasks {
            let calendar = Calendar.current
            let today = Date()
            
            // Calculate the deadline
            var deadline: Date
            
            // Parse time
            let timeComponents = task.time.split(separator: ":")
            let hour = Int(timeComponents[0]) ?? 9
            let minute = Int(timeComponents.count > 1 ? timeComponents[1] : "0") ?? 0
            
            if task.recurringDays.contains("monthly"), let dayOfMonth = task.dayOfMonth {
                // Monthly task
                var components = calendar.dateComponents([.year, .month], from: today)
                components.day = dayOfMonth
                components.hour = hour
                components.minute = minute
                deadline = calendar.date(from: components) ?? today
                
                if deadline <= today {
                    deadline = calendar.date(byAdding: .month, value: 1, to: deadline) ?? deadline
                }
            } else if task.isRecurring && !task.recurringDays.isEmpty {
                // Weekly/Daily recurring
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = hour
                components.minute = minute
                deadline = calendar.date(from: components) ?? tomorrow
            } else {
                // One-time task - set for tomorrow
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = hour
                components.minute = minute
                deadline = calendar.date(from: components) ?? tomorrow
            }
            
            // Map priority
            let priorityLevel: PriorityLevel
            switch task.priority.lowercased() {
            case "high": priorityLevel = .high
            case "medium": priorityLevel = .medium
            default: priorityLevel = .low
            }
            
            // Convert [String] to Set<Weekday>
            var weekdaySet: Set<Weekday> = []
            if task.isRecurring && !task.recurringDays.contains("monthly") {
                for dayString in task.recurringDays {
                    if let weekday = Weekday(rawValue: dayString.lowercased()) {
                        weekdaySet.insert(weekday)
                    }
                }
            }
            
            // Create the VisualTask
            let visualTask = VisualTask(
                title: task.title,
                deadlineTime: deadline,
                isRecurring: task.isRecurring,
                recurringDays: weekdaySet,
                userId: currentUser.id,
                userName: currentUser.name,
                userAvatar: currentUser.avatarEmoji,
                userColor: currentUser.color,
                basePriority: priorityLevel
            )
            
            dataManager.addTask(visualTask)
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        currentStep = .welcome
        isListening = false
        isProcessing = false
        currentTranscript = ""
        assistantMessage = OnboardingStep.welcome.prompt
        generatedTasks = []
        conversationHistory = []
        errorMessage = nil
        showError = false
    }
}
