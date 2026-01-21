//
//  SpeechManager.swift
//  VisualMemory
//  Text-to-speech for Siri-like voice responses
//

import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var selectedVoiceIdentifier: String?
    
    // Completion handler for when speech finishes
    var onSpeechFinished: (() -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Set default to Siri-like female voice
        selectedVoiceIdentifier = findBestVoice()
    }
    
    // MARK: - Find Best Voice
    
    private func findBestVoice() -> String? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Priority order for natural Siri-like voices
        let preferredVoices = [
            "com.apple.voice.premium.en-US.Samantha",  // Premium Samantha (most Siri-like)
            "com.apple.voice.enhanced.en-US.Samantha", // Enhanced Samantha
            "com.apple.ttsbundle.Samantha-premium",    // Alternative premium
            "com.apple.voice.premium.en-US.Ava",       // Premium Ava
            "com.apple.voice.enhanced.en-US.Ava",      // Enhanced Ava
            "com.apple.ttsbundle.siri_female_en-US_compact", // Siri voice
            "com.apple.ttsbundle.Samantha-compact"     // Basic Samantha
        ]
        
        for preferredId in preferredVoices {
            if voices.contains(where: { $0.identifier == preferredId }) {
                return preferredId
            }
        }
        
        // Fallback to any English female voice
        if let englishVoice = voices.first(where: { 
            $0.language.starts(with: "en") && $0.gender == .female 
        }) {
            return englishVoice.identifier
        }
        
        // Last resort - any English voice
        return voices.first(where: { $0.language.starts(with: "en") })?.identifier
    }
    
    // MARK: - Speak
    
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        onSpeechFinished = completion
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Set voice
        if let voiceId = selectedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Natural speech settings
        utterance.rate = 0.52  // Slightly faster than default for natural feel
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func speakWithPause(_ text: String, pauseSeconds: Double = 0.5, completion: (() -> Void)? = nil) {
        speak(text) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseSeconds) {
                completion?()
            }
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // MARK: - Available Voices (for future settings)
    
    struct VoiceOption: Identifiable {
        let id: String
        let name: String
        let language: String
        let gender: AVSpeechSynthesisVoiceGender
        let quality: String
    }
    
    func availableEnglishVoices() -> [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        return voices
            .filter { $0.language.starts(with: "en") }
            .map { voice in
                let quality: String
                if voice.identifier.contains("premium") {
                    quality = "Premium"
                } else if voice.identifier.contains("enhanced") {
                    quality = "Enhanced"
                } else {
                    quality = "Standard"
                }
                
                return VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    gender: voice.gender,
                    quality: quality
                )
            }
            .sorted { $0.quality > $1.quality } // Premium first
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onSpeechFinished?()
            self.onSpeechFinished = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

// MARK: - Conversation Prompts

extension SpeechManager {
    
    // Greeting based on time of day
    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning!"
        case 12..<17:
            return "Good afternoon!"
        case 17..<21:
            return "Good evening!"
        default:
            return "Hello!"
        }
    }
    
    // MARK: - Onboarding Prompts
    
    func speakWelcome(completion: (() -> Void)? = nil) {
        speak("\(timeBasedGreeting) I'm here to help you set up your tasks. Just tell me what you need to remember, and I'll organize it for you.", completion: completion)
    }
    
    func speakMorningRoutinePrompt(completion: (() -> Void)? = nil) {
        speak("Let's start with your morning. What time do you usually wake up? And do you have any morning habits you'd like to track?", completion: completion)
    }
    
    func speakDailyHabitsPrompt(completion: (() -> Void)? = nil) {
        speak("Do you have any daily habits you want to maintain? Things like exercise, meditation, or reading?", completion: completion)
    }
    
    func speakChoresPrompt(completion: (() -> Void)? = nil) {
        speak("What about household chores? Things like taking out the trash, laundry, or grocery shopping?", completion: completion)
    }
    
    func speakBillsPrompt(completion: (() -> Void)? = nil) {
        speak("Do you have any bills you need to pay regularly? Like rent, utilities, or subscriptions?", completion: completion)
    }
    
    func speakCustomPrompt(completion: (() -> Void)? = nil) {
        speak("Is there anything else you'd like me to help you track?", completion: completion)
    }
    
    // MARK: - Task Confirmation Prompts
    
    func speakTaskConfirmation(taskTitle: String, completion: (() -> Void)? = nil) {
        speak("Got it! I've added \(taskTitle) to your list.", completion: completion)
    }
    
    func speakMultipleTasksConfirmation(count: Int, completion: (() -> Void)? = nil) {
        if count == 1 {
            speak("I've added 1 task for you.", completion: completion)
        } else {
            speak("I've added \(count) tasks for you.", completion: completion)
        }
    }
    
    // MARK: - Follow-up Questions
    
    func speakWeekendQuestion(taskTitle: String, completion: (() -> Void)? = nil) {
        speak("Should \(taskTitle) also apply to weekends?", completion: completion)
    }
    
    func speakTimeQuestion(taskTitle: String, completion: (() -> Void)? = nil) {
        speak("What time would you like to be reminded about \(taskTitle)?", completion: completion)
    }
    
    func speakRecurringQuestion(taskTitle: String, completion: (() -> Void)? = nil) {
        speak("Is \(taskTitle) a daily task, or does it happen on specific days?", completion: completion)
    }
    
    // MARK: - Transition Prompts
    
    func speakNextSection(sectionName: String, completion: (() -> Void)? = nil) {
        speak("Great! Now let's talk about \(sectionName).", completion: completion)
    }
    
    func speakReviewPrompt(taskCount: Int, completion: (() -> Void)? = nil) {
        if taskCount == 0 {
            speak("You haven't added any tasks yet. Would you like to go back and add some?", completion: completion)
        } else if taskCount == 1 {
            speak("You have 1 task ready. Take a moment to review it.", completion: completion)
        } else {
            speak("You have \(taskCount) tasks ready. Take a moment to review them.", completion: completion)
        }
    }
    
    func speakCompletion(taskCount: Int, completion: (() -> Void)? = nil) {
        if taskCount == 0 {
            speak("You're all set! You can add tasks anytime from the main screen.", completion: completion)
        } else {
            speak("You're all set! I've added \(taskCount) tasks to help you stay on track. Good luck!", completion: completion)
        }
    }
    
    // MARK: - Error/Clarification
    
    func speakDidntUnderstand(completion: (() -> Void)? = nil) {
        speak("I didn't quite catch that. Could you say it again?", completion: completion)
    }
    
    func speakNoTasksDetected(completion: (() -> Void)? = nil) {
        speak("I didn't detect any specific tasks. Try saying something like 'brush teeth at 7 AM' or 'take out trash every Thursday'.", completion: completion)
    }
}
