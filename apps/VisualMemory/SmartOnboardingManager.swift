//
//  SmartOnboardingManager.swift
//  VisualMemory
//  AI-powered smart onboarding that builds a complete daily routine
//

import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Smart Onboarding Step

enum SmartOnboardingStep: Int, CaseIterable {
    case welcome
    case wakeUpTime
    case leaveHouseTime
    case workOrSchool
    case returnHomeTime
    case bedtime
    case lifestyle  // kids, pets, exercise, etc.
    case generating // AI generating tasks
    case review
    case complete
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .wakeUpTime: return "Morning Start"
        case .leaveHouseTime: return "Leaving Home"
        case .workOrSchool: return "Your Day"
        case .returnHomeTime: return "Coming Home"
        case .bedtime: return "Bedtime"
        case .lifestyle: return "Your Lifestyle"
        case .generating: return "Building Routine"
        case .review: return "Your Routine"
        case .complete: return "All Set!"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .wakeUpTime: return "sunrise.fill"
        case .leaveHouseTime: return "door.left.hand.open"
        case .workOrSchool: return "briefcase.fill"
        case .returnHomeTime: return "house.fill"
        case .bedtime: return "moon.stars.fill"
        case .lifestyle: return "heart.fill"
        case .generating: return "sparkles"
        case .review: return "checklist"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .welcome: return .purple
        case .wakeUpTime: return .orange
        case .leaveHouseTime: return .blue
        case .workOrSchool: return .cyan
        case .returnHomeTime: return .green
        case .bedtime: return .indigo
        case .lifestyle: return .pink
        case .generating: return .purple
        case .review: return .green
        case .complete: return .green
        }
    }
    
    var question: String {
        switch self {
        case .welcome: return "I'm going to help you build your daily routine. I'll ask a few questions about your typical day, then create a personalized task list for you."
        case .wakeUpTime: return "What time do you usually wake up?"
        case .leaveHouseTime: return "What time do you need to leave the house? (Say 'I work from home' if you don't commute)"
        case .workOrSchool: return "Do you work, go to school, or stay at home? What's your typical day like?"
        case .returnHomeTime: return "What time do you usually get home? (Or when does your workday end if you're at home)"
        case .bedtime: return "What time do you usually go to bed?"
        case .lifestyle: return "Tell me about your lifestyle - do you have kids? Pets? Do you exercise? Any hobbies or regular activities?"
        case .generating: return "Great! I'm building your personalized routine..."
        case .review: return "Here's your complete daily routine! Review and adjust as needed."
        case .complete: return "You're all set! Your routine is ready to go."
        }
    }
}

// MARK: - User Profile Data

struct UserRoutineProfile {
    var wakeUpTime: String = ""          // "07:00"
    var leaveHouseTime: String?          // "08:30" or nil if WFH
    var worksFromHome: Bool = false
    var workType: String = ""            // "office job", "student", "stay at home parent"
    var returnHomeTime: String = ""      // "18:00"
    var bedtime: String = ""             // "22:30"
    var hasKids: Bool = false
    var numberOfKids: Int = 0
    var hasPets: Bool = false
    var petTypes: [String] = []          // ["dog", "cat"]
    var exercises: Bool = false
    var exerciseTime: String?            // "morning", "evening"
    var otherActivities: [String] = []   // ["meditation", "reading"]
}

// MARK: - Generated Task

struct GeneratedTask: Identifiable {
    let id = UUID()
    var title: String
    var time: String                     // "HH:mm"
    var isRecurring: Bool = true
    var recurringDays: [String] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    var priority: String = "low"
    var category: String                 // "morning", "work", "evening", "night"
    var isSelected: Bool = true
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return time
    }
    
    var recurringDescription: String {
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday"]
        let weekend = ["saturday", "sunday"]
        let allDays = weekdays + weekend
        
        let sortedDays = recurringDays.sorted { day1, day2 in
            allDays.firstIndex(of: day1.lowercased()) ?? 0 < allDays.firstIndex(of: day2.lowercased()) ?? 0
        }
        
        if Set(sortedDays.map { $0.lowercased() }) == Set(allDays) {
            return "Every day"
        } else if Set(sortedDays.map { $0.lowercased() }) == Set(weekdays) {
            return "Weekdays"
        } else if Set(sortedDays.map { $0.lowercased() }) == Set(weekend) {
            return "Weekends"
        } else {
            return sortedDays.prefix(3).map { $0.prefix(3).capitalized }.joined(separator: ", ")
        }
    }
}

