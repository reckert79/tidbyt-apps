import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Onboarding Phase (5 Screens)

enum SOPhase: String, Equatable, Codable, CaseIterable {
    case aboutYou
    case detailedInfo
    case dailyTasks
    case recurringTasks
    case memoryHelper
    case reviewTasks
    
    var title: String {
        switch self {
        case .aboutYou: return "Basic Information About You"
        case .detailedInfo: return "Detailed Information About You"
        case .dailyTasks: return "Daily Tasks"
        case .recurringTasks: return "Recurring Tasks"
        case .memoryHelper: return "Intelligent Task Adder"
        case .reviewTasks: return "Review Tasks"
        }
    }
    
    var stepNumber: Int {
        switch self {
        case .aboutYou: return 1
        case .detailedInfo: return 2
        case .dailyTasks: return 3
        case .recurringTasks: return 4
        case .memoryHelper: return 5
        case .reviewTasks: return 6
        }
    }
}

// MARK: - Priority

enum SOPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Frequency

enum SOFrequency: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case once = "One-time"
    
    var color: Color {
        switch self {
        case .daily: return .cyan
        case .weekly: return .green
        case .monthly: return .purple
        case .yearly: return .orange
        case .once: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.circle"
        case .monthly: return "calendar"
        case .yearly: return "calendar.badge.clock"
        case .once: return "1.circle"
        }
    }
}

// MARK: - Category

enum SOCategory: String, CaseIterable, Codable {
    case morning = "Morning Routine"
    case health = "Health & Wellness"
    case kids = "Kids & Family"
    case pets = "Pet Care"
    case elderCare = "Elder Care"
    case home = "Home & Chores"
    case work = "Work & Career"
    case finance = "Finance & Bills"
    case errands = "Errands & Shopping"
    case social = "Social & Events"
    case personal = "Personal"
    case night = "Evening Routine"
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .health: return "heart.fill"
        case .kids: return "figure.and.child.holdinghands"
        case .pets: return "pawprint.fill"
        case .elderCare: return "figure.stand"
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .finance: return "dollarsign.circle.fill"
        case .errands: return "cart.fill"
        case .social: return "person.3.fill"
        case .personal: return "person.fill"
        case .night: return "moon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .morning: return .orange
        case .health: return .red
        case .kids: return .cyan
        case .pets: return .brown
        case .elderCare: return .purple
        case .home: return .green
        case .work: return .blue
        case .finance: return .yellow
        case .errands: return .pink
        case .social: return .indigo
        case .personal: return .gray
        case .night: return .purple
        }
    }
}

// MARK: - Task Model

struct SOTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var frequency: SOFrequency
    var daysOfWeek: [String]
    var dayOfMonth: Int?
    var monthOfYear: Int?
    var time: String
    var dueDate: Date?  // For one-time tasks
    var duration: Int
    var priority: SOPriority
    var category: SOCategory
    var isSelected: Bool
    var relatedDependentId: UUID?
    var relatedDependentName: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        frequency: SOFrequency = .daily,
        daysOfWeek: [String] = [],
        dayOfMonth: Int? = nil,
        monthOfYear: Int? = nil,
        time: String = "",
        dueDate: Date? = nil,
        duration: Int = 15,
        priority: SOPriority = .medium,
        category: SOCategory = .personal,
        isSelected: Bool = true,
        relatedDependentId: UUID? = nil,
        relatedDependentName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.frequency = frequency
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.time = time
        self.dueDate = dueDate
        self.duration = duration
        self.priority = priority
        self.category = category
        self.isSelected = isSelected
        self.relatedDependentId = relatedDependentId
        self.relatedDependentName = relatedDependentName
    }
    
    var timeDisplay: String {
        guard !time.isEmpty else { return "Any time" }
        let parts = time.components(separatedBy: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else { return time }
        let minute = Int(parts[1]) ?? 0
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(hour12):\(String(format: "%02d", minute)) \(ampm)"
    }
    
    var dueDateDisplay: String {
        guard let date = dueDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var durationDisplay: String {
        if duration == 0 { return "" }
        if duration < 60 { return "\(duration) min" }
        let hours = duration / 60
        let mins = duration % 60
        if mins == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }
    
    var scheduleDisplay: String {
        switch frequency {
        case .daily: return "Every day"
        case .weekly:
            if daysOfWeek.isEmpty { return "Weekly" }
            let shortDays = daysOfWeek.map { $0.prefix(3).capitalized }
            return shortDays.joined(separator: ", ")
        case .monthly:
            if let day = dayOfMonth { return "Monthly on the \(ordinal(day))" }
            return "Monthly"
        case .yearly: return "Yearly"
        case .once:
            if let date = dueDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
            return "One-time"
        }
    }
    
    // For sorting by date
    var sortDate: Date {
        if let date = dueDate { return date }
        return Date.distantFuture
    }
    
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }
}

// MARK: - Kid

struct SOKid: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var age: Int
    var gender: String
    
    init(id: UUID = UUID(), name: String = "", age: Int = 10, gender: String = "") {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
    }
    
    var displayString: String {
        var result = name
        if age > 0 { result += ", \(age)" }
        if !gender.isEmpty { result += " (\(gender.capitalized))" }
        return result
    }
}

// MARK: - Pet

struct SOPet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var petType: String
    var age: String  // Changed to String to support "6 months", "2 years", etc.
    
    init(id: UUID = UUID(), name: String = "", petType: String = "dog", age: String = "") {
        self.id = id
        self.name = name
        self.petType = petType
        self.age = age
    }
    
    var displayString: String {
        if age.isEmpty {
            return "\(name) (\(petType.capitalized))"
        }
        return "\(name) (\(petType.capitalized), \(age))"
    }
    
    var icon: String {
        switch petType.lowercased() {
        case "dog": return "dog.fill"
        case "cat": return "cat.fill"
        case "bird": return "bird.fill"
        case "fish": return "fish.fill"
        case "rabbit": return "hare.fill"
        default: return "pawprint.fill"
        }
    }
}

// MARK: - Parent/Elder

struct SOParent: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var relationship: String
    var age: Int
    var livesWithYou: Bool
    
    init(id: UUID = UUID(), name: String = "", relationship: String = "parent", age: Int = 70, livesWithYou: Bool = false) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.age = age
        self.livesWithYou = livesWithYou
    }
    
    var displayString: String {
        var result = "\(name) (\(relationship.capitalized), \(age))"
        if livesWithYou { result += " • Lives with you" }
        return result
    }
}

// MARK: - Profile

struct SOProfile: Codable {
    var age: Int = 30
    var gender: String = ""
    var wakeTime: String = "07:00"
    var bedTime: String = "22:00"
    var sameScheduleWeekends: Bool = true  // Whether same sleep schedule on weekends
    var kids: [SOKid] = []
    var pets: [SOPet] = []
    var dependentParents: [SOParent] = []
    
    // Detailed info
    var vehicles: [SOVehicle] = []
    var housingType: String = ""  // house, condo, apartment, townhouse
    var hasYard: Bool = false
    var hasPool: Bool = false
    var hasGarage: Bool = false
    var occupation: String = ""
    var worksFromHome: Bool = false
    var hobbies: [String] = []
    
    var hasKids: Bool { !kids.isEmpty }
    var hasPets: Bool { !pets.isEmpty }
    var hasParents: Bool { !dependentParents.isEmpty }
    var hasVehicles: Bool { !vehicles.isEmpty }
    
    var wakeHour: Int { Int(wakeTime.components(separatedBy: ":").first ?? "7") ?? 7 }
    var bedHour: Int { Int(bedTime.components(separatedBy: ":").first ?? "22") ?? 22 }
}

// MARK: - Vehicle

struct SOVehicle: Identifiable, Codable {
    var id = UUID()
    var name: String = ""  // "My Honda", "Dad's truck"
    var type: String = "car"  // car, truck, suv, motorcycle, boat
    var year: Int = 2020
    var needsOilChange: Bool = true
    var needsRegistration: Bool = true
}

// MARK: - Memory Question

struct SOQuestion: Identifiable {
    let id: UUID
    let question: String
    let category: SOCategory
    let suggestedTaskTitle: String
    var isAnswered: Bool = false
    var answeredYes: Bool = false
    
    init(id: UUID = UUID(), question: String, category: SOCategory, suggestedTaskTitle: String) {
        self.id = id
        self.question = question
        self.category = category
        self.suggestedTaskTitle = suggestedTaskTitle
    }
}

// MARK: - Detailed Info Question

struct SODetailedQuestion: Identifiable {
    let id: UUID
    let question: String
    let questionType: DetailedQuestionType
    var isAnswered: Bool = false
    var answer: String = ""
    
    enum DetailedQuestionType {
        case yesNo(followUp: String?)
        case selection([String])
        case freeText
        case vehicle
        case housing
    }
    
    init(id: UUID = UUID(), question: String, questionType: DetailedQuestionType) {
        self.id = id
        self.question = question
        self.questionType = questionType
    }
}

// MARK: - Task Bubble

struct SOBubble: Identifiable {
    let id: UUID
    let title: String
    let category: SOCategory
    
    init(id: UUID = UUID(), title: String, category: SOCategory) {
        self.id = id
        self.title = title
        self.category = category
    }
}

// MARK: - Main Manager

@MainActor
class ClaudeSmartOnboardingManager: ObservableObject {
    @Published var currentPhase: SOPhase = .aboutYou
    @Published var userProfile = SOProfile()
    
    @Published var suggestedDailyTasks: [SOTask] = []
    @Published var suggestedRecurringTasks: [SOTask] = []
    @Published var customTasks: [SOTask] = []
    @Published var taskBubbles: [SOBubble] = []
    
    @Published var editingTask: SOTask? = nil
    @Published var showingTaskEditor: Bool = false
    
    @Published var editingKid: SOKid = SOKid()
    @Published var editingPet: SOPet = SOPet()
    @Published var editingParent: SOParent = SOParent()
    @Published var editingVehicle: SOVehicle = SOVehicle()
    @Published var showingKidEditor: Bool = false
    @Published var showingPetEditor: Bool = false
    @Published var showingParentEditor: Bool = false
    @Published var showingVehicleEditor: Bool = false
    @Published var editingKidIndex: Int? = nil
    @Published var editingPetIndex: Int? = nil
    @Published var editingParentIndex: Int? = nil
    @Published var editingVehicleIndex: Int? = nil
    
    // Detailed info questions
    @Published var detailedInfoQuestions: [SODetailedQuestion] = []
    @Published var currentDetailedQuestionIndex: Int = 0
    
    @Published var memoryQuestions: [SOQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var showingMemoryTaskEditor: Bool = false
    
    @Published var isListening: Bool = false
    @Published var voiceTranscript: String = ""
    @Published var showingSettings: Bool = false
    @Published var showingHelp: Bool = false
    @Published var isDarkMode: Bool = true
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() { loadProgress() }
    
    var progress: Double { Double(currentPhase.stepNumber) / 6.0 }
    
    var allSelectedTasks: [SOTask] {
        suggestedDailyTasks.filter { $0.isSelected } + suggestedRecurringTasks.filter { $0.isSelected } + customTasks
    }
    
    var taskCountByFrequency: [SOFrequency: Int] {
        var counts: [SOFrequency: Int] = [:]
        for task in allSelectedTasks { counts[task.frequency, default: 0] += 1 }
        return counts
    }
    
    // MARK: - Navigation
    
    func nextPhase() {
        switch currentPhase {
        case .aboutYou:
            generateDetailedQuestions()
            currentPhase = .detailedInfo
        case .detailedInfo:
            generateDailyTasks()
            currentPhase = .dailyTasks
        case .dailyTasks:
            generateRecurringTasks()
            currentPhase = .recurringTasks
        case .recurringTasks:
            generateMemoryQuestions()
            generateTaskBubbles()
            currentPhase = .memoryHelper
        case .memoryHelper:
            currentPhase = .reviewTasks
        case .reviewTasks:
            completeOnboarding()
        }
        saveProgress()
    }
    
    func previousPhase() {
        switch currentPhase {
        case .aboutYou: break
        case .detailedInfo: currentPhase = .aboutYou
        case .dailyTasks: currentPhase = .detailedInfo
        case .recurringTasks: currentPhase = .dailyTasks
        case .memoryHelper: currentPhase = .recurringTasks
        case .reviewTasks: currentPhase = .memoryHelper
        }
        saveProgress()
    }
    
    var canGoBack: Bool { currentPhase != .aboutYou }
    
    // MARK: - Dependent Management
    
    func addKid() {
        guard !editingKid.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        editingKid.name = editingKid.name.trimmingCharacters(in: .whitespaces)
        if let index = editingKidIndex {
            userProfile.kids[index] = editingKid
        } else {
            userProfile.kids.append(editingKid)
        }
        editingKid = SOKid()
        editingKidIndex = nil
        showingKidEditor = false
        saveProgress()
    }
    
    func editKid(_ kid: SOKid) {
        if let index = userProfile.kids.firstIndex(where: { $0.id == kid.id }) {
            editingKid = kid
            editingKidIndex = index
            showingKidEditor = true
        }
    }
    
    func removeKid(_ kid: SOKid) {
        userProfile.kids.removeAll { $0.id == kid.id }
        suggestedDailyTasks.removeAll { $0.relatedDependentId == kid.id }
        suggestedRecurringTasks.removeAll { $0.relatedDependentId == kid.id }
        saveProgress()
    }
    
    func addPet() {
        guard !editingPet.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        editingPet.name = editingPet.name.trimmingCharacters(in: .whitespaces)
        if let index = editingPetIndex {
            userProfile.pets[index] = editingPet
        } else {
            userProfile.pets.append(editingPet)
        }
        editingPet = SOPet()
        editingPetIndex = nil
        showingPetEditor = false
        saveProgress()
    }
    
    func editPet(_ pet: SOPet) {
        if let index = userProfile.pets.firstIndex(where: { $0.id == pet.id }) {
            editingPet = pet
            editingPetIndex = index
            showingPetEditor = true
        }
    }
    
    func removePet(_ pet: SOPet) {
        userProfile.pets.removeAll { $0.id == pet.id }
        suggestedDailyTasks.removeAll { $0.relatedDependentId == pet.id }
        suggestedRecurringTasks.removeAll { $0.relatedDependentId == pet.id }
        saveProgress()
    }
    
    func addParent() {
        guard !editingParent.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        editingParent.name = editingParent.name.trimmingCharacters(in: .whitespaces)
        if let index = editingParentIndex {
            userProfile.dependentParents[index] = editingParent
        } else {
            userProfile.dependentParents.append(editingParent)
        }
        editingParent = SOParent()
        editingParentIndex = nil
        showingParentEditor = false
        saveProgress()
    }
    
    func editParent(_ parent: SOParent) {
        if let index = userProfile.dependentParents.firstIndex(where: { $0.id == parent.id }) {
            editingParent = parent
            editingParentIndex = index
            showingParentEditor = true
        }
    }
    
    func removeParent(_ parent: SOParent) {
        userProfile.dependentParents.removeAll { $0.id == parent.id }
        suggestedDailyTasks.removeAll { $0.relatedDependentId == parent.id }
        suggestedRecurringTasks.removeAll { $0.relatedDependentId == parent.id }
        saveProgress()
    }
    
    // MARK: - Vehicle Management
    
    func addVehicle() {
        if editingVehicleIndex != nil {
            userProfile.vehicles[editingVehicleIndex!] = editingVehicle
            editingVehicleIndex = nil
        } else if !editingVehicle.name.isEmpty {
            userProfile.vehicles.append(editingVehicle)
        }
        editingVehicle = SOVehicle()
        showingVehicleEditor = false
        saveProgress()
    }
    
    func editVehicle(_ vehicle: SOVehicle) {
        if let index = userProfile.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            editingVehicle = vehicle
            editingVehicleIndex = index
            showingVehicleEditor = true
        }
    }
    
