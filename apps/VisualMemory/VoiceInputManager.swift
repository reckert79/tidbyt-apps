//
//  VoiceInputManager.swift
//  VisualMemory - Conversational Voice Input
//  Uses Speech framework + Claude API for natural language parsing
//

import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Voice Input Manager
@MainActor
class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()
    
    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // State
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var originalTranscription = ""  // Store original request
    @Published var isProcessing = false
    @Published var conversationState: ConversationState = .idle
    @Published var parsedTask: ParsedTaskData?
    @Published var errorMessage: String?
    @Published var assistantMessage: String?
    @Published var debugLog: String = ""
    
    // Conversation context
    private var conversationHistory: [String] = []
    
    enum ConversationState {
        case idle
        case listening
        case processing
        case askingForTime
        case askingForDate
        case confirming
        case complete
        case error
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return false
        }
        
        // Request microphone permission
        let audioStatus = await AVAudioApplication.requestRecordPermission()
        
        guard audioStatus else {
            errorMessage = "Microphone access not authorized"
            return false
        }
        
        return true
    }
    
    // MARK: - Start Listening
    
    func startListening() async {
        // Check permissions first
        guard await requestPermissions() else { return }
        
        // Reset state (but preserve askingForTime if that's where we are)
        let preserveState = (conversationState == .askingForTime || conversationState == .askingForDate)
        transcribedText = ""
        errorMessage = nil
        if !preserveState {
            conversationState = .listening
        }
        isListening = true
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            conversationState = .error
            isListening = false
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            conversationState = .error
            isListening = false
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation  // Best for natural speech
        
        // CRITICAL: Help recognize day names and recurring phrases
        recognitionRequest.contextualStrings = [
            "every Monday", "every Tuesday", "every Wednesday",
            "every Thursday", "every Friday", "every Saturday", "every Sunday",
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
            "every day", "everyday", "daily", "every week", "weekly",
            "every weekday", "weekdays", "every weekend", "weekends",
            "every month", "monthly", "every year", "yearly",
            "every morning", "every evening", "every night",
            "recurring", "repeat", "repeating",
            "the 1st", "the 2nd", "the 3rd", "the 4th", "the 5th",
            "the 10th", "the 15th", "the 20th", "the 25th", "the 30th",
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
            "starting on", "beginning", "from",
            "7:30", "7:30 AM", "7:30 PM", "11:00", "11:00 AM",
            "morning", "afternoon", "evening", "noon"
        ]
        
        // Add punctuation if available (iOS 16+)
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        // Use SERVER-based recognition for better accuracy with temporal phrases
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // iOS 18 workaround variables - tracks dropped words
        var lastPartialResult = ""
        var accumulatedTranscription = ""
        
        // Start recognition task with iOS 18 workaround
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    
                    // iOS 18 WORKAROUND: Detect if words were dropped
                    // When there's a pause, iOS resets and loses previous words
                    if !lastPartialResult.isEmpty && newText.count < lastPartialResult.count - 3 {
                        // Words were dropped! Save the last good transcription
                        if !accumulatedTranscription.contains(lastPartialResult) {
                            accumulatedTranscription = lastPartialResult
                            print("🎤 Saved before reset: \(lastPartialResult)")
                        }
                    }
                    
                    lastPartialResult = newText
                    
                    // Combine: accumulated (has the dropped words) + current
                    if accumulatedTranscription.isEmpty {
                        self.transcribedText = newText
                    } else {
                        // Claude will clean up any duplicates
                        self.transcribedText = accumulatedTranscription + ". " + newText
                    }
                    
                    print("🎤 Full: \(self.transcribedText)")
                }
                
                if let error = error {
                    if (error as NSError).code != 216 {
                        print("Recognition error: \(error)")
                    }
                }
            }
        }
        
        // Configure audio input - larger buffer for better recognition
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
            conversationState = .error
            isListening = false
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        guard isListening else { return }
        
        let wasAskingForTime = (conversationState == .askingForTime || conversationState == .askingForDate)
        
        isListening = false
        
        // End the recognition request first to finalize transcription
        recognitionRequest?.endAudio()
        
        // Wait briefly for final transcription results
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                // Stop audio engine
                if audioEngine.isRunning {
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)
                }
                
                recognitionRequest = nil
                recognitionTask?.cancel()
                recognitionTask = nil
                
                // Deactivate audio session
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                
                print("🎤 Final: \(transcribedText)")
            }
            
            // Auto-process if we have text
            if !transcribedText.isEmpty {
                if wasAskingForTime {
                    await processFollowUp()
                } else {
                    await processTranscription()
                }
            }
        }
    }
    
    // MARK: - Process with Claude API
    
    func processTranscription() async {
        guard !transcribedText.isEmpty else {
            await MainActor.run {
                conversationState = .error
                errorMessage = "No speech detected. Please try again."
            }
            return
        }
        
        await MainActor.run {
            conversationState = .processing
            isProcessing = true
            debugLog = "Processing..."
            // Save original if this is the first message
            if originalTranscription.isEmpty {
                originalTranscription = transcribedText
            }
        }
        
        // Add to conversation history
        conversationHistory.append("User: \(transcribedText)")
        
        print("🔵 Processing: \(transcribedText)")
        
        // USE LOCAL PARSING FOR NOW (no API needed)
        await MainActor.run {
            debugLog = "Parsing locally..."
        }
        
        let localResult = parseLocally(transcribedText)
        
        await MainActor.run {
            // Never ask for time - always proceed to confirmation
            var cleanedTaskData = localResult.taskData
            if let originalTitle = cleanedTaskData?.title {
                cleanedTaskData?.title = cleanUpTitle(originalTitle)
            }
            
            // Default to noon if no time specified
            if cleanedTaskData?.dueTime == nil || cleanedTaskData?.dueTime?.isEmpty == true {
                cleanedTaskData?.dueTime = "12:00"
                cleanedTaskData?.timeSpecified = false
            }
            
            // FIX THE DATE - calculate correct date based on recurring pattern
            // If monthly but no dayOfMonth, try to extract from original text
            if cleanedTaskData?.recurringDays?.contains(where: { $0.lowercased() == "monthly" }) == true {
                if cleanedTaskData?.dayOfMonth == nil {
                    cleanedTaskData?.dayOfMonth = extractDayOfMonth(from: transcribedText)
                }
            }
            
            if let data = cleanedTaskData {
                cleanedTaskData?.dueDate = calculateCorrectDate(from: data)
            }
            
            parsedTask = cleanedTaskData
            
            let displayTitle = cleanedTaskData?.title ?? "task"
            let daysStr = formatRecurringDays(cleanedTaskData?.recurringDays)
            
            if cleanedTaskData?.isRecurring == true && !daysStr.isEmpty {
                assistantMessage = "\(displayTitle) - \(daysStr)"
            } else {
                assistantMessage = displayTitle
            }
            conversationState = .confirming
            debugLog = "Ready to confirm!"
            isProcessing = false
        }
    }
    
    // MARK: - Local Parsing (No API needed)
    
    func parseLocally(_ input: String) -> (needsTime: Bool, taskData: ParsedTaskData?) {
        let lowercased = input.lowercased()
        
        // Extract title (use the whole input as title for now)
        var title = input
        
        // Try to extract time
        var dueTime: String? = nil
        var timeSpecified = false
        var dueDate: String? = formattedToday()
        
        // Check for time patterns
        let timePatterns = [
            "at (\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?",
            "(\\d{1,2})\\s*(am|pm)",
            "(\\d{1,2}):(\\d{2})",
            "by (\\d{1,2})(?::(\\d{2}))?"
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
                
                if let hourRange = Range(match.range(at: 1), in: lowercased) {
                    var hour = Int(lowercased[hourRange]) ?? 12
                    var minute = 0
                    
                    if match.numberOfRanges > 2, let minRange = Range(match.range(at: 2), in: lowercased) {
                        minute = Int(lowercased[minRange]) ?? 0
                    }
                    
                    // Check for AM/PM or morning/evening keywords
                    if lowercased.contains("pm") || lowercased.contains("evening") || lowercased.contains("afternoon") {
                        if hour < 12 {
                            hour += 12
                        }
                    } else if lowercased.contains("am") || lowercased.contains("morning") {
                        if hour == 12 {
                            hour = 0
                        }
                        // Keep hour as-is for morning (7:00 morning = 07:00)
                    }
                    
                    dueTime = String(format: "%02d:%02d", hour, minute)
                    timeSpecified = true
                }
                break
            }
        }
        
        // If no time pattern matched but has time keywords
        if dueTime == nil {
            if lowercased.contains("morning") {
                dueTime = "09:00"
                timeSpecified = true
            } else if lowercased.contains("noon") {
                dueTime = "12:00"
                timeSpecified = true
            } else if lowercased.contains("afternoon") {
                dueTime = "15:00"
                timeSpecified = true
            } else if lowercased.contains("evening") {
                dueTime = "18:00"
                timeSpecified = true
            } else if lowercased.contains("night") {
                dueTime = "21:00"
                timeSpecified = true
            }
        }
        
        // Check for date keywords
        if lowercased.contains("tomorrow") {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDate = formatter.string(from: tomorrow)
        }
        
        // Check for priority
        var priority = "low"
        if lowercased.contains("high priority") || lowercased.contains("urgent") || lowercased.contains("important") {
            priority = "high"
        } else if lowercased.contains("medium priority") {
            priority = "medium"
        } else if lowercased.contains("low priority") || lowercased.contains("whenever") {
            priority = "low"
        }
        
        // Check for recurring
        var isRecurring = false
        var recurringDays: [String] = []
        var dayOfMonth: Int? = nil
        
        // Check for monthly recurring
        if lowercased.contains("every month") || lowercased.contains("monthly") {
            isRecurring = true
            recurringDays.append("monthly")
            // Try to extract day of month
            dayOfMonth = extractDayOfMonth(from: input)
        }
        
        // Check for weekly recurring
        let dayKeywords = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        if lowercased.contains("every") {
            isRecurring = true
            for day in dayKeywords {
                if lowercased.contains(day) {
                    recurringDays.append(day)
                }
            }
            
            // Check for "every weekday"
            if lowercased.contains("weekday") {
                recurringDays = ["monday", "tuesday", "wednesday", "thursday", "friday"]
            }
            
            // Check for "every weekend"
            if lowercased.contains("weekend") {
                recurringDays = ["saturday", "sunday"]
            }
            
            // Check for "every day", "everyday", or "daily"
            if lowercased.contains("every day") || lowercased.contains("everyday") || lowercased.contains("daily") {
                recurringDays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            }
        }
        
        // Clean up title - remove time/date phrases
        let removePatterns = ["at \\d+", "\\d+\\s*(am|pm)", "tomorrow", "today", "every \\w+", "high priority", "low priority"]
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(in: title, range: NSRange(title.startIndex..., in: title), withTemplate: "")
            }
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = input }
        
        // If no time found, ask for it
        if dueTime == nil {
            return (needsTime: true, taskData: ParsedTaskData(
                title: title,
                dueDate: dueDate,
                dueTime: nil,
                timeSpecified: false,
                dayOfMonth: dayOfMonth,
                priority: priority,
                assignee: nil,
                isRecurring: isRecurring,
                recurringDays: recurringDays.isEmpty ? nil : recurringDays,
                voiceAlerts: false
            ))
        }
        
        return (needsTime: false, taskData: ParsedTaskData(
            title: title,
            dueDate: dueDate,
            dueTime: dueTime,
            timeSpecified: true,
            dayOfMonth: dayOfMonth,
            priority: priority,
            assignee: nil,
            isRecurring: isRecurring,
            recurringDays: recurringDays.isEmpty ? nil : recurringDays,
            voiceAlerts: false
        ))
    }
    
    // MARK: - Claude API Call
    
    func callClaudeAPI(userInput: String) async throws -> ClaudeTaskResponse {
        // NOTE: Replace with your actual Claude API key
        let apiKey = "YOUR_CLAUDE_API_KEY_HERE"
        
        // Check if API key has been set
        if apiKey == "YOUR_CLAUDE_API_KEY_HERE" || apiKey.isEmpty {
            throw VoiceInputError.noAPIKey
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw VoiceInputError.invalidURL
        }
        
        let systemPrompt = """
        You are a task parser that handles MESSY speech recognition output.
        
        TODAY: \(formattedToday()) (\(currentDayOfWeek()))
        TOMORROW: \(tomorrowDate())
        CURRENT MONTH: \(currentMonth())
        CURRENT YEAR: \(currentYear())
        
        The user said: "\(transcribedText)"
        
        STEP 1 - EXTRACT SHORT TITLE (1-3 words max):
        - "Pay the HVAC bill every month" → "HVAC bill"
        - "Take the trash out Tuesday" → "Trash"
        - "Brush your teeth everyday" → "Brush teeth"
        
        STEP 2 - FIND THE TIME (if mentioned):
        - "at 7:00" or "7:00" → 07:00, timeSpecified: true
        - "7:00 in the morning" or "7am" → 07:00, timeSpecified: true
        - "by 7:00 in the morning" → 07:00, timeSpecified: true
        - "3:00 in the afternoon" or "3pm" → 15:00, timeSpecified: true
        - "morning" (no specific time) → 09:00, timeSpecified: true
        - "evening" (no specific time) → 18:00, timeSpecified: true
        - If NO time mentioned → 12:00, timeSpecified: false
        
        STEP 3 - FOR DAILY RECURRING:
        If user says "every day", "everyday", or "daily":
        - Set isRecurring: true
        - Set recurringDays: ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]
        - Set dueDate: \(tomorrowDate())
        
        STEP 4 - FOR MONTHLY RECURRING:
        If user says "every month on the 20th" or "monthly on the 15th":
        - Set isRecurring: true
        - Set recurringDays: ["monthly"]
        - Set dayOfMonth: 20 (or whatever day number they said)
        - Set dueDate to the NEXT occurrence of that day
        
        STEP 5 - FOR WEEKLY RECURRING:
        If user says "every Tuesday":
        - Set isRecurring: true
        - Set recurringDays: ["tuesday"]
        - Set dueDate: \(nextWeekday("tuesday"))
        
        Return ONLY valid JSON:
        {
            "needsMoreInfo": false,
            "question": null,
            "taskData": {
                "title": "Brush teeth",
                "dueDate": "\(tomorrowDate())",
                "dueTime": "07:00",
                "timeSpecified": true,
                "dayOfMonth": null,
                "priority": "low",
                "assignee": "me",
                "isRecurring": true,
                "recurringDays": ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"],
                "voiceAlerts": false
            },
            "confirmationMessage": "Brush teeth - every day at 7:00 AM"
        }
        """
        
        let messagesArray: [[String: String]] = conversationHistory.isEmpty
            ? [["role": "user", "content": transcribedText]]
            : conversationHistory.enumerated().map { index, message in
                let role = message.hasPrefix("User:") ? "user" : "assistant"
                let content = message.replacingOccurrences(of: "User: ", with: "")
                    .replacingOccurrences(of: "Assistant: ", with: "")
                return ["role": role, "content": content]
            }
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 500,
            "system": systemPrompt,
            "messages": messagesArray
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw VoiceInputError.apiError("Failed to create request body")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15
        
        await MainActor.run { debugLog = "Sending request..." }
        print("🔵 Request body size: \(httpBody.count) bytes")
        
        // Use a background URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { debugLog = "No HTTP response" }
                throw VoiceInputError.apiError("No response from server")
            }
            
            await MainActor.run { debugLog = "Status: \(httpResponse.statusCode)" }
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No body"
                print("🔴 Error: \(responseString)")
                await MainActor.run { debugLog = "Error \(httpResponse.statusCode)" }
                
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = errorJson["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    throw VoiceInputError.apiError(message)
                }
                throw VoiceInputError.apiError("Status \(httpResponse.statusCode)")
            }
            
            await MainActor.run { debugLog = "Parsing..." }
            
            let claudeResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
            
            guard let textContent = claudeResponse.content.first?.text else {
                throw VoiceInputError.parseError("No text in response")
            }
            
            await MainActor.run { debugLog = "Got response!" }
            print("🟢 Response: \(textContent)")
            
            return try parseClaudeJSON(textContent)
            
        } catch let error as VoiceInputError {
            throw error
        } catch let error as URLError {
            await MainActor.run { debugLog = "Network error: \(error.code.rawValue)" }
            print("🔴 URLError: \(error)")
            throw VoiceInputError.apiError("Network error: \(error.localizedDescription)")
        } catch {
            await MainActor.run { debugLog = "Error: \(error.localizedDescription)" }
            print("🔴 Other error: \(error)")
            throw VoiceInputError.apiError(error.localizedDescription)
        }
    }
    
    func parseClaudeJSON(_ text: String) throws -> ClaudeTaskResponse {
        // Find JSON in the response
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON if it's embedded in text
        if let startRange = jsonString.range(of: "{"),
           let endRange = jsonString.range(of: "}", options: .backwards) {
            jsonString = String(jsonString[startRange.lowerBound...endRange.upperBound])
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw VoiceInputError.parseError("Invalid JSON string")
        }
        
        do {
            return try JSONDecoder().decode(ClaudeTaskResponse.self, from: jsonData)
        } catch {
            print("JSON Parse Error: \(error)")
            print("JSON String: \(jsonString)")
            throw VoiceInputError.parseError("Failed to parse: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Claude Response
    
    func handleClaudeResponse(_ response: ClaudeTaskResponse) async {
        print("🔵 handleClaudeResponse called")
        print("🔵 needsMoreInfo: \(response.needsMoreInfo)")
        print("🔵 taskData: \(String(describing: response.taskData))")
        
        // Always proceed to confirmation - never ask follow-up questions
        if let taskData = response.taskData {
            // Clean up the title and show confirmation
            var cleanedTaskData = taskData
            cleanedTaskData.title = cleanUpTitle(taskData.title ?? "Task")
            
            // If no time specified, default to noon
            if cleanedTaskData.dueTime == nil || cleanedTaskData.dueTime?.isEmpty == true {
                cleanedTaskData.dueTime = "12:00"
                cleanedTaskData.timeSpecified = false
            }
            
            // FIX THE DATE - always calculate correct date based on recurring pattern
            // Claude often returns today's date incorrectly
            
            // If monthly but no dayOfMonth, try to extract from original text
            if cleanedTaskData.recurringDays?.contains(where: { $0.lowercased() == "monthly" }) == true {
                if cleanedTaskData.dayOfMonth == nil {
                    cleanedTaskData.dayOfMonth = extractDayOfMonth(from: transcribedText)
                    print("   Extracted dayOfMonth from text: \(cleanedTaskData.dayOfMonth ?? -1)")
                }
            }
            
            cleanedTaskData.dueDate = calculateCorrectDate(from: cleanedTaskData)
            
            parsedTask = cleanedTaskData
            
            // Build a clean confirmation message
            let displayTitle = cleanedTaskData.title ?? "Task"
            let daysStr = formatRecurringDays(cleanedTaskData.recurringDays)
            
            if cleanedTaskData.isRecurring == true && !daysStr.isEmpty {
                assistantMessage = "\(displayTitle) - \(daysStr)"
            } else {
                assistantMessage = "\(displayTitle)"
            }
            
            conversationState = .confirming
            print("🟢 State changed to: confirming")
        } else {
            // No task data and no more info needed - something went wrong
            errorMessage = "Couldn't understand the task. Please try again."
            conversationState = .error
            print("🔴 State changed to: error (no task data)")
        }
    }
    
    // MARK: - Continue Conversation
    
    func continueListening() async {
        transcribedText = ""
        await startListening()
    }
    
    // MARK: - Process Follow-up (for time input)
    
    func processFollowUp() async {
        guard !transcribedText.isEmpty else { return }
        
        await MainActor.run {
            conversationState = .processing
            debugLog = "Processing time..."
        }
        
        let lowercased = transcribedText.lowercased()
        
        // Try to extract time from follow-up
        var dueTime: String? = nil
        
        let timePatterns = [
            "(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)",
            "(\\d{1,2}):(\\d{2})",
            "in (\\d+) hours?",
            "in (\\d+) minutes?"
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
                
                if pattern.contains("in") {
                    // Handle "in X hours/minutes"
                    if let numRange = Range(match.range(at: 1), in: lowercased) {
                        let num = Int(lowercased[numRange]) ?? 1
                        var futureDate: Date
                        if lowercased.contains("hour") {
                            futureDate = Date().addingTimeInterval(TimeInterval(num * 3600))
                        } else {
                            futureDate = Date().addingTimeInterval(TimeInterval(num * 60))
                        }
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        dueTime = formatter.string(from: futureDate)
                    }
                } else if let hourRange = Range(match.range(at: 1), in: lowercased) {
                    var hour = Int(lowercased[hourRange]) ?? 12
                    var minute = 0
                    
                    if match.numberOfRanges > 2, let minRange = Range(match.range(at: 2), in: lowercased) {
                        minute = Int(lowercased[minRange]) ?? 0
                    }
                    
                    if lowercased.contains("pm") && hour < 12 {
                        hour += 12
                    } else if lowercased.contains("am") && hour == 12 {
                        hour = 0
                    }
                    
                    dueTime = String(format: "%02d:%02d", hour, minute)
                }
                break
            }
        }
        
        await MainActor.run {
            if let time = dueTime, var task = parsedTask {
                // Update the task with the time
                parsedTask = ParsedTaskData(
                    title: task.title,
                    dueDate: task.dueDate ?? formattedToday(),
                    dueTime: time,
                    priority: task.priority,
                    assignee: task.assignee,
                    isRecurring: task.isRecurring,
                    recurringDays: task.recurringDays,
                    voiceAlerts: task.voiceAlerts
                )
                
                // Show clean confirmation
                let displayTitle = task.title ?? "Task"
                let daysStr = formatRecurringDays(task.recurringDays)
                if task.isRecurring == true && !daysStr.isEmpty {
                    assistantMessage = "\(displayTitle) - \(daysStr) at \(time)?"
                } else {
                    assistantMessage = "\(displayTitle) at \(time)?"
                }
                conversationState = .confirming
                debugLog = "Ready!"
            } else {
                // Couldn't parse time, default to noon
                if var task = parsedTask {
                    task.dueTime = "12:00"
                    task.timeSpecified = false
                    parsedTask = task
                    
                    let displayTitle = task.title ?? "Task"
                    assistantMessage = "\(displayTitle)"
                    conversationState = .confirming
                    debugLog = "Defaulting to noon"
                }
            }
        }
    }
    
    // MARK: - Create Task from Parsed Data
    
    func createTask(userManager: UserManager) -> VisualTask? {
        guard let parsed = parsedTask else {
            print("❌ No parsed task")
            return nil
        }
        guard let currentUser = userManager.currentUser else {
            print("❌ No current user")
            return nil
        }
        
        // Clean up the title - extract key words
        let cleanTitle = cleanUpTitle(parsed.title ?? "Task")
        
        print("📋 Creating task from parsed data:")
        print("   Original title: \(parsed.title ?? "nil")")
        print("   Clean title: \(cleanTitle)")
        print("   Date: \(parsed.dueDate ?? "nil")")
        print("   Time: \(parsed.dueTime ?? "nil")")
        print("   dayOfMonth: \(parsed.dayOfMonth ?? -1)")
        print("   Recurring: \(parsed.isRecurring ?? false)")
        print("   Days: \(parsed.recurringDays ?? [])")
        
        // Parse the time - handle various formats
        var hour = 9  // default morning
        var minute = 0
        
        if let timeStr = parsed.dueTime {
            // Handle "07:30", "7:30", "730", etc.
            let cleanTime = timeStr.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if cleanTime.count >= 3 {
                if cleanTime.count == 3 {
                    // "730" -> 7, 30
                    hour = Int(String(cleanTime.prefix(1))) ?? 9
                    minute = Int(String(cleanTime.suffix(2))) ?? 0
                } else if cleanTime.count == 4 {
                    // "0730" -> 07, 30
                    hour = Int(String(cleanTime.prefix(2))) ?? 9
                    minute = Int(String(cleanTime.suffix(2))) ?? 0
                }
            } else if timeStr.contains(":") {
                let parts = timeStr.split(separator: ":")
                if parts.count >= 2 {
                    hour = Int(parts[0]) ?? 9
                    minute = Int(parts[1].prefix(2)) ?? 0
                }
            }
        }
        
        print("   Parsed time: \(hour):\(minute)")
        
        // Calculate the deadline - use the already-calculated dueDate from parsed data
        var deadline: Date
        let calendar = Calendar.current
        let today = Date()
        
        // The dueDate should already be correctly calculated by calculateCorrectDate()
        // Just parse it and add the time
        if let dateStr = parsed.dueDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateStr) {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                deadline = calendar.date(from: components) ?? today.addingTimeInterval(86400)
                print("   Using parsed dueDate: \(dateStr) -> \(deadline)")
            } else {
                // Couldn't parse date, default to tomorrow
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = hour
                components.minute = minute
                deadline = calendar.date(from: components) ?? tomorrow
                print("   Couldn't parse date, defaulting to tomorrow: \(deadline)")
            }
        } else {
            // No date provided, default to tomorrow
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = hour
            components.minute = minute
            deadline = calendar.date(from: components) ?? tomorrow
            print("   No date provided, defaulting to tomorrow: \(deadline)")
        }
        
        // Final safety check - if deadline is still in the past, push to tomorrow
        if deadline <= today {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = hour
            components.minute = minute
            deadline = calendar.date(from: components) ?? tomorrow
            print("   Safety: pushed to tomorrow: \(deadline)")
        }
        
        print("   Final deadline: \(deadline)")
        
        // Parse priority - default to LOW
        let priority: PriorityLevel
        switch parsed.priority?.lowercased() {
        case "medium": priority = .medium
        case "high": priority = .high
        default: priority = .low  // Default is now LOW (green)
        }
        
        // Parse recurring days
        var recurringDays: Set<Weekday> = []
        if let days = parsed.recurringDays {
            for day in days {
                switch day.lowercased() {
                case "sunday": recurringDays.insert(.sunday)
                case "monday": recurringDays.insert(.monday)
                case "tuesday": recurringDays.insert(.tuesday)
                case "wednesday": recurringDays.insert(.wednesday)
                case "thursday": recurringDays.insert(.thursday)
                case "friday": recurringDays.insert(.friday)
                case "saturday": recurringDays.insert(.saturday)
                default: break
                }
            }
        }
        
        // Determine assignee
        let assigneeName = parsed.assignee ?? currentUser.name
        let assigneeUser = userManager.users.first { $0.name.lowercased() == assigneeName.lowercased() } ?? currentUser
        
        return VisualTask(
            title: cleanTitle,
            deadlineTime: deadline,
            isRecurring: parsed.isRecurring ?? false,
            recurringDays: recurringDays,
            userId: assigneeUser.id,
            userName: assigneeUser.name,
            userAvatar: assigneeUser.avatarEmoji,
            userColor: assigneeUser.color,
            basePriority: priority,
            voiceAlertsEnabled: parsed.voiceAlerts ?? false,
            voiceAlertMinutesBefore: 2,
            reminderEnabled: parsed.voiceAlerts ?? false,
            reminderMinutesBefore: 5,
            reminderType: "Siri",
            reminderSound: "Radar"
        )
    }
    
    // MARK: - Reset
    
    func reset() {
        stopListening()
        transcribedText = ""
        originalTranscription = ""
        isProcessing = false
        conversationState = .idle
        parsedTask = nil
        errorMessage = nil
        assistantMessage = nil
        conversationHistory = []
        debugLog = ""
    }
    
    // MARK: - Helpers
    
    func formatRecurringDays(_ days: [String]?) -> String {
        guard let days = days, !days.isEmpty else { return "" }
        
        let lowercaseDays = days.map { $0.lowercased() }
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday"]
        let weekend = ["saturday", "sunday"]
        let allDays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        
        // Check for special patterns
        let sortedDays = Set(lowercaseDays)
        
        if sortedDays == Set(allDays) {
            return "daily"
        } else if sortedDays == Set(weekdays) {
            return "weekdays"
        } else if sortedDays == Set(weekend) {
            return "weekends"
        } else if days.count == 1 {
            return "every \(days[0].capitalized)"
        } else {
            // Multiple specific days
            let capitalized = days.map { $0.capitalized }
            if capitalized.count == 2 {
                return "every \(capitalized[0]) & \(capitalized[1])"
            } else {
                return "every \(capitalized.joined(separator: ", "))"
            }
        }
    }
    
    func cleanUpTitle(_ rawTitle: String) -> String {
        // Words to remove (days, times, filler words, months)
        let removeWords = [
            "every", "the", "a", "an", "by", "at", "on", "in", "to", "from",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "morning", "afternoon", "evening", "night", "noon",
            "am", "pm", "oclock", "o'clock",
            "month", "monthly", "week", "weekly", "day", "daily", "everyday", "year", "yearly",
            "starting", "beginning", "repeat", "recurring",
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december",
            "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th",
            "10th", "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th", "19th",
            "20th", "21st", "22nd", "23rd", "24th", "25th", "26th", "27th", "28th", "29th", "30th", "31st"
        ]
        
        // Split by common separators (period, comma, newline)
        let segments = rawTitle
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        
        // Remove time patterns (like "7:30", ":30", "730")
        let withoutTimes = segments.filter { word in
            let lower = word.lowercased()
            // Skip if it's a time pattern
            if lower.contains(":") { return false }
            if Int(lower) != nil && lower.count >= 3 { return false } // "730"
            return true
        }
        
        // Remove filler words and day names
        let cleanWords = withoutTimes.filter { word in
            let lower = word.lowercased()
            return !removeWords.contains(lower)
        }
        
        // Take first 1-3 meaningful words
        let meaningfulWords = cleanWords.prefix(3)
        
        if meaningfulWords.isEmpty {
            // Fallback: just take first word that's not in remove list
            let firstWord = segments.first { word in
                let lower = word.lowercased()
                return !["the", "a", "an", "by", "at", "on", "in", "to", "every"].contains(lower)
            }
            return firstWord?.capitalized ?? "Task"
        }
        
        // Capitalize first word, lowercase rest
        var result = meaningfulWords.map { $0.lowercased() }
        if let first = result.first {
            result[0] = first.capitalized
        }
        
        return result.joined(separator: " ")
    }
    
    func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    func currentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    func currentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    func currentMonthNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter.string(from: Date())
    }
    
    func currentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    func tomorrowDate() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: tomorrow)
    }
    
    func nextWeekday(_ dayName: String) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        let dayMap: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        guard let targetWeekday = dayMap[dayName.lowercased()] else {
            return tomorrowDate()
        }
        
        let currentWeekday = calendar.component(.weekday, from: today)
        var daysUntil = targetWeekday - currentWeekday
        
        if daysUntil <= 0 {
            daysUntil += 7
        }
        
        let targetDate = calendar.date(byAdding: .day, value: daysUntil, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: targetDate)
    }
    
    func nextMonthFirstDay() -> String {
        let calendar = Calendar.current
        let today = Date()
        
        var components = calendar.dateComponents([.year, .month], from: today)
        components.month! += 1
        components.day = 1
        
        let nextMonth = calendar.date(from: components) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: nextMonth)
    }
    
    func isToday(_ dateStr: String?) -> Bool {
        guard let dateStr = dateStr else { return false }
        return dateStr == formattedToday()
    }
    
    func extractDayOfMonth(from text: String) -> Int? {
        let lowercased = text.lowercased()
        
        // First check for spelled-out ordinals
        let spelledOrdinals: [String: Int] = [
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
            "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
            "eleventh": 11, "twelfth": 12, "thirteenth": 13, "fourteenth": 14, "fifteenth": 15,
            "sixteenth": 16, "seventeenth": 17, "eighteenth": 18, "nineteenth": 19, "twentieth": 20,
            "twenty-first": 21, "twenty first": 21, "twenty-second": 22, "twenty second": 22,
            "twenty-third": 23, "twenty third": 23, "twenty-fourth": 24, "twenty fourth": 24,
            "twenty-fifth": 25, "twenty fifth": 25, "twenty-sixth": 26, "twenty sixth": 26,
            "twenty-seventh": 27, "twenty seventh": 27, "twenty-eighth": 28, "twenty eighth": 28,
            "twenty-ninth": 29, "twenty ninth": 29, "thirtieth": 30, "thirty-first": 31, "thirty first": 31
        ]
        
        for (word, day) in spelledOrdinals {
            if lowercased.contains(word) {
                print("   Found spelled ordinal '\(word)' -> day \(day)")
                return day
            }
        }
        
        // Patterns to match: "the 20th", "on the 15th", "the 1st", "the 2nd", "the 3rd", "the 5th"
        let patterns = [
            "the (\\d{1,2})(?:st|nd|rd|th)",
            "on the (\\d{1,2})(?:st|nd|rd|th)",
            "(\\d{1,2})(?:st|nd|rd|th) of",
            "(\\d{1,2})(?:st|nd|rd|th)"  // More general pattern
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: lowercased) {
                if let day = Int(lowercased[range]) {
                    if day >= 1 && day <= 31 {
                        print("   Found dayOfMonth in text: \(day)")
                        return day
                    }
                }
            }
        }
        
        return nil
    }
    
    func calculateCorrectDate(from taskData: ParsedTaskData) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        print("📅 calculateCorrectDate called")
        print("   Provided date: \(taskData.dueDate ?? "nil")")
        print("   isRecurring: \(taskData.isRecurring ?? false)")
        print("   recurringDays: \(taskData.recurringDays ?? [])")
        print("   dayOfMonth: \(taskData.dayOfMonth ?? -1)")
        
        // Check for recurring patterns
        let isMonthly = taskData.recurringDays?.contains(where: { $0.lowercased() == "monthly" }) ?? false
        let weekdayRecurring = taskData.recurringDays?.filter {
            ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains($0.lowercased())
        } ?? []
        
        print("   isMonthly: \(isMonthly)")
        print("   weekdayRecurring: \(weekdayRecurring)")
        
        // If monthly recurring
        if isMonthly {
            var targetDay: Int? = taskData.dayOfMonth
            
            // If no dayOfMonth, try to extract from dueDate
            if targetDay == nil, let dateStr = taskData.dueDate {
                let inputFormatter = DateFormatter()
                inputFormatter.dateFormat = "yyyy-MM-dd"
                if let date = inputFormatter.date(from: dateStr) {
                    targetDay = calendar.component(.day, from: date)
                }
            }
            
            // If still no day, default to 1st of month
            let dayOfMonth = targetDay ?? 1
            print("   Using dayOfMonth: \(dayOfMonth)")
            
            // Build next occurrence of this day
            var components = calendar.dateComponents([.year, .month], from: today)
            components.day = dayOfMonth
            
            if let nextDate = calendar.date(from: components) {
                var finalDate = nextDate
                // If this day has passed this month, move to next month
                if finalDate <= today {
                    finalDate = calendar.date(byAdding: .month, value: 1, to: finalDate) ?? finalDate
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let result = formatter.string(from: finalDate)
                print("   Monthly result: \(result)")
                return result
            }
            
            // Fallback
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: nextMonth)
        }
        
        // If weekly recurring (every Tuesday, etc.) or daily
        if !weekdayRecurring.isEmpty {
            // Check if it's daily (all 7 days) - use tomorrow
            let allDays = Set(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
            if Set(weekdayRecurring.map { $0.lowercased() }) == allDays {
                print("   Daily recurring - using tomorrow")
                return tomorrowDate()
            }
            
            // Otherwise find next occurrence of the specific day(s)
            let result = nextWeekday(weekdayRecurring.first ?? "monday")
            print("   Weekly result: \(result)")
            return result
        }
        
        // If a specific date was provided and it's not today
        if let dateStr = taskData.dueDate, !isToday(dateStr) {
            // Validate it's in the future
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd"
            if let date = inputFormatter.date(from: dateStr), date > today {
                print("   Using provided future date: \(dateStr)")
                return dateStr
            }
        }
        
        // Default to tomorrow
        let result = tomorrowDate()
        print("   Defaulting to tomorrow: \(result)")
        return result
    }
    
    func nextOccurrence(of dayName: String, atHour hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Map day name to weekday number (1 = Sunday, 2 = Monday, etc.)
        let dayMap: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        guard let targetWeekday = dayMap[dayName.lowercased()] else {
            // Default to tomorrow if day not recognized
            var components = calendar.dateComponents([.year, .month, .day], from: today)
            components.hour = hour
            components.minute = minute
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? today) ?? today
        }
        
        let currentWeekday = calendar.component(.weekday, from: today)
        var daysUntilTarget = targetWeekday - currentWeekday
        
        if daysUntilTarget < 0 {
            daysUntilTarget += 7
        } else if daysUntilTarget == 0 {
            // It's the same day - check if the time has passed
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
            todayComponents.hour = hour
            todayComponents.minute = minute
            if let targetTime = calendar.date(from: todayComponents), targetTime <= today {
                // Time has passed, set for next week
                daysUntilTarget = 7
            }
        }
        
        // Calculate the target date
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: today)
        targetComponents.hour = hour
        targetComponents.minute = minute
        
        if let baseDate = calendar.date(from: targetComponents) {
            return calendar.date(byAdding: .day, value: daysUntilTarget, to: baseDate) ?? today
        }
        
        return today
    }
    
    func nextOccurrenceOfAny(days: [String], atHour hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Map day names to weekday numbers (1 = Sunday, 2 = Monday, etc.)
        let dayMap: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        let currentWeekday = calendar.component(.weekday, from: today)
        var minDaysUntil = 8  // Start with more than a week
        
        for dayName in days {
            guard let targetWeekday = dayMap[dayName.lowercased()] else { continue }
            
            var daysUntil = targetWeekday - currentWeekday
            
            if daysUntil < 0 {
                daysUntil += 7
            } else if daysUntil == 0 {
                // It's today - check if time has passed
                var todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
                todayComponents.hour = hour
                todayComponents.minute = minute
                if let targetTime = calendar.date(from: todayComponents), targetTime > today {
                    // Time hasn't passed, can use today
                    daysUntil = 0
                } else {
                    // Time has passed, find next occurrence (which would be next week for this day)
                    daysUntil = 7
                }
            }
            
            if daysUntil < minDaysUntil {
                minDaysUntil = daysUntil
            }
        }
        
        // Default to tomorrow if no valid days found
        if minDaysUntil > 7 {
            minDaysUntil = 1
        }
        
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: today)
        targetComponents.hour = hour
        targetComponents.minute = minute
        
        if let baseDate = calendar.date(from: targetComponents) {
            return calendar.date(byAdding: .day, value: minDaysUntil, to: baseDate) ?? today
        }
        
        return today
    }
}

// MARK: - Data Models

struct ClaudeAPIResponse: Codable {
    let content: [ContentBlock]
    
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

struct ClaudeTaskResponse: Codable {
    let needsMoreInfo: Bool
    let question: String?
    let taskData: ParsedTaskData?
    let confirmationMessage: String?
}

struct ParsedTaskData: Codable {
    var title: String?
    var dueDate: String?
    var dueTime: String?
    var timeSpecified: Bool?
    var dayOfMonth: Int?  // For monthly recurring (e.g., 20 for "the 20th")
    var priority: String?
    var assignee: String?
    var isRecurring: Bool?
    var recurringDays: [String]?
    var voiceAlerts: Bool?
}

enum VoiceInputError: LocalizedError {
    case invalidURL
    case apiError(String)
    case parseError(String)
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let message):
            return "API Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        case .noAPIKey:
            return "Please add your Claude API key in VoiceInputManager.swift (line ~142)"
        }
    }
}