// MARK: - Smart Onboarding Manager

@MainActor
class SmartOnboardingManager: ObservableObject {
    static let shared = SmartOnboardingManager()
    
    // Current state
    @Published var currentStep: SmartOnboardingStep = .welcome
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var transcript = ""
    @Published var generatedTasks: [GeneratedTask] = []
    @Published var showError = false
    @Published var errorMessage: String?
    
    // User profile being built
    @Published var userProfile = UserRoutineProfile()
    
    // Speech
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechManager = SpeechManager.shared
    
    // Claude API
    private let apiKey = "YOUR_API_KEY_HERE" // Replace with actual key
    
    // Check if API is configured
    var isAPIConfigured: Bool {
        apiKey != "YOUR_CLAUDE_API_KEY_HERE" && !apiKey.isEmpty
    }
    
    var progress: Double {
        Double(currentStep.rawValue) / Double(SmartOnboardingStep.allCases.count - 1)
    }
    
    var canGoBack: Bool {
        currentStep.rawValue > 0 && currentStep != .generating && currentStep != .complete
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        let allSteps = SmartOnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex < allSteps.count - 1 {
            currentStep = allSteps[currentIndex + 1]
            
            // If we're moving to generating step, start generating tasks
            if currentStep == .generating {
                Task {
                    await generateRoutine()
                }
            }
        }
    }
    