    func removeVehicle(_ vehicle: SOVehicle) {
        userProfile.vehicles.removeAll { $0.id == vehicle.id }
        saveProgress()
    }
    
    // MARK: - Generate Detailed Info Questions
    
    func generateDetailedQuestions() {
        detailedInfoQuestions = [
            SODetailedQuestion(
                question: "Do you own or lease any vehicles?",
                questionType: .yesNo(followUp: "Add your vehicles below")
            ),
            SODetailedQuestion(
                question: "What type of home do you live in?",
                questionType: .selection(["House", "Condo", "Apartment", "Townhouse", "Mobile Home", "Other"])
            ),
            SODetailedQuestion(
                question: "Do you have a yard or outdoor space?",
                questionType: .yesNo(followUp: nil)
            ),
            SODetailedQuestion(
                question: "Do you have a pool?",
                questionType: .yesNo(followUp: nil)
            ),
            SODetailedQuestion(
                question: "Do you have a garage?",
                questionType: .yesNo(followUp: nil)
            ),
            SODetailedQuestion(
                question: "Do you work from home?",
                questionType: .yesNo(followUp: nil)
            ),
            SODetailedQuestion(
                question: "What is your occupation? (optional)",
                questionType: .freeText
            )
        ]
        currentDetailedQuestionIndex = 0
    }
    
    func answerDetailedQuestion(answer: String, yesNo: Bool? = nil) {
        guard currentDetailedQuestionIndex < detailedInfoQuestions.count else { return }
        
        detailedInfoQuestions[currentDetailedQuestionIndex].isAnswered = true
        detailedInfoQuestions[currentDetailedQuestionIndex].answer = answer
        
        // Apply answer to profile
        let question = detailedInfoQuestions[currentDetailedQuestionIndex]
        switch currentDetailedQuestionIndex {
        case 0: // Vehicles
            if yesNo == true { showingVehicleEditor = true }
        case 1: // Housing type
            userProfile.housingType = answer
        case 2: // Yard
            userProfile.hasYard = yesNo ?? false
        case 3: // Pool
            userProfile.hasPool = yesNo ?? false
        case 4: // Garage
            userProfile.hasGarage = yesNo ?? false
        case 5: // Work from home
            userProfile.worksFromHome = yesNo ?? false
        case 6: // Occupation
            userProfile.occupation = answer
        default:
            break
        }
        
        currentDetailedQuestionIndex += 1
        saveProgress()
    }
    
    // MARK: - Task Generation (Bubble Style - 50+ tasks ordered by commonality)
    
    func generateDailyTasks() {
        suggestedDailyTasks = []
        
        // Build comprehensive daily task list based on profile
        // Ordered by commonality from research data
        var allTasks: [(title: String, category: SOCategory, priority: SOPriority, duration: Int, relevanceScore: Int)] = []
        
        let age = userProfile.age
        let hasKids = userProfile.hasKids
        let hasPets = userProfile.hasPets
        let hasParents = userProfile.hasParents
        
        // === UNIVERSAL DAILY TASKS (Everyone does these) ===
        // Morning routine - highest frequency
        allTasks.append(("Brush teeth (morning)", .morning, .high, 3, 100))
        allTasks.append(("Use bathroom", .morning, .high, 5, 100))
        allTasks.append(("Wash face", .morning, .medium, 3, 98))
        allTasks.append(("Get dressed", .morning, .medium, 10, 97))
        allTasks.append(("Eat breakfast", .morning, .high, 20, 95))
        allTasks.append(("Make coffee/tea", .morning, .medium, 5, 90))
        allTasks.append(("Check phone/messages", .personal, .low, 10, 95))
        allTasks.append(("Shower", .morning, .medium, 15, 85))
        allTasks.append(("Apply deodorant", .morning, .medium, 1, 95))
        allTasks.append(("Comb/style hair", .morning, .low, 5, 90))
        allTasks.append(("Make bed", .home, .low, 3, 75))
        
        // Meals - universal
        allTasks.append(("Eat lunch", .personal, .medium, 30, 95))
        allTasks.append(("Eat dinner", .night, .medium, 30, 95))
        allTasks.append(("Drink water (8 glasses)", .health, .medium, 0, 85))
        allTasks.append(("Prepare meals", .home, .medium, 45, 80))
        
        // Evening routine - universal
        allTasks.append(("Brush teeth (evening)", .night, .high, 3, 100))
        allTasks.append(("Wash face (evening)", .night, .medium, 3, 90))
        allTasks.append(("Change into pajamas", .night, .low, 5, 85))
        allTasks.append(("Set alarm", .night, .medium, 1, 80))
        allTasks.append(("Charge phone", .night, .low, 1, 90))
        allTasks.append(("Lock doors", .night, .high, 2, 85))
        
        // === AGE-BASED TASKS ===
        if age >= 18 && age < 65 {
            // Working age adults
            allTasks.append(("Commute to work", .work, .high, 30, 85))
            allTasks.append(("Check work email", .work, .high, 15, 90))
            allTasks.append(("Attend meetings", .work, .medium, 60, 75))
            allTasks.append(("Complete work tasks", .work, .high, 240, 85))
            allTasks.append(("Take lunch break", .work, .medium, 30, 80))
            allTasks.append(("Commute home", .work, .high, 30, 85))
            allTasks.append(("Review calendar", .work, .medium, 5, 70))
            allTasks.append(("Respond to messages", .work, .medium, 15, 75))
        }
        
        if age >= 25 {
            allTasks.append(("Check bank account", .finance, .low, 5, 60))
            allTasks.append(("Review to-do list", .personal, .medium, 5, 65))
        }
        
        if age >= 30 {
            allTasks.append(("Take vitamins", .health, .medium, 2, 70))
            allTasks.append(("Stretch/light exercise", .health, .medium, 15, 65))
        }
        
        if age >= 40 {
            allTasks.append(("Take medications", .health, .high, 2, 80))
            allTasks.append(("Check blood pressure", .health, .medium, 5, 50))
            allTasks.append(("Exercise (30 min)", .health, .high, 30, 75))
        }
        
        if age >= 50 {
            allTasks.append(("Morning walk", .health, .high, 30, 80))
            allTasks.append(("Monitor health metrics", .health, .medium, 5, 60))
            allTasks.append(("Take supplements", .health, .medium, 2, 70))
        }
        
        if age >= 60 {
            allTasks.append(("Light stretching", .health, .medium, 15, 75))
            allTasks.append(("Call family member", .social, .medium, 15, 70))
            allTasks.append(("Read newspaper/news", .personal, .low, 20, 65))
        }
        
        // Young adults (18-30)
        if age >= 18 && age < 30 {
            allTasks.append(("Check social media", .personal, .low, 15, 85))
            allTasks.append(("Go to gym", .health, .medium, 60, 60))
            allTasks.append(("Study/learn", .personal, .medium, 60, 55))
        }
        
        // === GENDER-BASED TASKS ===
        if userProfile.gender == "female" {
            allTasks.append(("Skincare routine (AM)", .morning, .medium, 10, 80))
            allTasks.append(("Skincare routine (PM)", .night, .medium, 10, 80))
            allTasks.append(("Apply makeup", .morning, .low, 15, 65))
            allTasks.append(("Remove makeup", .night, .medium, 5, 70))
        }
        if userProfile.gender == "male" {
            allTasks.append(("Shave", .morning, .low, 10, 60))
        }
        
        // === KID-RELATED TASKS ===
        if hasKids {
            for kid in userProfile.kids {
                let kidAge = kid.age
                let name = kid.name
                
                // Universal kid tasks - use "Help" prefix for assistance tasks
                allTasks.append(("Wake up \(name)", .kids, .high, 5, 95))
                allTasks.append(("Help \(name) brush teeth (AM)", .kids, .high, 5, 95))
                allTasks.append(("Prepare \(name)'s breakfast", .kids, .high, 15, 90))
                allTasks.append(("Help \(name) brush teeth (PM)", .kids, .high, 5, 95))
                allTasks.append(("Put \(name) to bed", .kids, .high, 15, 95))
                
                if kidAge < 5 {
                    // Toddler/baby tasks
                    allTasks.append(("Change \(name)'s diaper", .kids, .high, 5, 95))
                    allTasks.append(("Feed \(name)", .kids, .high, 20, 95))
                    allTasks.append(("\(name)'s nap time", .kids, .high, 90, 90))
                    allTasks.append(("Help \(name) with bath", .kids, .high, 20, 85))
                    allTasks.append(("Play with \(name)", .kids, .medium, 30, 85))
                    allTasks.append(("Prepare \(name)'s bottles", .kids, .high, 10, 80))
                }
                
                if kidAge >= 5 && kidAge <= 12 {
                    // School-age kids
                    allTasks.append(("Pack \(name)'s lunch", .kids, .high, 10, 90))
                    allTasks.append(("Drop \(name) at school", .kids, .high, 20, 90))
                    allTasks.append(("Pick up \(name) from school", .kids, .high, 20, 90))
                    allTasks.append(("Help \(name) with homework", .kids, .medium, 45, 85))
                    allTasks.append(("Check \(name)'s backpack", .kids, .medium, 5, 75))
                    allTasks.append(("Help \(name) with bath time", .kids, .medium, 20, 85))
                    allTasks.append(("Read to \(name)", .kids, .medium, 15, 80))
                    allTasks.append(("Help \(name) get dressed", .kids, .low, 5, 70))
                    allTasks.append(("Manage \(name)'s screen time", .kids, .low, 0, 65))
                }
                
                if kidAge >= 13 && kidAge <= 18 {
                    // Teenagers
                    allTasks.append(("Check in with \(name)", .kids, .medium, 10, 80))
                    allTasks.append(("Drive \(name) to activities", .kids, .medium, 30, 75))
                    allTasks.append(("Help \(name) with homework", .kids, .medium, 30, 70))
                    allTasks.append(("Family dinner with \(name)", .kids, .medium, 30, 75))
                }
            }
        }
        
        // === PET-RELATED TASKS ===
        if hasPets {
            for pet in userProfile.pets {
                let name = pet.name
                let type = pet.petType.lowercased()
                
                allTasks.append(("Feed \(name)", .pets, .high, 5, 95))
                allTasks.append(("Fresh water for \(name)", .pets, .high, 2, 95))
                
                if type == "dog" {
                    allTasks.append(("Walk \(name) (morning)", .pets, .high, 20, 95))
                    allTasks.append(("Walk \(name) (evening)", .pets, .high, 20, 95))
                    allTasks.append(("Let \(name) out", .pets, .high, 5, 90))
                    allTasks.append(("Play with \(name)", .pets, .medium, 15, 80))
                    allTasks.append(("Brush \(name)", .pets, .low, 10, 50))
                    allTasks.append(("Train \(name)", .pets, .low, 15, 40))
                }
                
                if type == "cat" {
                    allTasks.append(("Clean \(name)'s litter box", .pets, .high, 5, 90))
                    allTasks.append(("Play with \(name)", .pets, .medium, 15, 75))
                    allTasks.append(("Brush \(name)", .pets, .low, 10, 45))
                }
                
                if type == "fish" {
                    allTasks.append(("Check \(name)'s tank", .pets, .medium, 2, 80))
                }
                
                if type == "bird" {
                    allTasks.append(("Clean \(name)'s cage", .pets, .medium, 10, 75))
                    allTasks.append(("Let \(name) out of cage", .pets, .low, 30, 60))
                }
            }
        }
        
        // === ELDER CARE TASKS ===
        if hasParents {
            for parent in userProfile.dependentParents {
                let name = parent.name
                
                allTasks.append(("Check on \(name)", .elderCare, .high, 15, 95))
                allTasks.append(("Call \(name)", .elderCare, .high, 15, 90))
                
                if parent.livesWithYou {
                    allTasks.append(("Help \(name) with breakfast", .elderCare, .high, 20, 95))
                    allTasks.append(("Give \(name) medications", .elderCare, .high, 5, 95))
                    allTasks.append(("Help \(name) with meals", .elderCare, .high, 30, 90))
                    allTasks.append(("Assist \(name) with mobility", .elderCare, .medium, 15, 85))
                    allTasks.append(("Help \(name) get dressed", .elderCare, .medium, 15, 80))
                    allTasks.append(("Monitor \(name)'s health", .elderCare, .high, 10, 85))
                }
            }
        }
        
        // === COMMON OPTIONAL DAILY TASKS ===
        allTasks.append(("Check weather", .personal, .low, 2, 70))
        allTasks.append(("Pack bag/briefcase", .personal, .medium, 5, 65))
        allTasks.append(("Water plants", .home, .low, 5, 45))
        allTasks.append(("Quick tidy up", .home, .low, 15, 60))
        allTasks.append(("Load/unload dishwasher", .home, .low, 10, 65))
        allTasks.append(("Take out trash", .home, .low, 5, 50))
        allTasks.append(("Do dishes", .home, .medium, 15, 70))
        allTasks.append(("Wipe down counters", .home, .low, 5, 55))
        allTasks.append(("Check mail", .errands, .low, 5, 60))
        allTasks.append(("Meditate", .health, .low, 15, 40))
        allTasks.append(("Journal", .personal, .low, 15, 35))
        allTasks.append(("Read", .personal, .low, 30, 55))
        allTasks.append(("Watch TV/streaming", .personal, .low, 60, 75))
        allTasks.append(("Scroll social media", .personal, .low, 20, 70))
        allTasks.append(("Exercise", .health, .medium, 45, 55))
        allTasks.append(("Yoga", .health, .low, 30, 35))
        allTasks.append(("Evening walk", .health, .low, 20, 45))
        allTasks.append(("Plan tomorrow", .personal, .medium, 10, 50))
        allTasks.append(("Prep clothes for tomorrow", .personal, .low, 5, 45))
        allTasks.append(("Wind down routine", .night, .medium, 30, 60))
        
        // Sort by relevance score (most common first)
        allTasks.sort { $0.relevanceScore > $1.relevanceScore }
        
        // Convert to SOTask objects (as bubbles - not pre-selected)
        for task in allTasks {
            suggestedDailyTasks.append(SOTask(
                title: task.title,
                frequency: .daily,
                duration: task.duration,
                priority: task.priority,
                category: task.category,
                isSelected: false  // Start unselected - user picks what they want
            ))
        }
    }
    