    func previousStep() {
        let allSteps = SmartOnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            currentStep = allSteps[currentIndex - 1]
        }
    }
    
    // MARK: - Voice Input
    
    func startListening() async {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            showError = true
            return
        }
        
        // Request permissions
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            showError = true
            return
        }
        
        do {
            try await startRecording()
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func startRecording() async throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    self?.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        
        // Process the transcript
        if !transcript.isEmpty {
            Task {
                await processResponse()
            }
        }
    }
    
    // MARK: - Process User Response
    
    private func processResponse() async {
        isProcessing = true
        
        // Extract information based on current step
        await extractInfoFromTranscript()
        
        isProcessing = false
        transcript = ""
        
        // Auto-advance to next step
        nextStep()
    }
    
    private func extractInfoFromTranscript() async {
        let response = transcript.lowercased()
        
        switch currentStep {
        case .wakeUpTime:
            userProfile.wakeUpTime = extractTime(from: response) ?? "07:00"
            
        case .leaveHouseTime:
            if response.contains("work from home") || response.contains("remote") || response.contains("don't leave") || response.contains("stay home") {
                userProfile.worksFromHome = true
                userProfile.leaveHouseTime = nil
            } else {
                userProfile.leaveHouseTime = extractTime(from: response)
            }
            
        case .workOrSchool:
            if response.contains("office") || response.contains("work") {
                userProfile.workType = "office"
            } else if response.contains("school") || response.contains("student") || response.contains("college") || response.contains("university") {
                userProfile.workType = "student"
            } else if response.contains("stay at home") || response.contains("parent") || response.contains("retired") {
                userProfile.workType = "home"
            } else {
                userProfile.workType = "general"
            }
            
        case .returnHomeTime:
            userProfile.returnHomeTime = extractTime(from: response) ?? "18:00"
            
        case .bedtime:
            userProfile.bedtime = extractTime(from: response) ?? "22:00"
            
        case .lifestyle:
            // Kids
            if response.contains("kid") || response.contains("child") || response.contains("son") || response.contains("daughter") {
                userProfile.hasKids = true
                // Try to extract number
                let numbers = ["one": 1, "two": 2, "three": 3, "four": 4, "1": 1, "2": 2, "3": 3, "4": 4]
                for (word, num) in numbers {
                    if response.contains(word) {
                        userProfile.numberOfKids = num
                        break
                    }
                }
                if userProfile.numberOfKids == 0 {
                    userProfile.numberOfKids = 1
                }
            }
            
            // Pets
            if response.contains("dog") {
                userProfile.hasPets = true
                userProfile.petTypes.append("dog")
            }
            if response.contains("cat") {
                userProfile.hasPets = true
                userProfile.petTypes.append("cat")
            }
            if response.contains("pet") && !userProfile.hasPets {
                userProfile.hasPets = true
            }
            
            // Exercise
            if response.contains("exercise") || response.contains("gym") || response.contains("workout") || response.contains("run") || response.contains("yoga") {
                userProfile.exercises = true
                if response.contains("morning") {
                    userProfile.exerciseTime = "morning"
                } else if response.contains("evening") || response.contains("night") || response.contains("after work") {
                    userProfile.exerciseTime = "evening"
                }
            }
            
            // Other activities
            if response.contains("meditat") {
                userProfile.otherActivities.append("meditation")
            }
            if response.contains("read") {
                userProfile.otherActivities.append("reading")
            }
            if response.contains("journal") {
                userProfile.otherActivities.append("journaling")
            }
            
        default:
            break
        }
    }
    
    private func extractTime(from text: String) -> String? {
        // Try to find time patterns
        let patterns = [
            #"(\d{1,2}):(\d{2})\s*(am|pm|a\.m\.|p\.m\.)"#,
            #"(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)"#,
            #"(\d{1,2}):(\d{2})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let matchString = String(text[Range(match.range, in: text)!])
                    return convertToMilitaryTime(matchString)
                }
            }
        }
        
        // Check for words
        let wordTimes: [String: String] = [
            "five": "05:00", "six": "06:00", "seven": "07:00", "eight": "08:00",
            "nine": "09:00", "ten": "10:00", "eleven": "11:00", "twelve": "12:00",
            "noon": "12:00", "midnight": "00:00"
        ]
        
        for (word, time) in wordTimes {
            if text.contains(word) {
                // Check for am/pm context
                if text.contains("pm") || text.contains("p.m.") || text.contains("evening") || text.contains("night") {
                    if let hour = Int(time.prefix(2)), hour < 12 {
                        return String(format: "%02d:00", hour + 12)
                    }
                }
                return time
            }
        }
        
        return nil
    }
    
    private func convertToMilitaryTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        let formats = ["h:mm a", "h a", "H:mm", "h:mma", "ha"]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: timeString) {
                formatter.dateFormat = "HH:mm"
                return formatter.string(from: date)
            }
        }
        
        return timeString
    }
    
    // MARK: - Generate Routine with AI
    
    private func generateRoutine() async {
        isProcessing = true
        
        // If API is configured, try Claude first
        if isAPIConfigured {
            let prompt = buildRoutinePrompt()
            
            do {
                let tasks = try await callClaudeForRoutine(prompt: prompt)
                generatedTasks = tasks
                isProcessing = false
                nextStep() // Move to review
                return
            } catch {
                print("⚠️ Claude API failed, using fallback: \(error)")
                // Fall through to basic routine
            }
        }
        
        // Use smart fallback routine generator
        generatedTasks = generateBasicRoutine()
        
        isProcessing = false
        nextStep() // Move to review
    }
    
    private func buildRoutinePrompt() -> String {
        var context = """
        Generate a complete daily routine for someone with the following schedule:
        
        Wake up time: \(userProfile.wakeUpTime)
        """
        
        if let leaveTime = userProfile.leaveHouseTime {
            context += "\nLeave house time: \(leaveTime)"
        } else {
            context += "\nWorks from home: Yes"
        }
        
        context += """
        
        Work type: \(userProfile.workType)
        Return home time: \(userProfile.returnHomeTime)
        Bedtime: \(userProfile.bedtime)
        """
        
        if userProfile.hasKids {
            context += "\nHas \(userProfile.numberOfKids) kid(s)"
        }
        
        if userProfile.hasPets {
            context += "\nHas pets: \(userProfile.petTypes.joined(separator: ", "))"
        }
        
        if userProfile.exercises {
            context += "\nExercises: \(userProfile.exerciseTime ?? "sometime during the day")"
        }
        
        if !userProfile.otherActivities.isEmpty {
            context += "\nActivities: \(userProfile.otherActivities.joined(separator: ", "))"
        }
        
        context += """
        
        
        Generate a realistic daily routine with tasks spaced appropriately. Include:
        - Morning hygiene (brush teeth, shower, skincare)
        - Getting dressed
        - Breakfast
        - Any kid/pet related tasks
        - Commute or work start
        - Lunch
        - Work end / commute home
        - Evening routine (dinner, relaxation)
        - Night routine (prepare for bed)
        
        Return ONLY a JSON array with tasks in this exact format:
        [
            {"title": "Task name", "time": "HH:MM", "priority": "low/medium/high", "category": "morning/afternoon/evening/night", "days": ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]}
        ]
        
        Make times realistic and properly spaced. Use 24-hour format for time.
        """
        
        return context
    }
    
    private func callClaudeForRoutine(prompt: String) async throws -> [GeneratedTask] {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? [[String: Any]],
           let textBlock = content.first,
           let text = textBlock["text"] as? String {
            return parseTasksFromJSON(text)
        }
        
        throw NSError(domain: "API", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
    
    private func parseTasksFromJSON(_ text: String) -> [GeneratedTask] {
        // Extract JSON array from response
        var jsonString = text
        
        if let startIndex = text.firstIndex(of: "["),
           let endIndex = text.lastIndex(of: "]") {
            jsonString = String(text[startIndex...endIndex])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return generateBasicRoutine()
        }
        
        return jsonArray.compactMap { dict -> GeneratedTask? in
            guard let title = dict["title"] as? String,
                  let time = dict["time"] as? String else { return nil }
            
            let priority = dict["priority"] as? String ?? "low"
            let category = dict["category"] as? String ?? "morning"
            let days = dict["days"] as? [String] ?? ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            
            return GeneratedTask(
                title: title,
                time: time,
                isRecurring: true,
                recurringDays: days,
                priority: priority,
                category: category
            )
        }.sorted { $0.time < $1.time }
    }
    
    // MARK: - Fallback Basic Routine Generator
    
    private func generateBasicRoutine() -> [GeneratedTask] {
        var tasks: [GeneratedTask] = []
        
        let wakeHour = Int(userProfile.wakeUpTime.prefix(2)) ?? 7
        let wakeMinute = Int(userProfile.wakeUpTime.suffix(2)) ?? 0
        
        // Morning routine
        tasks.append(GeneratedTask(title: "Wake up", time: userProfile.wakeUpTime, category: "morning"))
        tasks.append(GeneratedTask(title: "Brush teeth", time: formatTime(hour: wakeHour, minute: wakeMinute + 5), category: "morning"))
        tasks.append(GeneratedTask(title: "Shower", time: formatTime(hour: wakeHour, minute: wakeMinute + 15), category: "morning"))
        tasks.append(GeneratedTask(title: "Get dressed", time: formatTime(hour: wakeHour, minute: wakeMinute + 30), category: "morning"))
        tasks.append(GeneratedTask(title: "Breakfast", time: formatTime(hour: wakeHour, minute: wakeMinute + 45), category: "morning"))
        
        // Pet tasks
        if userProfile.hasPets {
            if userProfile.petTypes.contains("dog") {
                tasks.append(GeneratedTask(title: "Walk the dog", time: formatTime(hour: wakeHour, minute: wakeMinute + 60), category: "morning"))
                tasks.append(GeneratedTask(title: "Feed the dog", time: formatTime(hour: wakeHour, minute: wakeMinute + 75), category: "morning"))
            }
            if userProfile.petTypes.contains("cat") {
                tasks.append(GeneratedTask(title: "Feed the cat", time: formatTime(hour: wakeHour, minute: wakeMinute + 50), category: "morning"))
            }
        }
        
        // Kids tasks
        if userProfile.hasKids {
            tasks.append(GeneratedTask(title: "Wake up kids", time: formatTime(hour: wakeHour, minute: wakeMinute + 30), priority: "high", category: "morning"))
            tasks.append(GeneratedTask(title: "Make kids' breakfast", time: formatTime(hour: wakeHour, minute: wakeMinute + 45), category: "morning"))
            tasks.append(GeneratedTask(title: "Pack lunches", time: formatTime(hour: wakeHour, minute: wakeMinute + 60), category: "morning"))
        }
        
        // Leave house
        if let leaveTime = userProfile.leaveHouseTime {
            tasks.append(GeneratedTask(title: "Leave for work", time: leaveTime, priority: "high", category: "morning"))
        }
        
        // Lunch
        tasks.append(GeneratedTask(title: "Lunch", time: "12:00", category: "afternoon"))
        
        // Exercise
        if userProfile.exercises {
            if userProfile.exerciseTime == "morning" {
                tasks.append(GeneratedTask(title: "Exercise", time: formatTime(hour: wakeHour, minute: wakeMinute + 20), priority: "medium", category: "morning"))
            } else {
                let returnHour = Int(userProfile.returnHomeTime.prefix(2)) ?? 18
                tasks.append(GeneratedTask(title: "Exercise", time: formatTime(hour: returnHour, minute: 30), priority: "medium", category: "evening"))
            }
        }
        
        // Evening routine
        let returnHour = Int(userProfile.returnHomeTime.prefix(2)) ?? 18
        let returnMinute = Int(userProfile.returnHomeTime.suffix(2)) ?? 0
        
        if !userProfile.worksFromHome {
            tasks.append(GeneratedTask(title: "Arrive home", time: userProfile.returnHomeTime, category: "evening"))
        } else {
            tasks.append(GeneratedTask(title: "End work day", time: userProfile.returnHomeTime, category: "evening"))
        }
        
        tasks.append(GeneratedTask(title: "Dinner", time: formatTime(hour: returnHour, minute: returnMinute + 60), category: "evening"))
        
        // Evening pet tasks
        if userProfile.petTypes.contains("dog") {
            tasks.append(GeneratedTask(title: "Evening dog walk", time: formatTime(hour: returnHour, minute: returnMinute + 120), category: "evening"))
        }
        
        // Kids bedtime
        if userProfile.hasKids {
            let bedHour = Int(userProfile.bedtime.prefix(2)) ?? 22
            tasks.append(GeneratedTask(title: "Kids bedtime routine", time: formatTime(hour: bedHour - 2, minute: 0), priority: "high", category: "evening"))
        }
        
        // Other activities
        if userProfile.otherActivities.contains("meditation") {
            tasks.append(GeneratedTask(title: "Meditation", time: formatTime(hour: Int(userProfile.bedtime.prefix(2)) ?? 22, minute: -30), category: "night"))
        }
        if userProfile.otherActivities.contains("reading") {
            tasks.append(GeneratedTask(title: "Reading", time: formatTime(hour: Int(userProfile.bedtime.prefix(2)) ?? 22, minute: -20), category: "night"))
        }
        
        // Night routine
        let bedHour = Int(userProfile.bedtime.prefix(2)) ?? 22
        let bedMinute = Int(userProfile.bedtime.suffix(2)) ?? 0
        
        tasks.append(GeneratedTask(title: "Brush teeth", time: formatTime(hour: bedHour, minute: bedMinute - 15), category: "night"))
        tasks.append(GeneratedTask(title: "Go to bed", time: userProfile.bedtime, category: "night"))
        
        return tasks.sorted { $0.time < $1.time }
    }
    
    private func formatTime(hour: Int, minute: Int) -> String {
        var h = hour
        var m = minute
        
        while m >= 60 {
            m -= 60
            h += 1
        }
        while m < 0 {
            m += 60
            h -= 1
        }
        
        h = h % 24
        if h < 0 { h += 24 }
        
        return String(format: "%02d:%02d", h, m)
    }
    
    // MARK: - Task Management
    
    func toggleTask(_ task: GeneratedTask) {
        if let index = generatedTasks.firstIndex(where: { $0.id == task.id }) {
            generatedTasks[index].isSelected.toggle()
        }
    }
    
    func removeTask(_ task: GeneratedTask) {
        generatedTasks.removeAll { $0.id == task.id }
    }
    
    var selectedTasks: [GeneratedTask] {
        generatedTasks.filter { $0.isSelected }
    }
    
    // MARK: - Create Tasks in App
    
    func createTasksInApp(dataManager: VisualMemoryDataManager, userManager: UserManager) {
        guard let user = userManager.currentUser else { return }
        
        for task in selectedTasks {
            // Convert time string to Date
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            var deadlineDate = Date()
            if let time = formatter.date(from: task.time) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                deadlineDate = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                              minute: timeComponents.minute ?? 0,
                                              second: 0, of: Date()) ?? Date()
            }
            
            // Convert recurringDays to Weekday set
            let weekdaySet: Set<Weekday> = Set(task.recurringDays.compactMap { dayString -> Weekday? in
                switch dayString.lowercased() {
                case "monday": return .monday
                case "tuesday": return .tuesday
                case "wednesday": return .wednesday
                case "thursday": return .thursday
                case "friday": return .friday
                case "saturday": return .saturday
                case "sunday": return .sunday
                default: return nil
                }
            })
            
            // Convert priority
            let priority: PriorityLevel
            switch task.priority.lowercased() {
            case "high": priority = .high
            case "medium": priority = .medium
            default: priority = .low
            }
            
            let visualTask = VisualTask(
                title: task.title,
                deadlineTime: deadlineDate,
                isRecurring: task.isRecurring,
                recurringDays: weekdaySet,
                userId: user.id,
                userName: user.name,
                userAvatar: user.avatarEmoji,
                userColor: user.color,
                basePriority: priority
            )
            
            dataManager.addTask(visualTask)
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        currentStep = .welcome
        isListening = false
        isProcessing = false
        transcript = ""
        generatedTasks = []
        userProfile = UserRoutineProfile()
    }
}