    func generateRecurringTasks() {
        suggestedRecurringTasks = []
        
        var allTasks: [(title: String, frequency: SOFrequency, category: SOCategory, priority: SOPriority, duration: Int, relevanceScore: Int)] = []
        
        let age = userProfile.age
        let hasKids = userProfile.hasKids
        let hasPets = userProfile.hasPets
        let hasParents = userProfile.hasParents
        
        // === WEEKLY TASKS (Most common household tasks) ===
        allTasks.append(("Do laundry", .weekly, .home, .high, 90, 95))
        allTasks.append(("Grocery shopping", .weekly, .errands, .high, 60, 95))
        allTasks.append(("Vacuum floors", .weekly, .home, .medium, 30, 85))
        allTasks.append(("Mop floors", .weekly, .home, .medium, 30, 75))
        allTasks.append(("Clean bathroom", .weekly, .home, .medium, 30, 80))
        allTasks.append(("Change bed sheets", .weekly, .home, .medium, 20, 80))
        allTasks.append(("Take out recycling", .weekly, .home, .low, 10, 75))
        allTasks.append(("Meal prep Sunday", .weekly, .home, .medium, 90, 60))
        allTasks.append(("Dust surfaces", .weekly, .home, .low, 20, 65))
        allTasks.append(("Clean kitchen", .weekly, .home, .medium, 30, 75))
        allTasks.append(("Wipe appliances", .weekly, .home, .low, 15, 55))
        allTasks.append(("Organize clutter", .weekly, .home, .low, 30, 50))
        allTasks.append(("Water all plants", .weekly, .home, .low, 15, 45))
        allTasks.append(("Review weekly calendar", .weekly, .personal, .medium, 15, 70))
        allTasks.append(("Call parents/family", .weekly, .social, .medium, 30, 65))
        allTasks.append(("Date night", .weekly, .social, .medium, 120, 55))
        allTasks.append(("Wash car", .weekly, .errands, .low, 30, 40))
        allTasks.append(("Fill gas tank", .weekly, .errands, .medium, 15, 70))
        allTasks.append(("Check car fluids", .weekly, .errands, .low, 10, 35))
        allTasks.append(("Exercise routine", .weekly, .health, .medium, 60, 60))
        allTasks.append(("Weigh yourself", .weekly, .health, .low, 2, 45))
        allTasks.append(("Backup phone/computer", .weekly, .personal, .low, 15, 40))
        allTasks.append(("Review finances", .weekly, .finance, .medium, 30, 55))
        
        // Working adults
        if age >= 18 && age < 65 {
            allTasks.append(("Review work week", .weekly, .work, .medium, 30, 65))
            allTasks.append(("Prepare work clothes", .weekly, .work, .low, 15, 55))
            allTasks.append(("Update resume/LinkedIn", .weekly, .work, .low, 30, 25))
        }
        
        // Kid-related weekly
        if hasKids {
            for kid in userProfile.kids {
                let name = kid.name
                if kid.age >= 5 && kid.age <= 18 {
                    allTasks.append(("\(name)'s activity/sports", .weekly, .kids, .high, 60, 85))
                    allTasks.append(("\(name)'s playdate", .weekly, .kids, .medium, 120, 70))
                    allTasks.append(("Check \(name)'s grades", .weekly, .kids, .medium, 15, 65))
                    allTasks.append(("Family activity with \(name)", .weekly, .kids, .medium, 120, 75))
                }
            }
            allTasks.append(("Kids' laundry", .weekly, .kids, .high, 60, 85))
            allTasks.append(("Clean kids' rooms", .weekly, .kids, .medium, 30, 70))
            allTasks.append(("Organize toys", .weekly, .kids, .low, 30, 55))
        }
        
        // Pet-related weekly
        if hasPets {
            for pet in userProfile.pets {
                let name = pet.name
                if pet.petType.lowercased() == "dog" {
                    allTasks.append(("Bathe \(name)", .weekly, .pets, .medium, 30, 70))
                    allTasks.append(("Brush \(name)", .weekly, .pets, .low, 15, 60))
                    allTasks.append(("\(name) to dog park", .weekly, .pets, .low, 60, 50))
                }
                if pet.petType.lowercased() == "cat" {
                    allTasks.append(("Deep clean \(name)'s litter", .weekly, .pets, .medium, 15, 75))
                }
                if pet.petType.lowercased() == "fish" {
                    allTasks.append(("Clean \(name)'s tank", .weekly, .pets, .medium, 30, 80))
                }
            }
            allTasks.append(("Buy pet food", .weekly, .pets, .high, 20, 75))
        }
        
        // Elder care weekly
        if hasParents {
            for parent in userProfile.dependentParents {
                let name = parent.name
                allTasks.append(("Visit \(name)", .weekly, .elderCare, .high, 120, 85))
                allTasks.append(("Call \(name)", .weekly, .elderCare, .high, 30, 90))
                allTasks.append(("Help \(name) with errands", .weekly, .elderCare, .medium, 60, 70))
            }
        }
        
        // === MONTHLY TASKS ===
        allTasks.append(("Pay rent/mortgage", .monthly, .finance, .high, 15, 95))
        allTasks.append(("Pay utility bills", .monthly, .finance, .high, 15, 95))
        allTasks.append(("Pay credit cards", .monthly, .finance, .high, 15, 90))
        allTasks.append(("Review budget", .monthly, .finance, .medium, 30, 75))
        allTasks.append(("Check subscriptions", .monthly, .finance, .low, 15, 60))
        allTasks.append(("Balance checkbook", .monthly, .finance, .low, 20, 50))
        allTasks.append(("Review bank statements", .monthly, .finance, .medium, 20, 65))
        allTasks.append(("Deep clean house", .monthly, .home, .medium, 180, 70))
        allTasks.append(("Clean refrigerator", .monthly, .home, .low, 30, 60))
        allTasks.append(("Clean oven", .monthly, .home, .low, 30, 45))
        allTasks.append(("Wash windows", .monthly, .home, .low, 45, 40))
        allTasks.append(("Clean garage", .monthly, .home, .low, 120, 35))
        allTasks.append(("HVAC filter change", .monthly, .home, .medium, 15, 65))
        allTasks.append(("Test smoke detectors", .monthly, .home, .high, 10, 60))
        allTasks.append(("Haircut", .monthly, .personal, .medium, 45, 75))
        allTasks.append(("Self-care day", .monthly, .personal, .low, 120, 50))
        allTasks.append(("Oil change", .monthly, .errands, .high, 30, 60))
        allTasks.append(("Car wash (detail)", .monthly, .errands, .low, 60, 40))
        allTasks.append(("Refill prescriptions", .monthly, .health, .high, 20, 70))
        
        if age >= 30 {
            allTasks.append(("Review investments", .monthly, .finance, .medium, 30, 55))
            allTasks.append(("Check retirement accounts", .monthly, .finance, .low, 15, 50))
        }
        
        // Kid-related monthly
        if hasKids {
            for kid in userProfile.kids {
                let name = kid.name
                allTasks.append(("\(name)'s allowance", .monthly, .kids, .low, 5, 60))
            }
            allTasks.append(("Sort kids' outgrown clothes", .monthly, .kids, .low, 30, 55))
            allTasks.append(("Kids' activity fees", .monthly, .finance, .medium, 15, 65))
        }
        
        // Pet-related monthly
        if hasPets {
            for pet in userProfile.pets {
                let name = pet.name
                if pet.petType.lowercased() == "dog" {
                    allTasks.append(("\(name) grooming", .monthly, .pets, .medium, 60, 70))
                    allTasks.append(("\(name) flea/tick treatment", .monthly, .pets, .high, 10, 75))
                }
            }
            allTasks.append(("Buy pet supplies", .monthly, .pets, .medium, 30, 70))
        }
        
        // Elder care monthly
        if hasParents {
            for parent in userProfile.dependentParents {
                let name = parent.name
                allTasks.append(("Refill \(name)'s meds", .monthly, .elderCare, .high, 30, 90))
                allTasks.append(("\(name) doctor visit", .monthly, .elderCare, .high, 120, 80))
            }
        }
        
        // === YEARLY TASKS ===
        allTasks.append(("File taxes", .yearly, .finance, .high, 240, 98))
        allTasks.append(("Annual physical", .yearly, .health, .high, 90, 90))
        allTasks.append(("Dentist checkup", .yearly, .health, .high, 60, 90))
        allTasks.append(("Eye exam", .yearly, .health, .medium, 60, 75))
        allTasks.append(("Renew car registration", .yearly, .errands, .high, 30, 90))
        allTasks.append(("Renew license", .yearly, .errands, .high, 60, 60))
        allTasks.append(("Car inspection", .yearly, .errands, .high, 60, 80))
        allTasks.append(("Review insurance policies", .yearly, .finance, .medium, 60, 65))
        allTasks.append(("Update emergency contacts", .yearly, .personal, .medium, 15, 50))
        allTasks.append(("Flu shot", .yearly, .health, .high, 30, 80))
        allTasks.append(("Deep clean carpets", .yearly, .home, .low, 180, 50))
        allTasks.append(("Service HVAC", .yearly, .home, .medium, 120, 60))
        allTasks.append(("Clean gutters", .yearly, .home, .medium, 120, 55))
        allTasks.append(("Winterize home", .yearly, .home, .medium, 120, 50))
        allTasks.append(("Spring cleaning", .yearly, .home, .medium, 240, 65))
        allTasks.append(("Review will/estate", .yearly, .finance, .low, 60, 40))
        allTasks.append(("Birthday - self", .yearly, .social, .medium, 0, 70))
        
        if age >= 40 {
            allTasks.append(("Mammogram/PSA test", .yearly, .health, .high, 60, 75))
            allTasks.append(("Colonoscopy prep", .yearly, .health, .high, 120, 50))
        }
        
        if age >= 50 {
            allTasks.append(("Medicare review", .yearly, .health, .high, 60, 60))
        }
        
        // Kid-related yearly
        if hasKids {
            for kid in userProfile.kids {
                let name = kid.name
                allTasks.append(("\(name)'s birthday", .yearly, .kids, .high, 180, 95))
                allTasks.append(("\(name)'s doctor checkup", .yearly, .kids, .high, 90, 90))
                allTasks.append(("\(name)'s dentist", .yearly, .kids, .high, 60, 85))
                if kid.age >= 5 && kid.age <= 18 {
                    allTasks.append(("Buy \(name)'s school supplies", .yearly, .kids, .high, 60, 85))
                    allTasks.append(("Back to school clothes", .yearly, .kids, .high, 120, 80))
                    allTasks.append(("School registration", .yearly, .kids, .high, 30, 75))
                }
            }
        }
        
        // Pet-related yearly
        if hasPets {
            for pet in userProfile.pets {
                let name = pet.name
                allTasks.append(("\(name) vet checkup", .yearly, .pets, .high, 60, 90))
                allTasks.append(("\(name) vaccinations", .yearly, .pets, .high, 30, 90))
                allTasks.append(("\(name) license renewal", .yearly, .pets, .high, 15, 75))
            }
        }
        
        // Sort by relevance score
        allTasks.sort { $0.relevanceScore > $1.relevanceScore }
        
        // Convert to SOTask objects
        for task in allTasks {
            suggestedRecurringTasks.append(SOTask(
                title: task.title,
                frequency: task.frequency,
                duration: task.duration,
                priority: task.priority,
                category: task.category,
                isSelected: false
            ))
        }
    }
    
    func generateMemoryQuestions() {
        memoryQuestions = []
        currentQuestionIndex = 0
        
        // Universal questions
        memoryQuestions.append(SOQuestion(question: "Do you take any medications regularly?", category: .health, suggestedTaskTitle: "Take medication"))
        memoryQuestions.append(SOQuestion(question: "Do you exercise or go to the gym?", category: .health, suggestedTaskTitle: "Exercise/Gym"))
        memoryQuestions.append(SOQuestion(question: "Do you have any subscriptions to review?", category: .finance, suggestedTaskTitle: "Review subscriptions"))
        memoryQuestions.append(SOQuestion(question: "Do you have plants that need watering?", category: .home, suggestedTaskTitle: "Water plants"))
        memoryQuestions.append(SOQuestion(question: "Do you want to schedule time for hobbies?", category: .personal, suggestedTaskTitle: "Hobby time"))
        
        // Vehicle-based questions
        for vehicle in userProfile.vehicles {
            memoryQuestions.append(SOQuestion(question: "Does \(vehicle.name.isEmpty ? "your vehicle" : vehicle.name) need an oil change soon?", category: .errands, suggestedTaskTitle: "Oil change - \(vehicle.name.isEmpty ? "Vehicle" : vehicle.name)"))
            memoryQuestions.append(SOQuestion(question: "Is \(vehicle.name.isEmpty ? "your vehicle" : vehicle.name) due for registration renewal?", category: .errands, suggestedTaskTitle: "Registration - \(vehicle.name.isEmpty ? "Vehicle" : vehicle.name)"))
        }
        
        // House-based questions
        if userProfile.housingType == "House" || userProfile.housingType == "Townhouse" {
            if userProfile.hasYard {
                memoryQuestions.append(SOQuestion(question: "Does your lawn need regular mowing?", category: .home, suggestedTaskTitle: "Mow lawn"))
                memoryQuestions.append(SOQuestion(question: "Do you have a garden to tend?", category: .home, suggestedTaskTitle: "Garden maintenance"))
            }
            if userProfile.hasPool {
                memoryQuestions.append(SOQuestion(question: "Does your pool need regular cleaning?", category: .home, suggestedTaskTitle: "Clean pool"))
                memoryQuestions.append(SOQuestion(question: "Do you need to check pool chemicals?", category: .home, suggestedTaskTitle: "Check pool chemicals"))
            }
            if userProfile.hasGarage {
                memoryQuestions.append(SOQuestion(question: "Does your garage need organizing?", category: .home, suggestedTaskTitle: "Organize garage"))
            }
        }
        
        // Kid-based questions
        if userProfile.hasKids {
            memoryQuestions.append(SOQuestion(question: "Do your kids have extracurricular activities?", category: .kids, suggestedTaskTitle: "Kids' activity"))
            memoryQuestions.append(SOQuestion(question: "Do you need to schedule playdates?", category: .kids, suggestedTaskTitle: "Arrange playdate"))
            for kid in userProfile.kids where kid.age >= 5 && kid.age <= 12 {
                memoryQuestions.append(SOQuestion(question: "Does \(kid.name) have homework to help with?", category: .kids, suggestedTaskTitle: "Help \(kid.name) with homework"))
            }
        }
        
        // Pet-based questions
        for pet in userProfile.pets {
            if pet.petType.lowercased() == "dog" {
                memoryQuestions.append(SOQuestion(question: "Is \(pet.name) due for grooming?", category: .pets, suggestedTaskTitle: "Groom \(pet.name)"))
            }
            memoryQuestions.append(SOQuestion(question: "Is \(pet.name) due for a vet visit?", category: .pets, suggestedTaskTitle: "\(pet.name) vet appointment"))
        }
        
        // Work-from-home questions
        if userProfile.worksFromHome {
            memoryQuestions.append(SOQuestion(question: "Do you have regular video meetings to prepare for?", category: .work, suggestedTaskTitle: "Prepare for meetings"))
        }
        
        // Parent-based questions
        for parent in userProfile.dependentParents {
            memoryQuestions.append(SOQuestion(question: "Does \(parent.name) have doctor appointments to schedule?", category: .elderCare, suggestedTaskTitle: "\(parent.name) doctor appointment"))
        }
    }
    
    func generateTaskBubbles() {
        taskBubbles = []
        
        // Universal bubbles
        taskBubbles.append(contentsOf: [
            SOBubble(title: "Doctor appointment", category: .health),
            SOBubble(title: "Haircut", category: .personal),
            SOBubble(title: "Pay bills", category: .finance),
            SOBubble(title: "Meal prep", category: .home),
            SOBubble(title: "Call family", category: .social),
            SOBubble(title: "Meditate", category: .health)
        ])
        
        // Vehicle-related bubbles
        if !userProfile.vehicles.isEmpty {
            taskBubbles.append(contentsOf: [
                SOBubble(title: "Wash car", category: .errands),
                SOBubble(title: "Car inspection", category: .errands),
                SOBubble(title: "Fill gas", category: .errands)
            ])
        }
        
        // Home-related bubbles
        if userProfile.housingType == "House" || userProfile.housingType == "Townhouse" {
            if userProfile.hasYard {
                taskBubbles.append(contentsOf: [
                    SOBubble(title: "Yard work", category: .home),
                    SOBubble(title: "Trim hedges", category: .home)
                ])
            }
            if userProfile.hasPool {
                taskBubbles.append(SOBubble(title: "Pool maintenance", category: .home))
            }
            taskBubbles.append(SOBubble(title: "Home repair", category: .home))
        }
        
        // Kid-related bubbles
        if userProfile.hasKids {
            taskBubbles.append(contentsOf: [
                SOBubble(title: "School supplies", category: .kids),
                SOBubble(title: "Kids' clothes shopping", category: .kids),
                SOBubble(title: "Plan birthday party", category: .kids)
            ])
        }
        
        // Pet-related bubbles
        if userProfile.hasPets {
            taskBubbles.append(contentsOf: [
                SOBubble(title: "Buy pet food", category: .pets),
                SOBubble(title: "Pet grooming", category: .pets)
            ])
        }
        
        // Work-related bubbles
        if userProfile.worksFromHome {
            taskBubbles.append(contentsOf: [
                SOBubble(title: "Organize workspace", category: .work),
                SOBubble(title: "Update resume", category: .work)
            ])
        }
    }
    
    func removeCustomTask(_ task: SOTask) {
        customTasks.removeAll { $0.id == task.id }
        saveProgress()
    }
    
    // MARK: - Memory Helper
    
    var currentMemoryQuestion: SOQuestion? {
        guard currentQuestionIndex < memoryQuestions.count else { return nil }
        return memoryQuestions[currentQuestionIndex]
    }
    
    func answerMemoryQuestion(yes: Bool) {
        guard currentQuestionIndex < memoryQuestions.count else { return }
        memoryQuestions[currentQuestionIndex].isAnswered = true
        memoryQuestions[currentQuestionIndex].answeredYes = yes
        
        if yes {
            let question = memoryQuestions[currentQuestionIndex]
            let priority = determinePriority(for: question.suggestedTaskTitle)
            editingTask = SOTask(title: question.suggestedTaskTitle, frequency: .once, priority: priority, category: question.category)
            showingMemoryTaskEditor = true
        } else {
            moveToNextQuestion()
        }
    }
    
    func selectTaskBubble(_ bubble: SOBubble) {
        let priority = determinePriority(for: bubble.title)
        editingTask = SOTask(title: bubble.title, frequency: .once, priority: priority, category: bubble.category)
        showingMemoryTaskEditor = true
        taskBubbles.removeAll { $0.id == bubble.id }
    }
    
    // AI-based priority determination
    func determinePriority(for taskTitle: String) -> SOPriority {
        let title = taskTitle.lowercased()
        
        // LOW PRIORITY - Check first (hygiene basics, leisure, optional tasks)
        let lowPriorityKeywords = [
            "brush", "teeth", "floss", "mouthwash", "wash face", "skincare", "lotion",
            "shower", "bath", "shave", "deodorant", "comb", "hair", "bathroom",
            "make bed", "tidy", "organize", "declutter", "sort", "rearrange",
            "hobby", "game", "movie", "tv", "netflix", "streaming", "youtube",
            "social media", "scroll", "browse", "read book", "read article",
            "relax", "nap", "rest", "wind down", "leisure",
            "wash car", "clean garage", "dust", "polish", "decorate",
            "call friend", "text friend", "email personal", "journal", "meditate",
            "stretch", "yoga", "side project", "learn", "practice", "podcast",
            "trim", "water plant", "check weather", "charge phone", "dressed",
            "pajama", "wake up", "get up", "alarm"
        ]
        
        for keyword in lowPriorityKeywords {
            if title.contains(keyword) { return .low }
        }
        
        // HIGH PRIORITY - Health appointments, medications, important deadlines, payments
        let highPriorityKeywords = [
            "doctor", "dentist", "hospital", "emergency", "surgery", "therapy", "treatment",
            "medication", "medicine", "prescription", "refill",
            "appointment", "meeting", "interview", "deadline", "urgent", "important",
            "pay rent", "mortgage", "pay bill", "tax", "insurance", "registration", "renewal",
            "drop off", "pick up", "flight", "travel", "vaccine", "shot", "checkup",
            "vet visit", "exam", "test result"
        ]
        
        for keyword in highPriorityKeywords {
            if title.contains(keyword) { return .high }
        }
        
        // MEDIUM PRIORITY - Everything else (work, meals, chores, exercise, errands)
        return .medium
    }
    
    func saveMemoryTask() {
        guard var task = editingTask else { return }
        task.title = task.title.trimmingCharacters(in: .whitespaces)
        if !task.title.isEmpty { customTasks.append(task) }
        editingTask = nil
        showingMemoryTaskEditor = false
        moveToNextQuestion()
        saveProgress()
    }
    
    func cancelMemoryTask() {
        editingTask = nil
        showingMemoryTaskEditor = false
        moveToNextQuestion()
    }
    
    func moveToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    // MARK: - Task Management
    
    func toggleDailyTask(_ task: SOTask) {
        if let index = suggestedDailyTasks.firstIndex(where: { $0.id == task.id }) {
            suggestedDailyTasks[index].isSelected.toggle()
            saveProgress()
        }
    }
    
    func toggleRecurringTask(_ task: SOTask) {
        if let index = suggestedRecurringTasks.firstIndex(where: { $0.id == task.id }) {
            suggestedRecurringTasks[index].isSelected.toggle()
            saveProgress()
        }
    }
    
    func editTask(_ task: SOTask) {
        editingTask = task
        showingTaskEditor = true
    }
    
    func saveEditedTask() {
        guard let task = editingTask else { return }
        if let index = suggestedDailyTasks.firstIndex(where: { $0.id == task.id }) {
            suggestedDailyTasks[index] = task
        } else if let index = suggestedRecurringTasks.firstIndex(where: { $0.id == task.id }) {
            suggestedRecurringTasks[index] = task
        } else if let index = customTasks.firstIndex(where: { $0.id == task.id }) {
            customTasks[index] = task
        }
        editingTask = nil
        showingTaskEditor = false
        saveProgress()
    }
    
    func deleteTask(_ task: SOTask) {
        suggestedDailyTasks.removeAll { $0.id == task.id }
        suggestedRecurringTasks.removeAll { $0.id == task.id }
        customTasks.removeAll { $0.id == task.id }
        saveProgress()
    }
    
    func addCustomTask() {
        editingTask = SOTask(title: "", frequency: .daily, category: .personal)
        showingTaskEditor = true
    }
    
    // MARK: - Voice
    
    func startListening() {
        guard !isListening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                self?.startRecording()
            }
        }
    }
    
    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async { self.voiceTranscript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) { self.stopListening() }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        // Process the transcript if we have one
        let transcript = voiceTranscript
        if !transcript.isEmpty {
            processVoiceInput(transcript)
        }
    }
    
    func processVoiceInput(_ transcript: String) {
        let text = transcript.lowercased()
        print("🎤 Processing voice input: \(text)")
        
        if currentPhase == .aboutYou {
            // Create a mutable copy to batch all changes
            var updatedProfile = userProfile
            let nsText = text as NSString
            
            // ===== USER AGE PARSING =====
            // Look for "I am X year old" pattern
            if let regex = try? NSRegularExpression(pattern: "i\\s+am\\s+(?:a\\s+)?(\\d+)\\s+year", options: .caseInsensitive) {
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                    if match.numberOfRanges >= 2 {
                        let ageStr = nsText.substring(with: match.range(at: 1))
                        if let age = Int(ageStr), age >= 18 && age <= 100 {
                            updatedProfile.age = age
                            print("🎤 Found user age: \(age)")
                        }
                    }
                }
            }
            
            // ===== GENDER PARSING =====
            if text.contains("male") && !text.contains("female") {
                updatedProfile.gender = "male"
                print("🎤 Found gender: male")
            } else if text.contains("female") || text.contains("woman") {
                updatedProfile.gender = "female"
                print("🎤 Found gender: female")
            }
            
            // ===== KID PARSING =====
            // Pattern: "X year old son/daughter named Y"
            if let regex = try? NSRegularExpression(pattern: "(\\d+)[\\s-]+year[\\s-]*old\\s+(son|daughter)\\s+named\\s+([a-z]+)", options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                print("🎤 Kid pattern matches: \(matches.count)")
                for match in matches {
                    if match.numberOfRanges >= 4 {
                        let ageStr = nsText.substring(with: match.range(at: 1))
                        let relation = nsText.substring(with: match.range(at: 2)).lowercased()
                        let name = nsText.substring(with: match.range(at: 3)).capitalized
                        print("🎤 Kid match found: age=\(ageStr), relation=\(relation), name=\(name)")
                        if let age = Int(ageStr), age > 0 && age < 25 {
                            if !updatedProfile.kids.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                                var kid = SOKid()
                                kid.name = name
                                kid.age = age
                                kid.gender = relation == "son" ? "male" : "female"
                                updatedProfile.kids.append(kid)
                                print("🎤 Added kid: \(name), age \(age), \(relation)")
                            }
                        }
                    }
                }
            }
            
            // Also try alternate pattern: "son named X" with age mentioned separately
            if let regex = try? NSRegularExpression(pattern: "(son|daughter)\\s+named\\s+([a-z]+)", options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    if match.numberOfRanges >= 3 {
                        let relation = nsText.substring(with: match.range(at: 1)).lowercased()
                        let name = nsText.substring(with: match.range(at: 2)).capitalized
                        
                        // Skip if already added
                        if updatedProfile.kids.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                            continue
                        }
                        
                        // Look for age BEFORE this match (e.g., "9 year old daughter named kristen")
                        let matchStart = match.range.location
                        let lookbackStart = max(0, matchStart - 25)
                        let lookbackRange = NSRange(location: lookbackStart, length: matchStart - lookbackStart)
                        let lookback = nsText.substring(with: lookbackRange)
                        
                        var kidAge = 10 // default
                        if let ageRegex = try? NSRegularExpression(pattern: "(\\d+)[\\s-]+year", options: .caseInsensitive) {
                            if let ageMatch = ageRegex.firstMatch(in: lookback, options: [], range: NSRange(location: 0, length: lookback.count)) {
                                let ageStr = (lookback as NSString).substring(with: ageMatch.range(at: 1))
                                if let age = Int(ageStr), age > 0 && age < 25 {
                                    kidAge = age
                                    print("🎤 Found age \(age) in lookback: '\(lookback)'")
                                }
                            }
                        }
                        
                        var kid = SOKid()
                        kid.name = name
                        kid.age = kidAge
                        kid.gender = relation == "son" ? "male" : "female"
                        updatedProfile.kids.append(kid)
                        print("🎤 Added kid (alt pattern): \(name), age \(kidAge), \(relation)")
                    }
                }
            }
            
            // NOTE: Pets and parents are added manually on the Detailed Information page
            
            // NOW assign the updated profile in one go - this triggers @Published
            userProfile = updatedProfile
            
            // Save
            saveProgress()
            print("🎤 Profile after parsing - Age: \(userProfile.age), Gender: \(userProfile.gender), Kids: \(userProfile.kids.count)")
            
        } else if currentPhase == .memoryHelper && showingMemoryTaskEditor && editingTask != nil {
            editingTask?.title = transcript
            voiceTranscript = ""
        }
    }
    
    // MARK: - Settings
    
    func resetOnboardingTasks() {
        suggestedDailyTasks = []
        suggestedRecurringTasks = []
        customTasks = []
        currentPhase = .aboutYou
        saveProgress()
    }
    
    func resetAppCompletely() {
        userProfile = SOProfile()
        suggestedDailyTasks = []
        suggestedRecurringTasks = []
        customTasks = []
        memoryQuestions = []
        currentQuestionIndex = 0
        currentPhase = .aboutYou
        clearProgress()
    }
    
    // MARK: - Persistence
    
    private let profileKey = "soProfile"
    private let tasksKey = "soTasks"
    private let onboardingCompleteKey = "soOnboardingComplete"
    
    func saveProgress() {
        if let encoded = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
        let allTasks = suggestedDailyTasks + suggestedRecurringTasks + customTasks
        if let encoded = try? JSONEncoder().encode(allTasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
        UserDefaults.standard.set(currentPhase.rawValue, forKey: "soCurrentPhase")
    }
    
    func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(SOProfile.self, from: data) {
            userProfile = profile
        }
        if let phaseRaw = UserDefaults.standard.string(forKey: "soCurrentPhase"),
           let phase = SOPhase(rawValue: phaseRaw) {
            currentPhase = phase
        }
    }
    
    func clearProgress() {
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: "soCurrentPhase")
        UserDefaults.standard.removeObject(forKey: onboardingCompleteKey)
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
        saveProgress()
    }
    
    var isOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }
}

// MARK: - Views


struct ClaudeSmartOnboardingView: View {
    @StateObject private var manager = ClaudeSmartOnboardingManager()
    @Environment(\.dismiss) private var dismiss
    var onComplete: (([SOTask]) -> Void)?
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.03, blue: 0.12), Color(red: 0.08, green: 0.05, blue: 0.18)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                progressBar.padding(.horizontal, 24).padding(.top, 12)
                mainContent.frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomArea.padding(.bottom, 40)
            }
            
            if manager.showingTaskEditor { SOTaskEditorOverlay(manager: manager) }
            if manager.showingMemoryTaskEditor { SOMemoryTaskEditorOverlay(manager: manager) }
            if manager.showingKidEditor { SOKidEditorOverlay(manager: manager) }
            if manager.showingPetEditor { SOPetEditorOverlay(manager: manager) }
            if manager.showingParentEditor { SOParentEditorOverlay(manager: manager) }
            if manager.showingSettings { SOSettingsOverlay(manager: manager) }
            if manager.showingHelp { SOHelpOverlay(manager: manager) }
        }
        .preferredColorScheme(.dark)
    }
    
    var headerView: some View {
        HStack {
            if manager.canGoBack {
                Button(action: { manager.previousPhase() }) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundColor(.white).frame(width: 44, height: 44)
                }
            } else { Spacer().frame(width: 44) }
            Spacer()
            Text(manager.currentPhase.title).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Spacer()
            Button(action: { manager.showingSettings = true }) {
                Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.7)).frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }
    
    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1)).frame(height: 6)
                RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * manager.progress, height: 6)
            }
        }.frame(height: 6)
    }
    
    @ViewBuilder var mainContent: some View {
        switch manager.currentPhase {
        case .aboutYou: SOAboutYouView(manager: manager)
        case .detailedInfo: SODetailedInfoView(manager: manager)
        case .dailyTasks: SODailyTasksView(manager: manager)
        case .recurringTasks: SORecurringTasksView(manager: manager)
        case .memoryHelper: SOMemoryHelperView(manager: manager)
        case .reviewTasks: SOReviewTasksView(manager: manager, onComplete: onComplete, dismiss: dismiss)
        }
    }
    
    var bottomArea: some View {
        HStack(spacing: 16) {
            // Only show speak button for phases other than aboutYou
            if manager.currentPhase != .aboutYou {
                Button(action: { manager.isListening ? manager.stopListening() : manager.startListening() }) {
                    HStack(spacing: 8) {
                        Image(systemName: manager.isListening ? "waveform.circle.fill" : "mic.circle.fill").font(.system(size: 20))
                        Text(manager.isListening ? "Listening..." : "Speak").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Capsule().fill(manager.isListening ? Color.red.opacity(0.3) : Color.purple.opacity(0.3)))
                    .overlay(Capsule().stroke(manager.isListening ? Color.red : Color.purple, lineWidth: 2))
                }
            }
            
            Button(action: {
                if manager.currentPhase == .reviewTasks {
                    onComplete?(manager.allSelectedTasks)
                    dismiss()
                } else {
                    manager.nextPhase()
                }
            }) {
                Text(continueButtonText).font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)))
            }
        }.padding(.horizontal, 24)
    }
    
    var continueButtonText: String {
        switch manager.currentPhase {
        case .aboutYou: return "Continue"
        case .detailedInfo: return "Next: Daily Tasks"
        case .dailyTasks: return "Next: Recurring Tasks"
        case .recurringTasks: return "Next: Task Questions"
        case .memoryHelper: return "Review All Tasks"
        case .reviewTasks: return "Finish Setup"
        }
    }
}

// MARK: - Screen 1: About You

struct SOAboutYouView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SOAboutYouHeader()
                SOProfileSummaryCard(manager: manager)
                SOVoiceInputSection(manager: manager)
                SOManualEntrySection(manager: manager)
                SODependentsSection(manager: manager)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - About You Subviews

struct SOAboutYouHeader: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Basic Information About You")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Speak or type your info below")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 12)
    }
}

struct SOProfileSummaryCard: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                Text("YOUR PROFILE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
            }
            
            // User info - centered
            VStack(spacing: 4) {
                Text("You are a \(manager.userProfile.age) year old \(genderText)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Children section
            if !manager.userProfile.kids.isEmpty {
                VStack(spacing: 6) {
                    Text("CHILDREN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.7))
                    ForEach(manager.userProfile.kids) { kid in
                        HStack(spacing: 8) {
                            Image(systemName: kid.gender == "female" ? "figure.dress.line.vertical.figure" : "figure.stand")
                                .foregroundColor(.cyan)
                            Text("\(kid.name), \(kid.age) years old")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // No children message
            if manager.userProfile.kids.isEmpty {
                Text("No children added yet")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.4), lineWidth: 2))
    }
    
    var genderText: String {
        switch manager.userProfile.gender {
        case "male": return "male"
        case "female": return "female"
        default: return "person"
        }
    }
}

struct SOVoiceInputSection: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Mic button
                Button(action: { manager.startListening() }) {
                    SOVoiceButton(isListening: false, icon: "mic.fill", label: "Tap to Speak")
                }
                .disabled(manager.isListening)
                
                // Stop button
                if manager.isListening {
                    Button(action: { manager.stopListening() }) {
                        SOVoiceButton(isListening: true, icon: "stop.fill", label: "Stop")
                    }
                }
            }
            
            // Examples
            if !manager.isListening && manager.voiceTranscript.isEmpty {
                VStack(spacing: 3) {
                    Text("Try saying:")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\"I am a 35 year old male\"")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    Text("\"I have a 7 year old daughter named Emma\"")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            
            // Transcript
            if !manager.voiceTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What we heard:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                    Text(manager.voiceTranscript)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            manager.processVoiceInput(manager.voiceTranscript)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.green.opacity(0.2)))
                        }
                        
                        Button(action: { manager.voiceTranscript = "" }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.red.opacity(0.1)))
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.1)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple.opacity(0.1)))
    }
}

struct SOVoiceButton: View {
    let isListening: Bool
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isListening ? Color.red.opacity(0.3) : Color.purple.opacity(0.3))
                    .frame(width: 70, height: 70)
                Circle()
                    .stroke(isListening ? Color.red : Color.purple, lineWidth: 2)
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isListening ? .red : .purple)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct SOManualEntrySection: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    @State private var ageValue: Double = 30
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("MANUAL ENTRY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            
            // Age with slider
            VStack(spacing: 8) {
                HStack {
                    Text("Age")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(manager.userProfile.age) years old")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.cyan)
                }
                
                Slider(value: $ageValue, in: 6...100, step: 1)
                    .accentColor(.cyan)
                    .onAppear { ageValue = Double(manager.userProfile.age) }
                    .onChange(of: ageValue) { newValue in
                        manager.userProfile.age = Int(newValue)
                    }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            
            // Gender
            SOGenderControl(gender: $manager.userProfile.gender)
        }
    }
}

struct SOGenderControl: View {
    @Binding var gender: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Gender")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                genderButton("Male", value: "male", icon: "figure.stand")
                genderButton("Female", value: "female", icon: "figure.dress.line.vertical.figure")
                genderButton("Other", value: "other", icon: "person.fill")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    func genderButton(_ label: String, value: String, icon: String) -> some View {
        Button(action: { gender = value }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(gender == value ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(gender == value ? Color.cyan.opacity(0.4) : Color.white.opacity(0.05)))
        }
    }
}

struct SODependentsSection: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Children", systemImage: "figure.and.child.holdinghands")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            SODependentListSection(
                title: "Children",
                icon: "figure.and.child.holdinghands",
                color: .cyan,
                items: manager.userProfile.kids.map { "\($0.name), \($0.age)" },
                onAdd: {
                    manager.editingKid = SOKid()
                    manager.editingKidIndex = nil
                    manager.showingKidEditor = true
                },
                onRemoveAt: { idx in
                    if idx < manager.userProfile.kids.count {
                        manager.removeKid(manager.userProfile.kids[idx])
                    }
                }
            )
            
            // Note about pets and parents
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.cyan.opacity(0.6))
                Text("Pets and elderly care can be added on the next page")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }
}

// Compact time picker
struct SOCompactTimePicker: View {
    @Binding var time: String
    let color: Color
    
    var body: some View {
        Menu {
            ForEach(5..<24, id: \.self) { h in
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Button(action: { time = String(format: "%02d:%02d", h, m) }) {
                        Text(formatTimeCompact(h, m))
                    }
                }
            }
        } label: {
            Text(displayTime)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    var displayTime: String {
        let parts = time.components(separatedBy: ":")
        let h = Int(parts.first ?? "7") ?? 7
        let m = Int(parts.last ?? "0") ?? 0
        return formatTimeCompact(h, m)
    }
    
    func formatTimeCompact(_ h: Int, _ m: Int) -> String {
        let hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        let ampm = h >= 12 ? "PM" : "AM"
        return "\(hour12):\(String(format: "%02d", m)) \(ampm)"
    }
}

// Dependent list section with visible items
struct SODependentListSection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    let onAdd: () -> Void
    let onRemoveAt: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14))
                        Text("Add").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(color)
                }
            }
            
            if items.isEmpty {
                Text("None added").font(.system(size: 12)).foregroundColor(.white.opacity(0.3)).padding(.leading, 22)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(item).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Button(action: { onRemoveAt(index) }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                        }
                    }
                    .padding(.leading, 22)
                }
            }
        }
    }
}

// MARK: - Screen 2: Detailed Information

struct SODetailedInfoView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    // Only show house-specific questions if they live in a house/townhouse
    var showYardQuestion: Bool { ["House", "Townhouse"].contains(manager.userProfile.housingType) }
    var showPoolQuestion: Bool { ["House", "Townhouse"].contains(manager.userProfile.housingType) }
    var showGarageQuestion: Bool { ["House", "Townhouse", "Condo"].contains(manager.userProfile.housingType) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "list.clipboard.fill").font(.system(size: 32)).foregroundColor(.cyan)
                    Text("Detailed Information").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text("Answer a few questions to personalize your tasks").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                }.padding(.top, 12)
                
                // Show what user has added (summary at top)
                if hasAnyInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR INFO").font(.system(size: 10, weight: .bold)).foregroundColor(.cyan.opacity(0.7)).tracking(1)
                        
                        SOFlowLayout(spacing: 6) {
                            // Sleep schedule chip
                            SOInfoChip(icon: "bed.double.fill", text: "Wake \(formatTime(manager.userProfile.wakeTime)) • Sleep \(formatTime(manager.userProfile.bedTime))", color: .purple)
                            
                            if !manager.userProfile.housingType.isEmpty {
                                SOInfoChip(icon: "house.fill", text: manager.userProfile.housingType, color: .green)
                            }
                            ForEach(manager.userProfile.vehicles) { vehicle in
                                SOInfoChip(icon: "car.fill", text: vehicle.name.isEmpty ? "Vehicle" : vehicle.name, color: .blue, onRemove: { manager.removeVehicle(vehicle) })
                            }
                            if manager.userProfile.hasYard { SOInfoChip(icon: "leaf.fill", text: "Yard", color: .green) }
                            if manager.userProfile.hasPool { SOInfoChip(icon: "figure.pool.swim", text: "Pool", color: .cyan) }
                            if manager.userProfile.hasGarage { SOInfoChip(icon: "car.garage.fill", text: "Garage", color: .orange) }
                            if manager.userProfile.worksFromHome { SOInfoChip(icon: "laptopcomputer", text: "WFH", color: .purple) }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.1)))
                }
                
                // QUESTIONS - Show progressively based on answers
                VStack(spacing: 12) {
                    // 1. SLEEP SCHEDULE (First question)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bed.double.fill").foregroundColor(.purple)
                            Text("What's your typical sleep schedule?").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        }
                        
                        HStack(spacing: 16) {
                            // Wake time
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sunrise.fill").font(.system(size: 14)).foregroundColor(.orange)
                                    Text("Wake Up").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                }
                                SOCompactTimePicker(time: $manager.userProfile.wakeTime, color: .orange)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
                            
                            // Bed time
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "moon.fill").font(.system(size: 14)).foregroundColor(.purple)
                                    Text("Bedtime").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                }
                                SOCompactTimePicker(time: $manager.userProfile.bedTime, color: .purple)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.1)))
                        }
                        
                        // Weekend follow-up
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Does this apply to weekends too?")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 10) {
                                Button(action: { manager.userProfile.sameScheduleWeekends = true }) {
                                    Text("Yes, same schedule")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(manager.userProfile.sameScheduleWeekends ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(manager.userProfile.sameScheduleWeekends ? Color.purple.opacity(0.5) : Color.white.opacity(0.1)))
                                }
                                Button(action: { manager.userProfile.sameScheduleWeekends = false }) {
                                    Text("No, I sleep in")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(!manager.userProfile.sameScheduleWeekends ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(!manager.userProfile.sameScheduleWeekends ? Color.purple.opacity(0.5) : Color.white.opacity(0.1)))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    
                    // 2. Housing Type
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "house.fill").foregroundColor(.green)
                            Text("What type of home do you live in?").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach(["House", "Condo", "Apartment", "Townhouse"], id: \.self) { type in
                                Button(action: { manager.userProfile.housingType = type }) {
                                    Text(type)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(manager.userProfile.housingType == type ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(manager.userProfile.housingType == type ? Color.green.opacity(0.5) : Color.white.opacity(0.1)))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    
                    // 3. Follow-up questions based on housing type
                    if !manager.userProfile.housingType.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tell us more about your \(manager.userProfile.housingType.lowercased()):")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
                            
                            if showYardQuestion {
                                YesNoToggleRow(icon: "leaf.fill", color: .green, question: "Do you have a yard?", isOn: $manager.userProfile.hasYard)
                            }
                            if showPoolQuestion {
                                YesNoToggleRow(icon: "figure.pool.swim", color: .cyan, question: "Do you have a pool?", isOn: $manager.userProfile.hasPool)
                            }
                            if showGarageQuestion {
                                YesNoToggleRow(icon: "car.garage.fill", color: .orange, question: "Do you have a garage?", isOn: $manager.userProfile.hasGarage)
                            }
                            
                            // Always show work from home
                            YesNoToggleRow(icon: "laptopcomputer", color: .purple, question: "Do you work from home?", isOn: $manager.userProfile.worksFromHome)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    }
                    
                    // 4. Vehicles
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "car.fill").foregroundColor(.blue)
                            Text("Do you have any vehicles?").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            Spacer()
                            Button(action: { manager.showingVehicleEditor = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(manager.userProfile.vehicles.isEmpty ? "Add" : "Add Another")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if !manager.userProfile.vehicles.isEmpty {
                            ForEach(manager.userProfile.vehicles) { vehicle in
                                HStack {
                                    Text("• \(vehicle.name) (\(vehicle.type))").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Button(action: { manager.removeVehicle(vehicle) }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    
                    // 5. Pets
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pawprint.fill").foregroundColor(.orange)
                            Text("Do you have any pets?").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                manager.editingPet = SOPet()
                                manager.editingPetIndex = nil
                                manager.showingPetEditor = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(manager.userProfile.pets.isEmpty ? "Add" : "Add Another")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                            }
                        }
                        
                        if !manager.userProfile.pets.isEmpty {
                            ForEach(manager.userProfile.pets) { pet in
                                HStack {
                                    Image(systemName: pet.petType.lowercased() == "cat" ? "cat.fill" : "dog.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    if pet.age.isEmpty {
                                        Text("\(pet.name) the \(pet.petType)").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                    } else {
                                        Text("\(pet.name) the \(pet.petType), \(pet.age)").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    Button(action: { manager.removePet(pet) }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                                    }
                                }
                            }
                        } else {
                            Text("No pets added").font(.system(size: 12)).foregroundColor(.white.opacity(0.4)).padding(.leading, 4)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    
                    // 6. Parents/Elderly you care for
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "figure.stand").foregroundColor(.purple)
                            Text("Do you care for any parents or elderly?").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                manager.editingParent = SOParent()
                                manager.editingParentIndex = nil
                                manager.showingParentEditor = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(manager.userProfile.dependentParents.isEmpty ? "Add" : "Add Another")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.purple)
                            }
                        }
                        
                        if !manager.userProfile.dependentParents.isEmpty {
                            ForEach(manager.userProfile.dependentParents) { parent in
                                HStack {
                                    Image(systemName: "figure.stand")
                                        .font(.system(size: 12))
                                        .foregroundColor(.purple)
                                    Text("\(parent.name), \(parent.age) (\(parent.relationship.capitalized))").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Button(action: { manager.removeParent(parent) }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                                    }
                                }
                            }
                        } else {
                            Text("No parents/elderly added").font(.system(size: 12)).foregroundColor(.white.opacity(0.4)).padding(.leading, 4)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    
                    // 7. Occupation (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "briefcase.fill").foregroundColor(.orange)
                            Text("What do you do? (optional)").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        }
                        TextField("e.g., Teacher, Engineer, Nurse", text: $manager.userProfile.occupation)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $manager.showingVehicleEditor) {
            SOVehicleEditorSheet(manager: manager)
        }
    }
    
    var hasAnyInfo: Bool {
        true // Always show since we always have sleep schedule
    }
    
    func formatTime(_ time: String) -> String {
        let parts = time.components(separatedBy: ":")
        let h = Int(parts.first ?? "7") ?? 7
        let m = Int(parts.last ?? "0") ?? 0
        let hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        let ampm = h >= 12 ? "PM" : "AM"
        if m == 0 {
            return "\(hour12) \(ampm)"
        }
        return "\(hour12):\(String(format: "%02d", m)) \(ampm)"
    }
}

// Info chip for summary display
struct SOInfoChip: View {
    let icon: String
    let text: String
    let color: Color
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 11, weight: .medium))
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.2)))
    }
}

struct DetailedInfoCard: View {
    let icon: String
    let color: Color
    let question: String
    let hasItems: Bool
    let itemCount: Int
    let itemLabel: String
    let onYes: () -> Void
    let onNo: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(question).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
            }
            
            if hasItems {
                HStack {
                    Text("\(itemCount) \(itemLabel)\(itemCount == 1 ? "" : "s") added").font(.system(size: 12)).foregroundColor(color)
                    Spacer()
                    Button(action: onYes) {
                        Text("Add More").font(.system(size: 12, weight: .medium)).foregroundColor(color)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: onYes) {
                        Text("Yes, add").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Capsule().fill(color.opacity(0.4)))
                    }
                    Button(action: onNo) {
                        Text("No").font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }
}

struct YesNoToggleRow: View {
    let icon: String
    let color: Color
    let question: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(question).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(color)
        }
    }
}

struct SOVehicleEditorSheet: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    @Environment(\.dismiss) var dismiss
    @State private var vehicleName: String = ""
    @State private var vehicleType: String = "car"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vehicle Name").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5))
                        TextField("e.g., My Honda, Dad's Truck", text: $vehicleName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vehicle Type").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 10) {
                            ForEach(["car", "truck", "suv", "van"], id: \.self) { type in
                                Button(action: { vehicleType = type }) {
                                    Text(type.capitalized)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(vehicleType == type ? .white : .white.opacity(0.5))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(vehicleType == type ? Color.blue.opacity(0.4) : Color.white.opacity(0.1)))
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        var vehicle = SOVehicle()
                        vehicle.name = vehicleName
                        vehicle.type = vehicleType
                        manager.userProfile.vehicles.append(vehicle)
                        dismiss()
                    }) {
                        Text("Add Vehicle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.blue))
                    }
                    .disabled(vehicleName.isEmpty)
                    .opacity(vehicleName.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SOTimePicker: View {
    @Binding var time: String
    let color: Color
    
    var hour: Int { Int(time.components(separatedBy: ":").first ?? "7") ?? 7 }
    var minute: Int { Int(time.components(separatedBy: ":").last ?? "0") ?? 0 }
    
    var body: some View {
        Menu {
            ForEach(5..<24, id: \.self) { h in
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Button(action: { time = String(format: "%02d:%02d", h, m) }) {
                        Text(formatTime(h, m))
                    }
                }
            }
        } label: {
            Text(formatTime(hour, minute))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.2)))
        }
    }
    
    func formatTime(_ h: Int, _ m: Int) -> String {
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        let ampm = h >= 12 ? "PM" : "AM"
        return "\(hour12):\(String(format: "%02d", m)) \(ampm)"
    }
}

struct SOGenderButton: View {
    let title: String; let icon: String; let isSelected: Bool; let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2))
        }
    }
}

struct SOEditableDependentSection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [(id: UUID, display: String)]
    let onAdd: () -> Void
    let onEdit: (UUID) -> Void
    let onRemove: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
                Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(color) }
            }
            if items.isEmpty {
                Text("None added").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
            } else {
                ForEach(items, id: \.id) { item in
                    HStack {
                        Button(action: { onEdit(item.id) }) {
                            HStack {
                                Text(item.display).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Image(systemName: "pencil").font(.system(size: 12)).foregroundColor(color.opacity(0.6))
                            }
                        }
                        Button(action: { onRemove(item.id) }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
                }
            }
        }
    }
}

// MARK: - Screen 2: Daily Tasks (Bubble Style)

struct SODailyTasksView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    @State private var selectedCategory: SOCategory? = nil
    
    var filteredTasks: [SOTask] {
        if let cat = selectedCategory {
            return manager.suggestedDailyTasks.filter { $0.category == cat }
        }
        return manager.suggestedDailyTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Daily Tasks").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text("Tap tasks you do regularly").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                HStack(spacing: 8) {
                    Text("\(manager.suggestedDailyTasks.filter { $0.isSelected }.count) selected").font(.system(size: 14, weight: .bold)).foregroundColor(.cyan)
                    Text("of \(manager.suggestedDailyTasks.count) suggestions").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                }.padding(.top, 8)
            }.padding(.top, 16)
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SOCategoryFilterButton(title: "All", isSelected: selectedCategory == nil, color: .white) {
                        selectedCategory = nil
                    }
                    ForEach(SOCategory.allCases, id: \.self) { cat in
                        let count = manager.suggestedDailyTasks.filter { $0.category == cat }.count
                        if count > 0 {
                            SOCategoryFilterButton(title: cat.rawValue.components(separatedBy: " ").first ?? cat.rawValue, isSelected: selectedCategory == cat, color: cat.color) {
                                selectedCategory = cat
                            }
                        }
                    }
                }.padding(.horizontal, 20)
            }.padding(.top, 12)
            
            // Task bubbles
            ScrollView {
                SOFlowLayout(spacing: 10) {
                    ForEach(filteredTasks) { task in
                        SOTaskBubble(task: task, onTap: {
                            manager.toggleDailyTask(task)
                        }, onEdit: {
                            manager.editTask(task)
                        })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct SOCategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? color.opacity(0.4) : Color.white.opacity(0.1)))
                .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
    }
}

struct SOTaskBubble: View {
    let task: SOTask
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: task.category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(task.isSelected ? task.category.color : task.category.color.opacity(0.6))
                Text(task.title)
                    .font(.system(size: 13, weight: task.isSelected ? .semibold : .regular))
                    .foregroundColor(task.isSelected ? .white : .white.opacity(0.7))
                if task.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(task.isSelected ? task.category.color.opacity(0.3) : Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(task.isSelected ? task.category.color : Color.white.opacity(0.15), lineWidth: 1))
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Task", systemImage: "pencil")
            }
            Button(action: onTap) {
                Label(task.isSelected ? "Deselect" : "Select", systemImage: task.isSelected ? "xmark.circle" : "checkmark.circle")
            }
        }
    }
}

// MARK: - Screen 3: Recurring Tasks (Bubble Style)

struct SORecurringTasksView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    @State private var selectedFrequency: SOFrequency? = nil
    
    var filteredTasks: [SOTask] {
        if let freq = selectedFrequency {
            return manager.suggestedRecurringTasks.filter { $0.frequency == freq }
        }
        return manager.suggestedRecurringTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Recurring Tasks").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text("Weekly, Monthly & Yearly tasks").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                HStack(spacing: 8) {
                    Text("\(manager.suggestedRecurringTasks.filter { $0.isSelected }.count) selected").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                    Text("of \(manager.suggestedRecurringTasks.count) suggestions").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                }.padding(.top, 8)
            }.padding(.top, 16)
            
            // Frequency filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SOFrequencyFilterButton(title: "All", icon: "list.bullet", isSelected: selectedFrequency == nil, color: .white) {
                        selectedFrequency = nil
                    }
                    ForEach([SOFrequency.weekly, .monthly, .yearly], id: \.self) { freq in
                        let count = manager.suggestedRecurringTasks.filter { $0.frequency == freq }.count
                        let selected = manager.suggestedRecurringTasks.filter { $0.frequency == freq && $0.isSelected }.count
                        SOFrequencyFilterButton(title: "\(freq.rawValue) (\(selected))", icon: freq.icon, isSelected: selectedFrequency == freq, color: freq.color) {
                            selectedFrequency = freq
                        }
                    }
                }.padding(.horizontal, 20)
            }.padding(.top, 12)
            
            // Task bubbles
            ScrollView {
                SOFlowLayout(spacing: 10) {
                    ForEach(filteredTasks) { task in
                        SORecurringBubble(task: task, onTap: {
                            manager.toggleRecurringTask(task)
                        }, onEdit: {
                            manager.editTask(task)
                        })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct SOFrequencyFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? color.opacity(0.4) : Color.white.opacity(0.1)))
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
    }
}

struct SORecurringBubble: View {
    let task: SOTask
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Frequency indicator
                Circle()
                    .fill(task.frequency.color)
                    .frame(width: 8, height: 8)
                Image(systemName: task.category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(task.isSelected ? task.category.color : task.category.color.opacity(0.6))
                Text(task.title)
                    .font(.system(size: 13, weight: task.isSelected ? .semibold : .regular))
                    .foregroundColor(task.isSelected ? .white : .white.opacity(0.7))
                if task.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(task.isSelected ? task.frequency.color.opacity(0.25) : Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(task.isSelected ? task.frequency.color : Color.white.opacity(0.15), lineWidth: 1))
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Task", systemImage: "pencil")
            }
            Button(action: onTap) {
                Label(task.isSelected ? "Deselect" : "Select", systemImage: task.isSelected ? "xmark.circle" : "checkmark.circle")
            }
        }
    }
}

// MARK: - Screen 4: Memory Helper

struct SOMemoryHelperView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundColor(.purple)
                Text("Intelligent Task Adder").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Based on your profile, you might need these tasks").font(.system(size: 12)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center)
            }.padding(.top, 12).padding(.horizontal, 16)
            
            // Question counter
            if manager.memoryQuestions.count > 0 && manager.currentQuestionIndex < manager.memoryQuestions.count {
                Text("Question \(manager.currentQuestionIndex + 1) of \(manager.memoryQuestions.count)")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.4)).padding(.top, 6)
            }
            
            // Current question card
            if let question = manager.currentMemoryQuestion {
                SOQuestionCard(question: question, onYes: { manager.answerMemoryQuestion(yes: true) }, onNo: { manager.answerMemoryQuestion(yes: false) })
                    .padding(.horizontal, 16).padding(.top, 12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 32)).foregroundColor(.green)
                    Text("All questions answered!").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                }.padding(.top, 24)
            }
            
            // Quick add bubbles - personalized
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ADD").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4)).tracking(1)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manager.taskBubbles.prefix(15)) { bubble in
                            Button(action: { manager.selectTaskBubble(bubble) }) {
                                Text(bubble.title).font(.system(size: 11, weight: .medium)).foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(bubble.category.color.opacity(0.3)))
                            }
                        }
                        Button(action: { manager.addCustomTask() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus").font(.system(size: 10))
                                Text("Custom").font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
            
            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 12)
            
            // ADDED TASKS LIST
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TASKS ADDED").font(.system(size: 10, weight: .bold)).foregroundColor(.purple.opacity(0.8)).tracking(1)
                    Spacer()
                    Text("\(manager.customTasks.count)").font(.system(size: 12, weight: .bold)).foregroundColor(.purple)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.2)))
                }
                
                if manager.customTasks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "tray").font(.system(size: 20)).foregroundColor(.white.opacity(0.2))
                            Text("No tasks added yet").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    }.padding(.vertical, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(manager.customTasks) { task in
                                HStack(spacing: 8) {
                                    Circle().fill(task.category.color).frame(width: 6, height: 6)
                                    Text(task.title).font(.system(size: 12)).foregroundColor(.white).lineLimit(1)
                                    Spacer()
                                    Text(task.frequency.rawValue).font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
                                    Button(action: { manager.removeCustomTask(task) }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
}

struct SOQuestionCard: View {
    let question: SOQuestion; let onYes: () -> Void; let onNo: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: question.category.icon).font(.system(size: 22)).foregroundColor(question.category.color)
                Text(question.question).font(.system(size: 14, weight: .medium)).foregroundColor(.white).multilineTextAlignment(.leading)
                Spacer()
            }
            HStack(spacing: 12) {
                Button(action: onNo) {
                    Text("No").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                }
                Button(action: onYes) {
                    Text("Yes, add task").font(.system(size: 14, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple))
                }
            }
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.1))).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Screen 5: Review Tasks

struct SOReviewTasksView: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    var onComplete: (([SOTask]) -> Void)?
    var dismiss: DismissAction
    @State private var sortByDate: Bool = false
    
    var sortedTasks: [SOTask] {
        if sortByDate {
            // Sort by date (one-time tasks with dates first, then by date)
            return manager.allSelectedTasks.sorted { task1, task2 in
                // Tasks with dates come before tasks without
                if task1.dueDate != nil && task2.dueDate == nil { return true }
                if task1.dueDate == nil && task2.dueDate != nil { return false }
                // Both have dates - sort by date
                if let date1 = task1.dueDate, let date2 = task2.dueDate {
                    return date1 < date2
                }
                // Neither has date - sort by frequency priority (daily first)
                return task1.frequency.rawValue < task2.frequency.rawValue
            }
        } else {
            // Sort by priority (high > medium > low)
            return manager.allSelectedTasks.sorted { task1, task2 in
                let priority1 = priorityOrder(task1.priority)
                let priority2 = priorityOrder(task2.priority)
                if priority1 != priority2 { return priority1 < priority2 }
                // Same priority - sort by title
                return task1.title < task2.title
            }
        }
    }
    
    func priorityOrder(_ priority: SOPriority) -> Int {
        switch priority {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Review All Tasks").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text("Make any final edits before starting").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                
                // Stats
                HStack(spacing: 16) {
                    SOStatBadge(count: manager.taskCountByFrequency[.daily] ?? 0, label: "Daily", color: .cyan)
                    SOStatBadge(count: manager.taskCountByFrequency[.weekly] ?? 0, label: "Weekly", color: .green)
                    SOStatBadge(count: manager.taskCountByFrequency[.monthly] ?? 0, label: "Monthly", color: .purple)
                    SOStatBadge(count: manager.taskCountByFrequency[.yearly] ?? 0, label: "Yearly", color: .orange)
                    SOStatBadge(count: manager.taskCountByFrequency[.once] ?? 0, label: "One-time", color: .gray)
                }.padding(.top, 12)
            }.padding(.top, 16)
            
            // Sort toggle
            HStack {
                Text("Sort by:").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                
                Button(action: { sortByDate = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                        Text("Priority")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(!sortByDate ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(!sortByDate ? Color.red.opacity(0.3) : Color.white.opacity(0.1)))
                    .overlay(Capsule().stroke(!sortByDate ? Color.red : Color.clear, lineWidth: 1))
                }
                
                Button(action: { sortByDate = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10))
                        Text("Date Due")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(sortByDate ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(sortByDate ? Color.blue.opacity(0.3) : Color.white.opacity(0.1)))
                    .overlay(Capsule().stroke(sortByDate ? Color.blue : Color.clear, lineWidth: 1))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // Task list
            ScrollView {
                LazyVStack(spacing: 8) {
                    if !sortByDate {
                        // Group by priority
                        ForEach([SOPriority.high, .medium, .low], id: \.self) { priority in
                            let tasksForPriority = sortedTasks.filter { $0.priority == priority }
                            if !tasksForPriority.isEmpty {
                                SOPrioritySection(priority: priority, tasks: tasksForPriority, onEdit: { manager.editTask($0) }, onDelete: { manager.deleteTask($0) })
                            }
                        }
                    } else {
                        // Flat list sorted by date
                        ForEach(sortedTasks) { task in
                            SOReviewRow(task: task, showDate: true, onEdit: { manager.editTask(task) }, onDelete: { manager.deleteTask(task) })
                        }
                    }
                    
                    if manager.allSelectedTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.white.opacity(0.3))
                            Text("No tasks selected").font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
                        }.padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 100)
            }
        }
    }
}

struct SOPrioritySection: View {
    let priority: SOPriority
    let tasks: [SOTask]
    let onEdit: (SOTask) -> Void
    let onDelete: (SOTask) -> Void
    
    var priorityLabel: String {
        switch priority {
        case .high: return "🔴 High Priority"
        case .medium: return "🟠 Medium Priority"
        case .low: return "⚪ Low Priority"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(priorityLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(priority.color)
                Spacer()
                Text("\(tasks.count) tasks")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 8)
            
            ForEach(tasks) { task in
                SOReviewRow(task: task, showDate: false, onEdit: { onEdit(task) }, onDelete: { onDelete(task) })
            }
        }
    }
}

struct SOStatBadge: View {
    let count: Int; let label: String; let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
        }
    }
}

struct SOReviewRow: View {
    let task: SOTask
    var showDate: Bool = false
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(task.priority.color)
                .frame(width: 10, height: 10)
            
            // Category icon
            Image(systemName: task.category.icon)
                .font(.system(size: 14))
                .foregroundColor(task.category.color)
                .frame(width: 24)
            
            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Frequency badge
                    Text(task.frequency.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(task.frequency.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(task.frequency.color.opacity(0.2)))
                    
                    // Date if one-time and showing date
                    if showDate, let date = task.dueDate {
                        Text(formatDate(date))
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                    
                    // Time
                    if !task.time.isEmpty {
                        Text(task.timeDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Duration
                    if task.duration > 0 {
                        Text(task.durationDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Complete View

// MARK: - Flow Layout

struct SOFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? 0).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []; var currentX: CGFloat = 0; var currentY: CGFloat = 0; var lineHeight: CGFloat = 0; var maxWidth: CGFloat = 0
        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 { currentX = 0; currentY += lineHeight + spacing; lineHeight = 0 }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height); currentX += size.width + spacing; maxWidth = max(maxWidth, currentX)
        }
        return (offsets, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

// MARK: - Overlays

struct SOTaskEditorOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingTaskEditor = false }
            if let task = manager.editingTask {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Edit Task").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        
                        TextField("Task name", text: Binding(get: { manager.editingTask?.title ?? "" }, set: { manager.editingTask?.title = $0 }))
                            .textFieldStyle(PlainTextFieldStyle()).padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))).foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Frequency").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                            HStack(spacing: 8) {
                                ForEach(SOFrequency.allCases, id: \.self) { freq in
                                    Button(action: { manager.editingTask?.frequency = freq }) {
                                        Text(freq.rawValue).font(.system(size: 11, weight: .medium)).foregroundColor(task.frequency == freq ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(task.frequency == freq ? freq.color : Color.white.opacity(0.1)))
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priority").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                            HStack(spacing: 8) {
                                ForEach(SOPriority.allCases, id: \.self) { priority in
                                    Button(action: { manager.editingTask?.priority = priority }) {
                                        Text(priority.rawValue).font(.system(size: 11, weight: .medium)).foregroundColor(task.priority == priority ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(task.priority == priority ? priority.color : Color.white.opacity(0.1)))
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration: \(task.duration) min").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                            Slider(value: Binding<Double>(
                                get: { Double(manager.editingTask?.duration ?? 15) },
                                set: { manager.editingTask?.duration = Int($0) }
                            ), in: 5...180, step: 5)
                            .accentColor(.cyan)
                        }
                        
                        HStack(spacing: 16) {
                            Button(action: { manager.showingTaskEditor = false }) {
                                Text("Cancel").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                            }
                            Button(action: { manager.saveEditedTask() }) {
                                Text("Save").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan))
                            }
                        }
                    }
                    .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 20).padding(.vertical, 40)
                }
            }
        }
    }
}

struct SOMemoryTaskEditorOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    @State private var selectedFrequency: SOFrequency = .once
    @State private var selectedDayOfWeek: Int = 2  // Monday
    @State private var selectedDayOfMonth: Int = 15
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2026
    @State private var taskTime: Date = Date()
    @State private var selectedDuration: Int = 30
    @State private var noTimeSelected: Bool = false
    @State private var specificDetails: String = ""
    
    let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea().onTapGesture { manager.cancelMemoryTask() }
            
            if let task = manager.editingTask {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { manager.cancelMemoryTask() }) {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("Add Task").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Button(action: { saveTask() }) {
                            Text("Save").font(.system(size: 14, weight: .semibold)).foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    
                    ScrollView {
                        VStack(spacing: 14) {
                            // Task name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Task Name").font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5))
                                TextField("What needs to be done?", text: Binding(get: { manager.editingTask?.title ?? "" }, set: { manager.editingTask?.title = $0 }))
                                    .textFieldStyle(PlainTextFieldStyle()).font(.system(size: 14)).padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1))).foregroundColor(.white)
                            }
                            
                            // Details (optional)
                            TextField("Details (optional)", text: $specificDetails)
                                .textFieldStyle(PlainTextFieldStyle()).font(.system(size: 13)).padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05))).foregroundColor(.white.opacity(0.7))
                            
                            // Frequency
                            VStack(alignment: .leading, spacing: 6) {
                                Text("HOW OFTEN").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4)).tracking(0.5)
                                HStack(spacing: 6) {
                                    ForEach([SOFrequency.daily, .weekly, .monthly, .yearly, .once], id: \.self) { freq in
                                        Button(action: { selectedFrequency = freq }) {
                                            Text(freq == .once ? "Once" : freq.rawValue)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(selectedFrequency == freq ? .white : .white.opacity(0.5))
                                                .padding(.horizontal, 10).padding(.vertical, 8)
                                                .background(RoundedRectangle(cornerRadius: 6).fill(selectedFrequency == freq ? freq.color.opacity(0.5) : Color.white.opacity(0.08)))
                                        }
                                    }
                                }
                            }
                            
                            // Schedule row
                            HStack(spacing: 12) {
                                // Date (if applicable)
                                if selectedFrequency != .daily {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(dateLabel).font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5))
                                        datePicker
                                    }
                                }
                                
                                // Time
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TIME").font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5))
                                    if noTimeSelected {
                                        Text("None").font(.system(size: 13)).foregroundColor(.white.opacity(0.4)).padding(.vertical, 8)
                                    } else {
                                        DatePicker("", selection: $taskTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden().colorScheme(.dark)
                                    }
                                }
                                
                                // Duration
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DURATION").font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5))
                                    Menu {
                                        ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { d in
                                            Button("\(d < 60 ? "\(d) min" : "\(d/60) hr")") { selectedDuration = d }
                                        }
                                    } label: {
                                        Text(selectedDuration < 60 ? "\(selectedDuration)m" : "\(selectedDuration/60)h")
                                            .font(.system(size: 14, weight: .medium)).foregroundColor(.cyan)
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                            
                            // No time toggle
                            Button(action: { noTimeSelected.toggle() }) {
                                HStack {
                                    Image(systemName: noTimeSelected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16)).foregroundColor(noTimeSelected ? .cyan : .white.opacity(0.4))
                                    Text("No specific time").font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                }
                            }
                            
                            // Priority
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PRIORITY").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4)).tracking(0.5)
                                HStack(spacing: 8) {
                                    ForEach([SOPriority.low, .medium, .high], id: \.self) { p in
                                        Button(action: { manager.editingTask?.priority = p }) {
                                            HStack(spacing: 4) {
                                                Circle().fill(p == .low ? .green : (p == .medium ? .orange : .red)).frame(width: 8, height: 8)
                                                Text(p.rawValue).font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundColor(task.priority == p ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(task.priority == p ? Color.white.opacity(0.15) : Color.white.opacity(0.05)))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    
                    // Add button
                    Button(action: { saveTask() }) {
                        Text("Add Task").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple))
                    }
                    .padding(16)
                }
                .background(Color(red: 0.1, green: 0.08, blue: 0.16))
                .cornerRadius(16)
                .padding(.horizontal, 12).padding(.vertical, 50)
            }
        }
        .onAppear {
            selectedFrequency = manager.editingTask?.frequency ?? .once
            selectedDuration = manager.editingTask?.duration ?? 30
            selectedMonth = Calendar.current.component(.month, from: Date())
            selectedDayOfMonth = Calendar.current.component(.day, from: Date())
            selectedYear = Calendar.current.component(.year, from: Date())
        }
    }
    
    var dateLabel: String {
        switch selectedFrequency {
        case .weekly: return "DAY"
        case .monthly: return "DAY OF MONTH"
        case .yearly: return "DATE"
        case .once: return "DUE DATE"
        default: return "DATE"
        }
    }
    
    @ViewBuilder var datePicker: some View {
        switch selectedFrequency {
        case .weekly:
            Menu {
                ForEach(0..<7, id: \.self) { i in
                    Button(daysOfWeek[i]) { selectedDayOfWeek = i + 1 }
                }
            } label: {
                Text(daysOfWeek[selectedDayOfWeek - 1]).font(.system(size: 14, weight: .medium)).foregroundColor(.cyan)
            }
        case .monthly:
            Menu {
                ForEach(1...31, id: \.self) { d in Button("\(d)") { selectedDayOfMonth = d } }
            } label: {
                Text("\(selectedDayOfMonth)").font(.system(size: 14, weight: .medium)).foregroundColor(.cyan)
            }
        case .yearly, .once:
            HStack(spacing: 4) {
                Menu {
                    ForEach(1...12, id: \.self) { m in
                        Button(DateFormatter().monthSymbols[m-1]) { selectedMonth = m }
                    }
                } label: {
                    Text(DateFormatter().shortMonthSymbols[selectedMonth - 1]).font(.system(size: 13)).foregroundColor(.cyan)
                }
                Text("/").foregroundColor(.white.opacity(0.3))
                Menu {
                    ForEach(1...31, id: \.self) { d in Button("\(d)") { selectedDayOfMonth = d } }
                } label: {
                    Text("\(selectedDayOfMonth)").font(.system(size: 13)).foregroundColor(.cyan)
                }
                if selectedFrequency == .once {
                    Text("/").foregroundColor(.white.opacity(0.3))
                    Menu {
                        ForEach(2024...2030, id: \.self) { y in Button("\(y)") { selectedYear = y } }
                    } label: {
                        Text("\(selectedYear)").font(.system(size: 13)).foregroundColor(.cyan)
                    }
                }
            }
        default:
            EmptyView()
        }
    }
    
    func saveTask() {
        if !specificDetails.isEmpty {
            manager.editingTask?.title = "\(manager.editingTask?.title ?? "") - \(specificDetails)"
        }
        
        manager.editingTask?.duration = selectedDuration
        manager.editingTask?.frequency = selectedFrequency
        
        if noTimeSelected {
            manager.editingTask?.time = ""
        } else {
            let hour = Calendar.current.component(.hour, from: taskTime)
            let minute = Calendar.current.component(.minute, from: taskTime)
            manager.editingTask?.time = String(format: "%02d:%02d", hour, minute)
        }
        
        switch selectedFrequency {
        case .weekly: manager.editingTask?.daysOfWeek = [daysOfWeek[selectedDayOfWeek - 1].lowercased()]
        case .monthly: manager.editingTask?.dayOfMonth = selectedDayOfMonth
        case .yearly: manager.editingTask?.dayOfMonth = selectedDayOfMonth; manager.editingTask?.monthOfYear = selectedMonth
        case .once:
            var components = DateComponents()
            components.year = selectedYear; components.month = selectedMonth; components.day = selectedDayOfMonth
            if !noTimeSelected {
                components.hour = Calendar.current.component(.hour, from: taskTime)
                components.minute = Calendar.current.component(.minute, from: taskTime)
            }
            manager.editingTask?.dueDate = Calendar.current.date(from: components)
        default: break
        }
        
        manager.saveMemoryTask()
    }
}

struct SOPriorityButton: View {
    let priority: SOPriority
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

struct SOKidEditorOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    var isEditing: Bool { manager.editingKidIndex != nil }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingKidEditor = false; manager.editingKidIndex = nil }
            VStack(spacing: 16) {
                Text(isEditing ? "Edit Child" : "Add Child").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                TextField("Name", text: $manager.editingKid.name).textFieldStyle(PlainTextFieldStyle()).padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))).foregroundColor(.white)
                HStack {
                    Text("Age: \(manager.editingKid.age)").foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Stepper("", value: $manager.editingKid.age, in: 0...18).labelsHidden()
                }
                HStack(spacing: 8) {
                    ForEach(["boy", "girl"], id: \.self) { gender in
                        Button(action: { manager.editingKid.gender = gender }) {
                            Text(gender.capitalized).font(.system(size: 14, weight: .medium)).foregroundColor(manager.editingKid.gender == gender ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 8).fill(manager.editingKid.gender == gender ? Color.cyan : Color.white.opacity(0.1)))
                        }
                    }
                }
                HStack(spacing: 16) {
                    Button(action: { manager.showingKidEditor = false; manager.editingKidIndex = nil }) {
                        Text("Cancel").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                    }
                    Button(action: { manager.addKid() }) {
                        Text(isEditing ? "Save" : "Add").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan))
                    }.disabled(manager.editingKid.name.isEmpty)
                }
            }
            .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 30)
        }
    }
}

struct SOPetEditorOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    let petTypes = ["dog", "cat", "bird", "fish", "rabbit", "other"]
    var isEditing: Bool { manager.editingPetIndex != nil }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingPetEditor = false; manager.editingPetIndex = nil }
            VStack(spacing: 16) {
                Text(isEditing ? "Edit Pet" : "Add Pet").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                TextField("Name", text: $manager.editingPet.name).textFieldStyle(PlainTextFieldStyle()).padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))).foregroundColor(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(petTypes, id: \.self) { type in
                            Button(action: { manager.editingPet.petType = type }) {
                                Text(type.capitalized).font(.system(size: 12, weight: .medium)).foregroundColor(manager.editingPet.petType == type ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(manager.editingPet.petType == type ? Color.brown : Color.white.opacity(0.1)))
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age (e.g., '2 years' or '6 months')").font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                    TextField("Age", text: $manager.editingPet.age)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                        .foregroundColor(.white)
                }
                HStack(spacing: 16) {
                    Button(action: { manager.showingPetEditor = false; manager.editingPetIndex = nil }) {
                        Text("Cancel").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                    }
                    Button(action: { manager.addPet() }) {
                        Text(isEditing ? "Save" : "Add").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.brown))
                    }.disabled(manager.editingPet.name.isEmpty)
                }
            }
            .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 30)
        }
    }
}

struct SOParentEditorOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    let relationships = ["mother", "father", "grandma", "grandpa", "other"]
    var isEditing: Bool { manager.editingParentIndex != nil }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingParentEditor = false; manager.editingParentIndex = nil }
            VStack(spacing: 16) {
                Text(isEditing ? "Edit Dependent" : "Add Dependent").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                TextField("Name", text: $manager.editingParent.name).textFieldStyle(PlainTextFieldStyle()).padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))).foregroundColor(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(relationships, id: \.self) { rel in
                            Button(action: { manager.editingParent.relationship = rel }) {
                                Text(rel.capitalized).font(.system(size: 12, weight: .medium)).foregroundColor(manager.editingParent.relationship == rel ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(manager.editingParent.relationship == rel ? Color.purple : Color.white.opacity(0.1)))
                            }
                        }
                    }
                }
                HStack {
                    Text("Age: \(manager.editingParent.age)").foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Stepper("", value: $manager.editingParent.age, in: 50...100).labelsHidden()
                }
                Toggle("Lives with you", isOn: $manager.editingParent.livesWithYou).foregroundColor(.white.opacity(0.7)).tint(.purple)
                HStack(spacing: 16) {
                    Button(action: { manager.showingParentEditor = false; manager.editingParentIndex = nil }) {
                        Text("Cancel").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                    }
                    Button(action: { manager.addParent() }) {
                        Text(isEditing ? "Save" : "Add").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple))
                    }.disabled(manager.editingParent.name.isEmpty)
                }
            }
            .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 30)
        }
    }
}

struct SOSettingsOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingSettings = false }
            VStack(spacing: 16) {
                HStack {
                    Text("Settings").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { manager.showingSettings = false }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.white.opacity(0.5)) }
                }
                Divider().background(Color.white.opacity(0.2))
                Button(action: { manager.showingSettings = false; manager.showingHelp = true }) {
                    HStack {
                        Image(systemName: "questionmark.circle").foregroundColor(.cyan)
                        Text("Help & How to Use").foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
                    }.padding(.vertical, 8)
                }
                Button(action: { manager.resetOnboardingTasks(); manager.showingSettings = false }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise").foregroundColor(.orange)
                        Text("Reset Onboarding Tasks").foregroundColor(.white)
                        Spacer()
                    }.padding(.vertical, 8)
                }
                Button(action: { manager.resetAppCompletely(); manager.showingSettings = false }) {
                    HStack {
                        Image(systemName: "trash").foregroundColor(.red)
                        Text("Reset App Completely").foregroundColor(.red)
                        Spacer()
                    }.padding(.vertical, 8)
                }
                Divider().background(Color.white.opacity(0.2))
                Toggle(isOn: $manager.isDarkMode) {
                    HStack {
                        Image(systemName: "moon.fill").foregroundColor(.purple)
                        Text("Dark Mode").foregroundColor(.white)
                    }
                }.tint(.purple)
            }
            .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 30)
        }
    }
}

struct SOHelpOverlay: View {
    @ObservedObject var manager: ClaudeSmartOnboardingManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { manager.showingHelp = false }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("How to Use").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Button(action: { manager.showingHelp = false }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.white.opacity(0.5)) }
                    }
                    Divider().background(Color.white.opacity(0.2))
                    SOHelpItem(number: "1", title: "About You", description: "Enter your age, gender, and add any dependents (kids, pets, elderly family members) you care for.")
                    SOHelpItem(number: "2", title: "Daily Tasks", description: "Review AI-suggested daily tasks based on your profile. Toggle tasks on/off and edit details as needed.")
                    SOHelpItem(number: "3", title: "Recurring Tasks", description: "Review weekly, monthly, and yearly tasks. These include bills, maintenance, and appointments.")
                    SOHelpItem(number: "4", title: "Memory Helper", description: "Answer questions to uncover tasks you might have forgotten. Tap suggested bubbles to quickly add common tasks.")
                    SOHelpItem(number: "5", title: "Review", description: "See all your selected tasks in one place. Make final edits before completing setup.")
                    Divider().background(Color.white.opacity(0.2))
                    Text("Tips:").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("• Use the microphone button to speak instead of typing\n• Tap the gear icon for settings anytime\n• You can always come back and edit tasks later").font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                }
                .padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.12, green: 0.1, blue: 0.2))).padding(.horizontal, 20).padding(.vertical, 40)
            }
        }
    }
}

struct SOHelpItem: View {
    let number: String; let title: String; let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 14, weight: .bold)).foregroundColor(.white).frame(width: 24, height: 24).background(Circle().fill(Color.cyan))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Text(description).font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    ClaudeSmartOnboardingView()
}
