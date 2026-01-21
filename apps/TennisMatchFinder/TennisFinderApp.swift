import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - App Entry Point

@main
struct TennisMatchFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        if appState.currentUser == nil {
            OnboardingView(appState: appState)
        } else {
            MainTabView(appState: appState)
        }
    }
}

// MARK: - Data Models

struct User: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phone: String
    var skillLevels: [SkillLevel]  // Can select 1 or 2 skill levels
    var homeLocation: Coordinate?
    var profileImageData: Data?
    var joinedDate: Date = Date()
    var matchesPlayed: Int = 0
    var recentlyPlayedCourtIds: [UUID] = []  // Track recently played courts
    var favoriteCourtIds: [UUID] = []  // User's favorited courts
    
    // Friends & Social
    var friendIds: [UUID] = []  // Users added as friends
    var blockedIds: [UUID] = []  // Blocked users
    var groupIds: [UUID] = []  // Groups user belongs to
    
    // Trust & Ratings
    var ratingsReceived: [PlayerRating] = []
    var currentStreak: Int = 0  // Days in a row with matches
    var longestStreak: Int = 0
    var lastPlayedDate: Date?
    
    // Computed trust score (0-5 stars)
    var trustScore: Double {
        guard !ratingsReceived.isEmpty else { return 0 }
        let total = ratingsReceived.reduce(0.0) { $0 + $1.overallScore }
        return total / Double(ratingsReceived.count)
    }
    
    var trustLevel: TrustLevel {
        TrustLevel.from(score: trustScore, matchCount: matchesPlayed)
    }
    
    // Primary skill level (first selected)
    var skillLevel: SkillLevel {
        skillLevels.first ?? .intermediate
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    // For backward compatibility
    init(id: UUID = UUID(), name: String, phone: String, skillLevel: SkillLevel, homeLocation: Coordinate? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.skillLevels = [skillLevel]
        self.homeLocation = homeLocation
    }
    
    init(id: UUID = UUID(), name: String, phone: String, skillLevels: [SkillLevel], homeLocation: Coordinate? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.skillLevels = skillLevels
        self.homeLocation = homeLocation
    }
}

// MARK: - Rating & Trust Models

struct PlayerRating: Identifiable, Codable, Equatable {
    var id = UUID()
    var matchId: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var punctuality: Int  // 1-5
    var skillAccuracy: Int  // 1-5: Was their skill rating accurate?
    var sportsmanship: Int  // 1-5
    var wouldPlayAgain: Bool
    var comment: String = ""
    var date: Date = Date()
    
    var overallScore: Double {
        let base = Double(punctuality + skillAccuracy + sportsmanship) / 3.0
        return wouldPlayAgain ? min(base + 0.5, 5.0) : max(base - 0.5, 1.0)
    }
}

enum TrustLevel: String, Codable {
    case new = "New Player"
    case rising = "Rising"
    case trusted = "Trusted"
    case verified = "Verified"
    case allStar = "All-Star"
    
    var icon: String {
        switch self {
        case .new: return "person.badge.clock"
        case .rising: return "arrow.up.circle"
        case .trusted: return "checkmark.shield"
        case .verified: return "checkmark.seal.fill"
        case .allStar: return "star.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .gray
        case .rising: return .blue
        case .trusted: return .green
        case .verified: return .purple
        case .allStar: return .orange
        }
    }
    
    static func from(score: Double, matchCount: Int) -> TrustLevel {
        if matchCount < 3 { return .new }
        if matchCount < 10 { return score >= 3.5 ? .rising : .new }
        if matchCount < 25 { return score >= 4.0 ? .trusted : .rising }
        if matchCount < 50 { return score >= 4.3 ? .verified : .trusted }
        return score >= 4.5 ? .allStar : .verified
    }
}

// MARK: - Groups Model

struct TennisGroup: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String
    var creatorId: UUID
    var memberIds: [UUID]
    var adminIds: [UUID]
    var isPrivate: Bool = true
    var skillLevelRange: ClosedRange<Int> = 0...4
    var createdAt: Date = Date()
    var messages: [GroupMessage] = []
    var imageData: Data?
    
    var memberCount: Int { memberIds.count }
}

struct GroupMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var senderId: UUID
    var text: String
    var timestamp: Date = Date()
    var isSystemMessage: Bool = false
}

// MARK: - Weather Model

struct WeatherInfo: Codable, Equatable {
    var temperature: Int  // Fahrenheit
    var condition: WeatherCondition
    var humidity: Int  // Percentage
    var windSpeed: Int  // MPH
    var rainChance: Int  // Percentage
    var updatedAt: Date = Date()
    
    var isGoodForTennis: Bool {
        condition != .rain && condition != .storm && 
        temperature >= 45 && temperature <= 95 &&
        rainChance < 40 && windSpeed < 20
    }
    
    var recommendation: String {
        if condition == .rain || condition == .storm {
            return "Consider indoor courts"
        }
        if rainChance >= 40 {
            return "Rain likely - have backup plan"
        }
        if temperature < 45 {
            return "Bundle up - it's cold!"
        }
        if temperature > 90 {
            return "Stay hydrated - very hot!"
        }
        if windSpeed > 15 {
            return "Windy conditions expected"
        }
        return "Great tennis weather!"
    }
}

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case storm = "Thunderstorm"
    
    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .sunny: return .yellow
        case .partlyCloudy: return .orange
        case .cloudy: return .gray
        case .rain: return .blue
        case .storm: return .purple
        }
    }
}

// MARK: - Court Check-In Model

struct CourtCheckIn: Identifiable, Codable, Equatable {
    var id = UUID()
    var courtId: UUID
    var userId: UUID
    var courtsInUse: Int
    var totalCourts: Int
    var estimatedWaitMinutes: Int?
    var leavingInMinutes: Int?  // "I'm leaving in X minutes"
    var note: String = ""
    var timestamp: Date = Date()
    
    var isRecent: Bool {
        timestamp.timeIntervalSinceNow > -1800  // Within 30 minutes
    }
}

struct CourtBusynessPattern: Codable, Equatable {
    var courtId: UUID
    var dayOfWeek: Int  // 1 = Sunday, 7 = Saturday
    var hourOfDay: Int  // 0-23
    var averageBusyness: Double  // 0-1 scale
    var sampleCount: Int
}

enum SkillLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    var id: String { rawValue }
    
    var ntrpRange: String {
        switch self {
        case .beginner: return "2.0-2.5"
        case .intermediate: return "3.0-3.5"
        case .advanced: return "4.0-4.5"
        case .expert: return "5.0+"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .expert: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
}

// Helper function to format skill levels for display
func formatSkillLevels(_ levels: [SkillLevel]) -> String {
    if levels.count == 2 {
        let sorted = levels.sorted { $0.sortOrder < $1.sortOrder }
        return "\(sorted[0].rawValue)/\(sorted[1].rawValue)"
    }
    return levels.first?.rawValue ?? "Unknown"
}

struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    func distance(to other: Coordinate) -> Double {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2) / 1609.34 // Convert meters to miles
    }
}

struct TennisCourt: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var address: String
    var coordinate: Coordinate
    var numberOfCourts: Int
    var courtType: CourtType
    var hasLights: Bool
    var isPublic: Bool
    var notes: String
    var addedByUserId: UUID?
    var busynessReports: [BusynessReport] = []
    var isVerifiedPublic: Bool = false  // Courts verified by app owner as public
    var favoritedByUserIds: [UUID] = []  // Users who favorited this court
    var checkIns: [CourtCheckIn] = []  // Live check-ins
    var busynessPatterns: [CourtBusynessPattern] = []  // Historical patterns
    
    func isFavorite(for userId: UUID) -> Bool {
        favoritedByUserIds.contains(userId)
    }
    
    // Get recent check-ins (within 30 min)
    var recentCheckIns: [CourtCheckIn] {
        checkIns.filter { $0.isRecent }
    }
    
    // Live court availability from check-ins
    var liveAvailability: (inUse: Int, total: Int)? {
        guard let latest = recentCheckIns.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            return nil
        }
        return (latest.courtsInUse, latest.totalCourts)
    }
    
    // Estimated wait time from recent check-ins
    var estimatedWaitMinutes: Int? {
        recentCheckIns.compactMap { $0.estimatedWaitMinutes }.last
    }
    
    // Someone leaving soon?
    var soonestDeparture: Int? {
        recentCheckIns
            .compactMap { $0.leavingInMinutes }
            .filter { $0 > 0 }
            .min()
    }
    
    // Calculate current busyness based on reports and time
    func currentBusyness(at date: Date = Date()) -> BusynessLevel {
        // First check live check-ins
        if let live = liveAvailability {
            let occupancy = Double(live.inUse) / Double(max(live.total, 1))
            if occupancy >= 0.9 { return .high }
            if occupancy >= 0.5 { return .moderate }
            return .low
        }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        
        // Check historical patterns
        if let pattern = busynessPatterns.first(where: { 
            $0.dayOfWeek == weekday && $0.hourOfDay == hour 
        }), pattern.sampleCount >= 3 {
            if pattern.averageBusyness >= 0.7 { return .high }
            if pattern.averageBusyness >= 0.4 { return .moderate }
            return .low
        }
        
        // Check recent reports (last 2 weeks, same day type and hour range)
        let recentReports = busynessReports.filter { report in
            let reportWeekday = calendar.component(.weekday, from: report.date)
            let reportIsWeekend = reportWeekday == 1 || reportWeekday == 7
            let reportHour = calendar.component(.hour, from: report.date)
            let daysSince = calendar.dateComponents([.day], from: report.date, to: date).day ?? 100
            
            return daysSince <= 14 &&
                   reportIsWeekend == isWeekend &&
                   abs(reportHour - hour) <= 2
        }
        
        if !recentReports.isEmpty {
            let avgBusyness = recentReports.map { $0.level.rawValue }.reduce(0, +) / recentReports.count
            return BusynessLevel(rawValue: avgBusyness) ?? estimatedBusyness(hour: hour, isWeekend: isWeekend)
        }
        
        return estimatedBusyness(hour: hour, isWeekend: isWeekend)
    }
    
    private func estimatedBusyness(hour: Int, isWeekend: Bool) -> BusynessLevel {
        if isWeekend {
            switch hour {
            case 6...8: return .low
            case 9...11: return .high
            case 12...14: return .moderate
            case 15...18: return .high
            case 19...21: return hasLights ? .moderate : .low
            default: return .low
            }
        } else {
            switch hour {
            case 6...8: return .moderate
            case 9...11: return .low
            case 12...13: return .moderate
            case 14...16: return .low
            case 17...19: return .high
            case 20...21: return hasLights ? .moderate : .low
            default: return .low
            }
        }
    }
}

enum CourtType: String, Codable, CaseIterable, Identifiable {
    case hardcourt = "Hard Court"
    case clay = "Clay"
    case grass = "Grass"
    case indoor = "Indoor"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .hardcourt: return "square.fill"
        case .clay: return "leaf.fill"
        case .grass: return "leaf.circle.fill"
        case .indoor: return "building.2.fill"
        }
    }
}

struct BusynessReport: Identifiable, Codable, Equatable {
    var id = UUID()
    var courtId: UUID
    var userId: UUID
    var date: Date
    var level: BusynessLevel
    var waitTime: Int? // minutes
    var notes: String?
}

enum BusynessLevel: Int, Codable, CaseIterable, Identifiable {
    case low = 1
    case moderate = 2
    case high = 3
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "Busy"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .moderate: return "circle.lefthalf.filled"
        case .high: return "exclamationmark.circle.fill"
        }
    }
}

struct Availability: Identifiable, Codable, Equatable {
    var id = UUID()
    var userId: UUID
    var preferredCourtId: UUID?  // First choice court
    var secondaryCourtId: UUID?  // Second choice court
    var startTime: Date
    var endTime: Date
    var skillLevelRange: ClosedRange<Int>  // 1-4 matching SkillLevel
    var matchType: MatchType
    var notes: String
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// Invite for a specific user
struct UserInvite: Identifiable, Codable, Equatable {
    var id = UUID()
    var fromUserId: UUID
    var toUserId: UUID
    var preferredCourtId: UUID?
    var secondaryCourtId: UUID?
    var proposedTimes: [Date]  // Multiple proposed times
    var duration: TimeInterval = 3600  // Default 1 hour
    var matchType: MatchType
    var notes: String
    var status: InviteStatus = .pending
    var createdAt: Date = Date()
    var selectedTime: Date?  // Time accepted by recipient
}

enum InviteStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
    case expired = "Expired"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .expired: return .gray
        }
    }
}

enum MatchType: String, Codable, CaseIterable, Identifiable {
    case singles = "Singles"
    case doubles = "Doubles"
    case either = "Either"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .singles: return "person.fill"
        case .doubles: return "person.2.fill"
        case .either: return "person.fill.questionmark"
        }
    }
}

struct Match: Identifiable, Codable, Equatable {
    var id = UUID()
    var availabilityId: UUID
    var requesterId: UUID  // User who posted availability
    var accepterId: UUID   // User who accepted
    var courtId: UUID?
    var scheduledTime: Date
    var endTime: Date?
    var matchType: MatchType
    var status: MatchStatus
    var createdAt: Date = Date()
    var messages: [MatchMessage] = []
    
    // Rating tracking
    var requesterHasRated: Bool = false
    var accepterHasRated: Bool = false
    
    // Weather at time of match (cached)
    var weatherInfo: WeatherInfo?
    
    var isCompleted: Bool { status == .completed }
    var needsRating: Bool { status == .completed && (!requesterHasRated || !accepterHasRated) }
}

enum MatchStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .green
        case .completed: return .blue
        case .cancelled: return .red
        }
    }
}

struct MatchMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var senderId: UUID
    var text: String
    var timestamp: Date = Date()
    var isQuickAlert: Bool = false  // For system alerts like "Running late"
    var alertType: QuickAlertType?
}

enum QuickAlertType: String, Codable, CaseIterable {
    case runningLate = "Running Late"
    case courtsFull = "Courts Full"
    case needToCancel = "Need to Cancel"
    case onMyWay = "On My Way"
    case arrived = "I'm Here"
    
    var icon: String {
        switch self {
        case .runningLate: return "clock.badge.exclamationmark"
        case .courtsFull: return "exclamationmark.triangle"
        case .needToCancel: return "xmark.circle"
        case .onMyWay: return "car.fill"
        case .arrived: return "mappin.and.ellipse"
        }
    }
    
    var color: Color {
        switch self {
        case .runningLate: return .orange
        case .courtsFull: return .red
        case .needToCancel: return .red
        case .onMyWay: return .blue
        case .arrived: return .green
        }
    }
}

// Direct message for non-matched users
struct DirectMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var fromUserId: UUID
    var toUserId: UUID
    var text: String
    var timestamp: Date = Date()
    var isRead: Bool = false
}

// MARK: - Court Filter

enum CourtFilter: String, CaseIterable, Identifiable {
    case all = "All Courts"
    case verified = "Verified Public"
    case favorites = "Favorites"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "map"
        case .verified: return "checkmark.seal.fill"
        case .favorites: return "star.fill"
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var users: [User] = []
    @Published var courts: [TennisCourt] = []
    @Published var availabilities: [Availability] = []
    @Published var matches: [Match] = []
    @Published var directMessages: [DirectMessage] = []
    @Published var invites: [UserInvite] = []
    @Published var groups: [TennisGroup] = []
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var weatherCache: [String: WeatherInfo] = [:]  // Cache by date string
    
    private let userDefaultsKey = "TennisMatchFinderData"
    private var locationManager: LocationManager?
    
    // 50 mile radius in meters
    let maxCourtDistanceMiles: Double = 50
    
    init() {
        loadData()
        setupLocationManager()
        
        // Add sample courts if none exist
        if courts.isEmpty {
            addSampleCourts()
        }
    }
    
    private func setupLocationManager() {
        locationManager = LocationManager { [weak self] location in
            self?.userLocation = location
        }
    }
    
    // MARK: - Data Persistence
    
    func saveData() {
        let data = AppData(
            currentUserId: currentUser?.id,
            users: users,
            courts: courts,
            availabilities: availabilities,
            matches: matches,
            directMessages: directMessages,
            invites: invites,
            groups: groups
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func loadData() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(AppData.self, from: data) else {
            return
        }
        
        users = decoded.users
        courts = decoded.courts
        availabilities = decoded.availabilities
        matches = decoded.matches
        directMessages = decoded.directMessages
        invites = decoded.invites
        groups = decoded.groups
        
        if let userId = decoded.currentUserId {
            currentUser = users.first { $0.id == userId }
        }
    }
    
    // MARK: - User Management
    
    func createUser(_ user: User) {
        var newUser = user
        users.append(newUser)
        currentUser = newUser
        saveData()
    }
    
    func updateUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
            if currentUser?.id == user.id {
                currentUser = user
            }
            saveData()
        }
    }
    
    func getUser(by id: UUID) -> User? {
        users.first { $0.id == id }
    }
    
    // MARK: - Court Management
    
    func addCourt(_ court: TennisCourt) {
        courts.append(court)
        saveData()
    }
    
    func updateCourt(_ court: TennisCourt) {
        if let index = courts.firstIndex(where: { $0.id == court.id }) {
            courts[index] = court
            saveData()
        }
    }
    
    func deleteCourt(_ court: TennisCourt) {
        courts.removeAll { $0.id == court.id }
        saveData()
    }
    
    func toggleFavorite(court: TennisCourt) {
        guard let userId = currentUser?.id,
              let index = courts.firstIndex(where: { $0.id == court.id }) else { return }
        
        if courts[index].favoritedByUserIds.contains(userId) {
            courts[index].favoritedByUserIds.removeAll { $0 == userId }
        } else {
            courts[index].favoritedByUserIds.append(userId)
        }
        saveData()
    }
    
    func reportBusyness(courtId: UUID, level: BusynessLevel, waitTime: Int? = nil, notes: String? = nil) {
        guard let userId = currentUser?.id,
              let index = courts.firstIndex(where: { $0.id == courtId }) else { return }
        
        let report = BusynessReport(
            courtId: courtId,
            userId: userId,
            date: Date(),
            level: level,
            waitTime: waitTime,
            notes: notes
        )
        
        courts[index].busynessReports.append(report)
        saveData()
    }
    
    // Filter courts within 50 miles of user's home location
    func courtsWithinRange(of center: Coordinate? = nil) -> [TennisCourt] {
        guard let homeLocation = center ?? currentUser?.homeLocation else {
            return courts
        }
        
        return courts.filter { court in
            court.coordinate.distance(to: homeLocation) <= maxCourtDistanceMiles
        }
    }
    
    func filteredCourts(filter: CourtFilter, mapCenter: Coordinate? = nil) -> [TennisCourt] {
        let courtsInRange = courtsWithinRange(of: mapCenter)
        
        switch filter {
        case .all:
            return courtsInRange
        case .verified:
            return courtsInRange.filter { $0.isVerifiedPublic }
        case .favorites:
            guard let userId = currentUser?.id else { return [] }
            return courtsInRange.filter { $0.isFavorite(for: userId) }
        }
    }
    
    // MARK: - Availability Management
    
    func postAvailability(_ availability: Availability) {
        availabilities.append(availability)
        saveData()
    }
    
    func cancelAvailability(_ availability: Availability) {
        if let index = availabilities.firstIndex(where: { $0.id == availability.id }) {
            availabilities[index].isActive = false
            saveData()
        }
    }
    
    var activeAvailabilities: [Availability] {
        availabilities.filter { $0.isActive && $0.endTime > Date() }
    }
    
    func availabilitiesForOthers(excluding userId: UUID) -> [Availability] {
        activeAvailabilities.filter { $0.userId != userId }
    }
    
    func myActiveAvailabilities() -> [Availability] {
        guard let userId = currentUser?.id else { return [] }
        return activeAvailabilities.filter { $0.userId == userId }
    }
    
    // MARK: - Match Management
    
    func acceptMatch(availability: Availability, accepterId: UUID, courtId: UUID?) -> Match {
        let match = Match(
            availabilityId: availability.id,
            requesterId: availability.userId,
            accepterId: accepterId,
            courtId: courtId,
            scheduledTime: availability.startTime,
            matchType: availability.matchType,
            status: .pending
        )
        
        matches.append(match)
        
        // Deactivate the availability
        if let index = availabilities.firstIndex(where: { $0.id == availability.id }) {
            availabilities[index].isActive = false
        }
        
        saveData()
        return match
    }
    
    func confirmMatch(_ match: Match) {
        if let index = matches.firstIndex(where: { $0.id == match.id }) {
            matches[index].status = .confirmed
            saveData()
        }
    }
    
    func cancelMatch(_ match: Match) {
        if let index = matches.firstIndex(where: { $0.id == match.id }) {
            matches[index].status = .cancelled
            
            // Reactivate availability if match was pending
            if match.status == .pending,
               let availIndex = availabilities.firstIndex(where: { $0.id == match.availabilityId }) {
                availabilities[availIndex].isActive = true
            }
            
            saveData()
        }
    }
    
    func completeMatch(_ match: Match) {
        if let index = matches.firstIndex(where: { $0.id == match.id }) {
            matches[index].status = .completed
            
            // Increment match count for both players
            if let requesterIndex = users.firstIndex(where: { $0.id == match.requesterId }) {
                users[requesterIndex].matchesPlayed += 1
            }
            if let accepterIndex = users.firstIndex(where: { $0.id == match.accepterId }) {
                users[accepterIndex].matchesPlayed += 1
            }
            
            saveData()
        }
    }
    
    func matchesForUser(_ userId: UUID) -> [Match] {
        matches.filter { $0.requesterId == userId || $0.accepterId == userId }
    }
    
    func addMessageToMatch(matchId: UUID, text: String, isQuickAlert: Bool = false, alertType: QuickAlertType? = nil) {
        guard let userId = currentUser?.id,
              let index = matches.firstIndex(where: { $0.id == matchId }) else { return }
        
        let message = MatchMessage(
            senderId: userId,
            text: text,
            isQuickAlert: isQuickAlert,
            alertType: alertType
        )
        
        matches[index].messages.append(message)
        saveData()
        
        // TODO: Send push notification to other user
        // This would integrate with your notification service
    }
    
    func sendQuickAlert(matchId: UUID, alertType: QuickAlertType) {
        addMessageToMatch(matchId: matchId, text: alertType.rawValue, isQuickAlert: true, alertType: alertType)
    }
    
    // MARK: - Direct Messages
    
    func sendDirectMessage(to userId: UUID, text: String) {
        guard let fromUserId = currentUser?.id else { return }
        
        let message = DirectMessage(
            fromUserId: fromUserId,
            toUserId: userId,
            text: text
        )
        
        directMessages.append(message)
        saveData()
        
        // TODO: Send push notification to recipient
    }
    
    func getDirectMessages(with userId: UUID) -> [DirectMessage] {
        guard let currentUserId = currentUser?.id else { return [] }
        return directMessages.filter {
            ($0.fromUserId == currentUserId && $0.toUserId == userId) ||
            ($0.fromUserId == userId && $0.toUserId == currentUserId)
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    func unreadMessageCount(from userId: UUID) -> Int {
        guard let currentUserId = currentUser?.id else { return 0 }
        return directMessages.filter {
            $0.fromUserId == userId && $0.toUserId == currentUserId && !$0.isRead
        }.count
    }
    
    func markMessagesAsRead(from userId: UUID) {
        guard let currentUserId = currentUser?.id else { return }
        for index in directMessages.indices {
            if directMessages[index].fromUserId == userId &&
               directMessages[index].toUserId == currentUserId {
                directMessages[index].isRead = true
            }
        }
        saveData()
    }
    
    // MARK: - Invite Management
    
    func sendInvite(_ invite: UserInvite) {
        invites.append(invite)
        saveData()
        // TODO: Send push notification to recipient
    }
    
    func acceptInvite(_ invite: UserInvite, selectedTime: Date) {
        guard let index = invites.firstIndex(where: { $0.id == invite.id }) else { return }
        invites[index].status = .accepted
        invites[index].selectedTime = selectedTime
        
        // Create a match from the accepted invite
        guard let currentUserId = currentUser?.id else { return }
        
        let match = Match(
            availabilityId: invite.id,  // Using invite ID as reference
            requesterId: invite.fromUserId,
            accepterId: currentUserId,
            courtId: invite.preferredCourtId,
            scheduledTime: selectedTime,
            matchType: invite.matchType,
            status: .confirmed
        )
        
        matches.append(match)
        saveData()
    }
    
    func declineInvite(_ invite: UserInvite) {
        if let index = invites.firstIndex(where: { $0.id == invite.id }) {
            invites[index].status = .declined
            saveData()
        }
    }
    
    func invitesForUser(_ userId: UUID) -> [UserInvite] {
        invites.filter { $0.toUserId == userId && $0.status == .pending }
    }
    
    func invitesSentByUser(_ userId: UUID) -> [UserInvite] {
        invites.filter { $0.fromUserId == userId }
    }
    
    // Get recently played courts for current user
    func recentlyPlayedCourts() -> [TennisCourt] {
        guard let user = currentUser else { return [] }
        return user.recentlyPlayedCourtIds.compactMap { courtId in
            courts.first { $0.id == courtId }
        }
    }
    
    // Get favorited courts for current user
    func favoritedCourts() -> [TennisCourt] {
        guard let user = currentUser else { return [] }
        return user.favoriteCourtIds.compactMap { courtId in
            courts.first { $0.id == courtId }
        }
    }
    
    // Add court to recently played
    func addToRecentlyPlayed(courtId: UUID) {
        guard var user = currentUser,
              let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        
        // Remove if already exists, then add to front
        user.recentlyPlayedCourtIds.removeAll { $0 == courtId }
        user.recentlyPlayedCourtIds.insert(courtId, at: 0)
        
        // Keep only last 10
        if user.recentlyPlayedCourtIds.count > 10 {
            user.recentlyPlayedCourtIds = Array(user.recentlyPlayedCourtIds.prefix(10))
        }
        
        users[index] = user
        currentUser = user
        saveData()
    }
    
    // Toggle favorite court for current user
    func toggleFavoriteCourt(courtId: UUID) {
        guard var user = currentUser,
              let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        
        if user.favoriteCourtIds.contains(courtId) {
            user.favoriteCourtIds.removeAll { $0 == courtId }
        } else {
            user.favoriteCourtIds.append(courtId)
        }
        
        users[index] = user
        currentUser = user
        saveData()
    }
    
    // MARK: - Friends Management
    
    func addFriend(_ userId: UUID) {
        guard var user = currentUser,
              let index = users.firstIndex(where: { $0.id == user.id }),
              !user.friendIds.contains(userId) else { return }
        
        user.friendIds.append(userId)
        users[index] = user
        currentUser = user
        saveData()
    }
    
    func removeFriend(_ userId: UUID) {
        guard var user = currentUser,
              let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        
        user.friendIds.removeAll { $0 == userId }
        users[index] = user
        currentUser = user
        saveData()
    }
    
    func isFriend(_ userId: UUID) -> Bool {
        currentUser?.friendIds.contains(userId) ?? false
    }
    
    func getFriends() -> [User] {
        guard let user = currentUser else { return [] }
        return user.friendIds.compactMap { friendId in
            users.first { $0.id == friendId }
        }
    }
    
    func getFriendsAvailabilities() -> [Availability] {
        let friendIds = currentUser?.friendIds ?? []
        return activeAvailabilities.filter { friendIds.contains($0.userId) }
    }
    
    // MARK: - Groups Management
    
    func createGroup(name: String, description: String, isPrivate: Bool = true) -> TennisGroup? {
        guard let userId = currentUser?.id else { return nil }
        
        let group = TennisGroup(
            name: name,
            description: description,
            creatorId: userId,
            memberIds: [userId],
            adminIds: [userId],
            isPrivate: isPrivate
        )
        
        groups.append(group)
        
        // Add group to user
        if var user = currentUser,
           let index = users.firstIndex(where: { $0.id == userId }) {
            user.groupIds.append(group.id)
            users[index] = user
            currentUser = user
        }
        
        saveData()
        return group
    }
    
    func joinGroup(_ groupId: UUID) {
        guard let userId = currentUser?.id,
              let groupIndex = groups.firstIndex(where: { $0.id == groupId }),
              !groups[groupIndex].memberIds.contains(userId) else { return }
        
        groups[groupIndex].memberIds.append(userId)
        
        // Add group to user
        if var user = currentUser,
           let userIndex = users.firstIndex(where: { $0.id == userId }) {
            user.groupIds.append(groupId)
            users[userIndex] = user
            currentUser = user
        }
        
        // Add system message
        let message = GroupMessage(
            senderId: userId,
            text: "\(currentUser?.name ?? "Someone") joined the group",
            isSystemMessage: true
        )
        groups[groupIndex].messages.append(message)
        
        saveData()
    }
    
    func leaveGroup(_ groupId: UUID) {
        guard let userId = currentUser?.id,
              let groupIndex = groups.firstIndex(where: { $0.id == groupId }) else { return }
        
        groups[groupIndex].memberIds.removeAll { $0 == userId }
        groups[groupIndex].adminIds.removeAll { $0 == userId }
        
        // Remove group from user
        if var user = currentUser,
           let userIndex = users.firstIndex(where: { $0.id == userId }) {
            user.groupIds.removeAll { $0 == groupId }
            users[userIndex] = user
            currentUser = user
        }
        
        saveData()
    }
    
    func sendGroupMessage(groupId: UUID, text: String) {
        guard let userId = currentUser?.id,
              let groupIndex = groups.firstIndex(where: { $0.id == groupId }) else { return }
        
        let message = GroupMessage(senderId: userId, text: text)
        groups[groupIndex].messages.append(message)
        saveData()
    }
    
    func getMyGroups() -> [TennisGroup] {
        guard let userId = currentUser?.id else { return [] }
        return groups.filter { $0.memberIds.contains(userId) }
    }
    
    func getGroupMembers(_ groupId: UUID) -> [User] {
        guard let group = groups.first(where: { $0.id == groupId }) else { return [] }
        return group.memberIds.compactMap { memberId in
            users.first { $0.id == memberId }
        }
    }
    
    // MARK: - Ratings Management
    
    func submitRating(matchId: UUID, toUserId: UUID, punctuality: Int, skillAccuracy: Int, sportsmanship: Int, wouldPlayAgain: Bool, comment: String = "") {
        guard let fromUserId = currentUser?.id,
              let matchIndex = matches.firstIndex(where: { $0.id == matchId }),
              let userIndex = users.firstIndex(where: { $0.id == toUserId }) else { return }
        
        let rating = PlayerRating(
            matchId: matchId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            punctuality: punctuality,
            skillAccuracy: skillAccuracy,
            sportsmanship: sportsmanship,
            wouldPlayAgain: wouldPlayAgain,
            comment: comment
        )
        
        // Add rating to recipient
        users[userIndex].ratingsReceived.append(rating)
        
        // Mark match as rated
        if matches[matchIndex].requesterId == fromUserId {
            matches[matchIndex].requesterHasRated = true
        } else {
            matches[matchIndex].accepterHasRated = true
        }
        
        // Update current user if they're the recipient
        if toUserId == currentUser?.id {
            currentUser = users[userIndex]
        }
        
        saveData()
    }
    
    func getMatchesNeedingRating() -> [Match] {
        guard let userId = currentUser?.id else { return [] }
        return matches.filter { match in
            match.status == .completed &&
            ((match.requesterId == userId && !match.requesterHasRated) ||
             (match.accepterId == userId && !match.accepterHasRated))
        }
    }
    
    func completeMatch(_ matchId: UUID) {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return }
        matches[index].status = .completed
        matches[index].endTime = Date()
        
        // Update match count for both players
        let requesterId = matches[index].requesterId
        let accepterId = matches[index].accepterId
        
        if let reqIndex = users.firstIndex(where: { $0.id == requesterId }) {
            users[reqIndex].matchesPlayed += 1
            users[reqIndex].lastPlayedDate = Date()
            updateStreak(for: reqIndex)
        }
        
        if let accIndex = users.firstIndex(where: { $0.id == accepterId }) {
            users[accIndex].matchesPlayed += 1
            users[accIndex].lastPlayedDate = Date()
            updateStreak(for: accIndex)
        }
        
        // Update current user
        if let userId = currentUser?.id {
            currentUser = users.first { $0.id == userId }
        }
        
        saveData()
    }
    
    private func updateStreak(for userIndex: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastPlayed = users[userIndex].lastPlayedDate {
            let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
            let daysDiff = calendar.dateComponents([.day], from: lastPlayedDay, to: today).day ?? 0
            
            if daysDiff <= 1 {
                users[userIndex].currentStreak += 1
                users[userIndex].longestStreak = max(users[userIndex].longestStreak, users[userIndex].currentStreak)
            } else {
                users[userIndex].currentStreak = 1
            }
        } else {
            users[userIndex].currentStreak = 1
        }
    }
    
    // MARK: - Weather (Simulated)
    
    func getWeather(for date: Date) -> WeatherInfo {
        let dateString = formatDateKey(date)
        
        // Return cached weather if available
        if let cached = weatherCache[dateString] {
            return cached
        }
        
        // Generate simulated weather based on date
        let weather = generateSimulatedWeather(for: date)
        weatherCache[dateString] = weather
        return weather
    }
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }
    
    private func generateSimulatedWeather(for date: Date) -> WeatherInfo {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let hour = calendar.component(.hour, from: date)
        
        // Base temperature by month (Massachusetts)
        let baseTemp: Int
        switch month {
        case 12, 1, 2: baseTemp = 35
        case 3, 4: baseTemp = 50
        case 5, 6: baseTemp = 68
        case 7, 8: baseTemp = 82
        case 9, 10: baseTemp = 62
        case 11: baseTemp = 45
        default: baseTemp = 65
        }
        
        // Vary by hour
        let hourVariation = hour >= 10 && hour <= 16 ? 8 : -3
        let temp = baseTemp + hourVariation + Int.random(in: -5...5)
        
        // Random conditions weighted by season
        let conditions: [WeatherCondition]
        let rainChance: Int
        switch month {
        case 3, 4, 10, 11:
            conditions = [.partlyCloudy, .cloudy, .rain, .partlyCloudy]
            rainChance = Int.random(in: 20...50)
        case 7, 8:
            conditions = [.sunny, .sunny, .partlyCloudy, .storm]
            rainChance = Int.random(in: 10...30)
        default:
            conditions = [.sunny, .partlyCloudy, .cloudy, .sunny]
            rainChance = Int.random(in: 5...25)
        }
        
        return WeatherInfo(
            temperature: temp,
            condition: conditions.randomElement() ?? .sunny,
            humidity: Int.random(in: 40...80),
            windSpeed: Int.random(in: 3...18),
            rainChance: rainChance
        )
    }
    
    // MARK: - Court Check-In
    
    func checkInAtCourt(courtId: UUID, courtsInUse: Int, totalCourts: Int, waitMinutes: Int?, leavingIn: Int?, note: String = "") {
        guard let userId = currentUser?.id,
              let courtIndex = courts.firstIndex(where: { $0.id == courtId }) else { return }
        
        let checkIn = CourtCheckIn(
            courtId: courtId,
            userId: userId,
            courtsInUse: courtsInUse,
            totalCourts: totalCourts,
            estimatedWaitMinutes: waitMinutes,
            leavingInMinutes: leavingIn,
            note: note
        )
        
        courts[courtIndex].checkIns.append(checkIn)
        
        // Update busyness patterns
        updateBusynessPattern(for: courtIndex, occupancy: Double(courtsInUse) / Double(totalCourts))
        
        saveData()
    }
    
    func updateLeavingTime(courtId: UUID, minutes: Int) {
        guard let userId = currentUser?.id,
              let courtIndex = courts.firstIndex(where: { $0.id == courtId }) else { return }
        
        if let checkInIndex = courts[courtIndex].checkIns.lastIndex(where: { $0.userId == userId && $0.isRecent }) {
            courts[courtIndex].checkIns[checkInIndex].leavingInMinutes = minutes
            saveData()
        }
    }
    
    private func updateBusynessPattern(for courtIndex: Int, occupancy: Double) {
        let calendar = Calendar.current
        let now = Date()
        let dayOfWeek = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        if let patternIndex = courts[courtIndex].busynessPatterns.firstIndex(where: {
            $0.dayOfWeek == dayOfWeek && $0.hourOfDay == hour
        }) {
            // Update existing pattern
            var pattern = courts[courtIndex].busynessPatterns[patternIndex]
            let newAvg = (pattern.averageBusyness * Double(pattern.sampleCount) + occupancy) / Double(pattern.sampleCount + 1)
            pattern.averageBusyness = newAvg
            pattern.sampleCount += 1
            courts[courtIndex].busynessPatterns[patternIndex] = pattern
        } else {
            // Create new pattern
            let pattern = CourtBusynessPattern(
                courtId: courts[courtIndex].id,
                dayOfWeek: dayOfWeek,
                hourOfDay: hour,
                averageBusyness: occupancy,
                sampleCount: 1
            )
            courts[courtIndex].busynessPatterns.append(pattern)
        }
    }
    
    func getCourtsWithRecentActivity() -> [TennisCourt] {
        courts.filter { !$0.recentCheckIns.isEmpty }
    }
    
    // MARK: - Match Statistics
    
    func getMatchStats() -> MatchStats {
        guard let userId = currentUser?.id else {
            return MatchStats()
        }
        
        let userMatches = matches.filter {
            ($0.requesterId == userId || $0.accepterId == userId) && $0.status == .completed
        }
        
        // Matches by month
        let calendar = Calendar.current
        var matchesByMonth: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        for match in userMatches {
            let key = formatter.string(from: match.scheduledTime)
            matchesByMonth[key, default: 0] += 1
        }
        
        // Most played partners
        var partnerCounts: [UUID: Int] = [:]
        for match in userMatches {
            let partnerId = match.requesterId == userId ? match.accepterId : match.requesterId
            partnerCounts[partnerId, default: 0] += 1
        }
        let topPartnerIds = partnerCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        let topPartners = topPartnerIds.compactMap { id in users.first { $0.id == id } }
        
        // Favorite courts
        var courtCounts: [UUID: Int] = [:]
        for match in userMatches {
            if let courtId = match.courtId {
                courtCounts[courtId, default: 0] += 1
            }
        }
        let topCourtIds = courtCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let favoriteCourts = topCourtIds.compactMap { id in courts.first { $0.id == id } }
        
        // Favorite time slots
        var timeSlotCounts: [Int: Int] = [:]
        for match in userMatches {
            let hour = calendar.component(.hour, from: match.scheduledTime)
            timeSlotCounts[hour, default: 0] += 1
        }
        let favoriteHours = timeSlotCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        return MatchStats(
            totalMatches: userMatches.count,
            currentStreak: currentUser?.currentStreak ?? 0,
            longestStreak: currentUser?.longestStreak ?? 0,
            matchesByMonth: matchesByMonth,
            topPartners: topPartners,
            favoriteCourts: favoriteCourts,
            favoriteHours: favoriteHours,
            trustScore: currentUser?.trustScore ?? 0,
            trustLevel: currentUser?.trustLevel ?? .new
        )
    }

    // MARK: - Sample Data
    
    private func addSampleCourts() {
        // Search for tennis courts in specified Massachusetts towns
        let towns = [
            ("Ashland, MA", CLLocationCoordinate2D(latitude: 42.2612, longitude: -71.4634)),
            ("Hopkinton, MA", CLLocationCoordinate2D(latitude: 42.2287, longitude: -71.5226)),
            ("Framingham, MA", CLLocationCoordinate2D(latitude: 42.2793, longitude: -71.4162)),
            ("Southborough, MA", CLLocationCoordinate2D(latitude: 42.3056, longitude: -71.5245)),
            ("Brighton, MA", CLLocationCoordinate2D(latitude: 42.3484, longitude: -71.1576))
        ]
        
        // Add some known courts immediately as fallback
        let knownCourts = [
            // Ashland
            TennisCourt(
                name: "Ashland High School Tennis Courts",
                address: "65 E Union St, Ashland, MA 01721",
                coordinate: Coordinate(latitude: 42.2590, longitude: -71.4590),
                numberOfCourts: 6,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Public courts at high school",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "Stone Park Tennis Courts",
                address: "Stone Park, Ashland, MA 01721",
                coordinate: Coordinate(latitude: 42.2550, longitude: -71.4620),
                numberOfCourts: 2,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Town park courts",
                isVerifiedPublic: true
            ),
            // Hopkinton
            TennisCourt(
                name: "Hopkinton High School Tennis Courts",
                address: "90 Hayden Rowe St, Hopkinton, MA 01748",
                coordinate: Coordinate(latitude: 42.2290, longitude: -71.5180),
                numberOfCourts: 8,
                courtType: .hardcourt,
                hasLights: true,
                isPublic: true,
                notes: "High school courts, lights available",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "EMC Park Tennis Courts",
                address: "EMC Park, Hopkinton, MA 01748",
                coordinate: Coordinate(latitude: 42.2310, longitude: -71.5250),
                numberOfCourts: 4,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Town park with playground nearby",
                isVerifiedPublic: true
            ),
            // Framingham
            TennisCourt(
                name: "Framingham High School Tennis Courts",
                address: "115 A St, Framingham, MA 01701",
                coordinate: Coordinate(latitude: 42.2920, longitude: -71.4280),
                numberOfCourts: 10,
                courtType: .hardcourt,
                hasLights: true,
                isPublic: true,
                notes: "Large facility with multiple courts",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "Bowditch Field Tennis Courts",
                address: "Bowditch Field, Framingham, MA 01702",
                coordinate: Coordinate(latitude: 42.2750, longitude: -71.4100),
                numberOfCourts: 4,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Near athletic fields",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "Loring Arena Tennis Courts",
                address: "347 Dudley Rd, Framingham, MA 01702",
                coordinate: Coordinate(latitude: 42.2680, longitude: -71.4350),
                numberOfCourts: 6,
                courtType: .hardcourt,
                hasLights: true,
                isPublic: true,
                notes: "Near ice arena, good parking",
                isVerifiedPublic: true
            ),
            // Southborough
            TennisCourt(
                name: "Algonquin Regional High School Courts",
                address: "79 Bartlett St, Northborough, MA 01532",
                coordinate: Coordinate(latitude: 42.3180, longitude: -71.5420),
                numberOfCourts: 8,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Regional high school, great facilities",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "Neary Elementary Tennis Courts",
                address: "53 Parkerville Rd, Southborough, MA 01772",
                coordinate: Coordinate(latitude: 42.3020, longitude: -71.5200),
                numberOfCourts: 2,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "School courts open to public",
                isVerifiedPublic: true
            ),
            // Brighton
            TennisCourt(
                name: "Rogers Park Tennis Courts",
                address: "Rogers Park Ave, Brighton, MA 02135",
                coordinate: Coordinate(latitude: 42.3520, longitude: -71.1620),
                numberOfCourts: 4,
                courtType: .hardcourt,
                hasLights: true,
                isPublic: true,
                notes: "Popular Brighton park courts",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "McKinney Playground Tennis Courts",
                address: "McKinney Playground, Brighton, MA 02135",
                coordinate: Coordinate(latitude: 42.3450, longitude: -71.1550),
                numberOfCourts: 2,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Neighborhood playground courts",
                isVerifiedPublic: true
            ),
            TennisCourt(
                name: "Cassidy Park Tennis Courts",
                address: "180 Lincoln St, Brighton, MA 02135",
                coordinate: Coordinate(latitude: 42.3580, longitude: -71.1480),
                numberOfCourts: 3,
                courtType: .hardcourt,
                hasLights: false,
                isPublic: true,
                notes: "Cleveland Circle area",
                isVerifiedPublic: true
            )
        ]
        
        courts = knownCourts
        saveData()
        
        // Also search MapKit for additional courts
        searchForTennisCourtsInTowns(towns)
    }
    
    private func searchForTennisCourtsInTowns(_ towns: [(String, CLLocationCoordinate2D)]) {
        for (townName, coordinate) in towns {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "tennis courts"
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 8000,  // ~5 mile radius
                longitudinalMeters: 8000
            )
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                guard let self = self,
                      let response = response else { return }
                
                DispatchQueue.main.async {
                    for item in response.mapItems {
                        // Check if court already exists (by similar coordinates)
                        let newCoord = Coordinate(from: item.placemark.coordinate)
                        let alreadyExists = self.courts.contains { court in
                            court.coordinate.distance(to: newCoord) < 0.1 // Within 0.1 miles
                        }
                        
                        if !alreadyExists, let name = item.name {
                            let court = TennisCourt(
                                name: name,
                                address: item.placemark.title ?? "\(townName)",
                                coordinate: newCoord,
                                numberOfCourts: 2, // Default estimate
                                courtType: .hardcourt,
                                hasLights: false,
                                isPublic: true,
                                notes: "Found via MapKit search",
                                isVerifiedPublic: false // Not verified yet
                            )
                            self.courts.append(court)
                        }
                    }
                    self.saveData()
                }
            }
        }
    }
    
    func addSampleUsers() {
        // For testing - add some sample users with availabilities
        let sampleUsers = [
            User(name: "John Smith", phone: "555-0101", skillLevels: [.intermediate]),
            User(name: "Sarah Johnson", phone: "555-0102", skillLevels: [.advanced, .intermediate]),
            User(name: "Mike Williams", phone: "555-0103", skillLevels: [.beginner]),
            User(name: "Emily Brown", phone: "555-0104", skillLevels: [.intermediate, .advanced]),
            User(name: "David Lee", phone: "555-0105", skillLevels: [.expert]),
        ]
        
        var addedUsers: [User] = []
        
        for user in sampleUsers {
            if !users.contains(where: { $0.phone == user.phone }) {
                users.append(user)
                addedUsers.append(user)
            }
        }
        
        // Add sample availabilities for the new test users
        let calendar = Calendar.current
        let now = Date()
        
        for (index, user) in addedUsers.enumerated() {
            // Create availability starting tomorrow + index days, at different times
            let hoursToAdd = [9, 14, 17, 10, 18][index % 5]
            
            if let tomorrow = calendar.date(byAdding: .day, value: index + 1, to: now),
               let startTime = calendar.date(bySettingHour: hoursToAdd, minute: 0, second: 0, of: tomorrow) {
                
                // Assign preferred courts
                let preferredCourt = courts.first?.id
                let secondaryCourt = courts.count > 1 ? courts[1].id : nil
                
                let availability = Availability(
                    userId: user.id,
                    preferredCourtId: preferredCourt,
                    secondaryCourtId: secondaryCourt,
                    startTime: startTime,
                    endTime: startTime.addingTimeInterval(5400), // 1.5 hours
                    skillLevelRange: 0...3,
                    matchType: index % 2 == 0 ? .singles : .either,
                    notes: ["Looking for a friendly match", "Competitive play preferred", "Just want to hit around", "Down for singles or doubles", "Looking to improve my game"][index % 5]
                )
                availabilities.append(availability)
            }
        }
        
        saveData()
    }
    
    // MARK: - Search Local Courts
    
    func searchTennisCourtsInArea(completion: @escaping (Int) -> Void) {
        // Towns to search: Ashland, Hopkinton, Framingham, Southborough, Brighton MA
        let townCoordinates: [(name: String, lat: Double, lon: Double)] = [
            ("Ashland, MA", 42.2612, -71.4634),
            ("Hopkinton, MA", 42.2287, -71.5226),
            ("Framingham, MA", 42.2793, -71.4162),
            ("Southborough, MA", 42.3056, -71.5245),
            ("Brighton, MA", 42.3484, -71.1578)
        ]
        
        var totalAdded = 0
        let group = DispatchGroup()
        
        for town in townCoordinates {
            group.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "tennis courts"
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: town.lat, longitude: town.lon),
                latitudinalMeters: 8000,  // ~5 mile radius
                longitudinalMeters: 8000
            )
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                defer { group.leave() }
                
                guard let self = self,
                      let response = response else { return }
                
                for item in response.mapItems {
                    // Check if court already exists (by coordinate proximity)
                    let newCoord = Coordinate(from: item.placemark.coordinate)
                    let alreadyExists = self.courts.contains { existingCourt in
                        existingCourt.coordinate.distance(to: newCoord) < 0.1 // Within 0.1 miles
                    }
                    
                    if !alreadyExists {
                        let court = TennisCourt(
                            name: item.name ?? "Tennis Court",
                            address: item.placemark.title ?? "\(town.name)",
                            coordinate: newCoord,
                            numberOfCourts: 2, // Default estimate
                            courtType: .hardcourt, // Default
                            hasLights: false, // Default - unknown
                            isPublic: true, // Assume public unless noted
                            notes: "Found via MapKit search in \(town.name)",
                            isVerifiedPublic: false
                        )
                        
                        DispatchQueue.main.async {
                            self.courts.append(court)
                            totalAdded += 1
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.saveData()
            completion(totalAdded)
        }
    }
    
    func resetAllData() {
        currentUser = nil
        users = []
        courts = []
        availabilities = []
        matches = []
        directMessages = []
        invites = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        addSampleCourts()
    }
}

struct AppData: Codable {
    var currentUserId: UUID?
    var users: [User]
    var courts: [TennisCourt]
    var availabilities: [Availability]
    var matches: [Match]
    var directMessages: [DirectMessage] = []
    var invites: [UserInvite] = []
    var groups: [TennisGroup] = []
}

// MARK: - Match Statistics

struct MatchStats {
    var totalMatches: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var matchesByMonth: [String: Int] = [:]
    var topPartners: [User] = []
    var favoriteCourts: [TennisCourt] = []
    var favoriteHours: [Int] = []
    var trustScore: Double = 0
    var trustLevel: TrustLevel = .new
    
    var favoriteTimeSlots: [String] {
        favoriteHours.map { hour in
            let period = hour >= 12 ? "PM" : "AM"
            let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
            return "\(displayHour):00 \(period)"
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var callback: ((CLLocationCoordinate2D) -> Void)?
    
    init(callback: @escaping (CLLocationCoordinate2D) -> Void) {
        self.callback = callback
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            callback?(location.coordinate)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Onboarding View (Single Step - Combined)

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedSkillLevels: Set<SkillLevel> = [.intermediate]
    @State private var showPhoneError = false
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.count >= 10 &&
        !selectedSkillLevels.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "tennis.racket")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Tennis Match Finder")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("Create your profile to find tennis partners")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Form Section - About You
                    VStack(alignment: .leading, spacing: 20) {
                        Text("About You")
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Name (single field)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                                TextField("First and Last Name", text: $name)
                                    .textContentType(.name)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                            
                            // Phone
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                                TextField("Phone number", text: $phone)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(showPhoneError ? Color.red : Color.clear, lineWidth: 1)
                                    )
                                
                                Text("Used for match confirmations and alerts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Skill Level Section
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Skill Level")
                                .font(.title2.weight(.semibold))
                            Text("Select 1 or 2 levels that match your play style")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ForEach(SkillLevel.allCases) { level in
                                Button(action: { toggleSkillLevel(level) }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(level.rawValue)
                                                .font(.subheadline.weight(.medium))
                                            Text("NTRP \(level.ntrpRange)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedSkillLevels.contains(level) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title3)
                                        }
                                    }
                                    .padding()
                                    .background(selectedSkillLevels.contains(level) ? level.color.opacity(0.15) : Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedSkillLevels.contains(level) ? level.color : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        if selectedSkillLevels.count == 2 {
                            Text("✓ Two skill levels selected")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Complete Button
                    Button(action: createUser) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValid ? Color.green : Color.gray)
                            .cornerRadius(14)
                    }
                    .disabled(!isValid)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    func toggleSkillLevel(_ level: SkillLevel) {
        if selectedSkillLevels.contains(level) {
            // Don't allow deselecting if it's the only one
            if selectedSkillLevels.count > 1 {
                selectedSkillLevels.remove(level)
            }
        } else {
            // Max 2 selections
            if selectedSkillLevels.count < 2 {
                selectedSkillLevels.insert(level)
            } else {
                // Replace the first one (or oldest)
                if let first = selectedSkillLevels.first {
                    selectedSkillLevels.remove(first)
                }
                selectedSkillLevels.insert(level)
            }
        }
    }
    
    func createUser() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return
        }
        if phone.trimmingCharacters(in: .whitespaces).isEmpty || phone.count < 10 {
            showPhoneError = true
            return
        }
        
        let user = User(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone,
            skillLevels: Array(selectedSkillLevels).sorted { $0.sortOrder < $1.sortOrder },
            homeLocation: appState.userLocation != nil ? Coordinate(from: appState.userLocation!) : nil
        )
        appState.createUser(user)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0
    
    var matchesNeedingRating: Int {
        appState.getMatchesNeedingRating().count
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FindMatchView(appState: appState)
                .tabItem {
                    Label("Find Match", systemImage: "magnifyingglass")
                }
                .tag(0)
            
            FriendsGroupsView(appState: appState)
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
            
            CourtsMapView(appState: appState)
                .tabItem {
                    Label("Courts", systemImage: "map.fill")
                }
                .tag(2)
            
            MyMatchesView(appState: appState)
                .tabItem {
                    Label("Matches", systemImage: "calendar")
                }
                .badge(matchesNeedingRating > 0 ? matchesNeedingRating : 0)
                .tag(3)
            
            ProfileView(appState: appState)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(.green)
    }
}

// MARK: - Find Match View

struct FindMatchView: View {
    @ObservedObject var appState: AppState
    @State private var showingPostAvailability = false
    @State private var showingInviteUser = false
    @State private var selectedAvailability: Availability?
    @State private var viewingAvailability: Availability?
    @State private var showingMessageSheet: (User, Availability)? = nil
    
    var otherAvailabilities: [Availability] {
        guard let userId = appState.currentUser?.id else { return [] }
        return appState.availabilitiesForOthers(excluding: userId)
            .sorted { $0.startTime < $1.startTime }
    }
    
    var pendingInvites: [UserInvite] {
        guard let userId = appState.currentUser?.id else { return [] }
        return appState.invitesForUser(userId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Action cards
                    HStack(spacing: 12) {
                        // Post availability card
                        ActionCard(
                            icon: "plus.circle.fill",
                            title: "Post Availability",
                            subtitle: "Let others know when you can play",
                            color: .green
                        ) {
                            showingPostAvailability = true
                        }
                        
                        // Invite specific user card
                        ActionCard(
                            icon: "person.badge.plus",
                            title: "Invite User",
                            subtitle: "Send invite to a specific player",
                            color: .blue
                        ) {
                            showingInviteUser = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // Pending invites section
                    if !pendingInvites.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Invites for You")
                                    .font(.headline)
                                Spacer()
                                Text("\(pendingInvites.count)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            ForEach(pendingInvites) { invite in
                                if let user = appState.getUser(by: invite.fromUserId) {
                                    InviteCard(
                                        invite: invite,
                                        user: user,
                                        appState: appState
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Available players section
                    if otherAvailabilities.isEmpty && pendingInvites.isEmpty {
                        EmptyAvailabilityView()
                            .padding(.top, 40)
                    } else if !otherAvailabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Available Players")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(otherAvailabilities) { availability in
                                if let user = appState.getUser(by: availability.userId) {
                                    AvailabilityCard(
                                        availability: availability,
                                        user: user,
                                        appState: appState,
                                        onView: {
                                            viewingAvailability = availability
                                        },
                                        onMessage: {
                                            showingMessageSheet = (user, availability)
                                        },
                                        onAccept: {
                                            selectedAvailability = availability
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Find a Match")
            .sheet(isPresented: $showingPostAvailability) {
                PostAvailabilitySheet(appState: appState)
            }
            .sheet(isPresented: $showingInviteUser) {
                InviteUserSheet(appState: appState)
            }
            .sheet(item: $selectedAvailability) { availability in
                AcceptMatchSheet(appState: appState, availability: availability)
            }
            .sheet(item: $viewingAvailability) { availability in
                AvailabilityDetailSheet(appState: appState, availability: availability)
            }
            .sheet(item: Binding(
                get: { showingMessageSheet.map { MessageSheetData(user: $0.0, availability: $0.1) } },
                set: { _ in showingMessageSheet = nil }
            )) { data in
                DirectMessageSheet(appState: appState, recipient: data.user, availability: data.availability)
            }
        }
    }
}

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct InviteCard: View {
    let invite: UserInvite
    let user: User
    @ObservedObject var appState: AppState
    @State private var showingDetail = false
    
    var preferredCourt: TennisCourt? {
        guard let courtId = invite.preferredCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(user.skillLevel.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Text(user.initials)
                        .font(.headline)
                        .foregroundColor(user.skillLevel.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.headline)
                    Text("\(formatSkillLevels(user.skillLevels)) • Invited you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("INVITE")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
            
            // Proposed times
            VStack(alignment: .leading, spacing: 4) {
                Text("Proposed times:")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                ForEach(invite.proposedTimes.prefix(3), id: \.self) { time in
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(time, format: .dateTime.weekday().month().day().hour().minute())
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Preferred court
            if let court = preferredCourt {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(court.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: { showingDetail = true }) {
                    HStack {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: { showingDetail = true }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Respond")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .sheet(isPresented: $showingDetail) {
            InviteDetailSheet(appState: appState, invite: invite)
        }
    }
}

struct MessageSheetData: Identifiable {
    let user: User
    let availability: Availability
    var id: UUID { user.id }
}

struct EmptyAvailabilityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Players Available")
                .font(.headline)
            
            Text("Be the first to post your availability\nor check back later")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct AvailabilityCard: View {
    let availability: Availability
    let user: User
    @ObservedObject var appState: AppState
    var onView: () -> Void
    var onMessage: () -> Void
    var onAccept: () -> Void
    
    @State private var timeRemaining: String = ""
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var preferredCourt: TennisCourt? {
        guard let courtId = availability.preferredCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var secondaryCourt: TennisCourt? {
        guard let courtId = availability.secondaryCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var skillLevelText: String {
        if user.skillLevels.count == 2 {
            let sorted = user.skillLevels.sorted { $0.sortOrder < $1.sortOrder }
            return "\(sorted[0].rawValue) / \(sorted[1].rawValue)"
        }
        return user.skillLevel.rawValue
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with centered name and countdown
            VStack(spacing: 8) {
                // Name centered with countdown on right
                HStack {
                    Spacer()
                    
                    // Centered name
                    Text(user.name)
                        .font(.title3.weight(.bold))
                    
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    // Countdown badge
                    Text(timeRemaining)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(countdownColor)
                        .cornerRadius(8)
                }
                
                // Skill level and match type
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(user.skillLevel.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text(user.initials)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(user.skillLevel.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Label(skillLevelText, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(user.skillLevel.color)
                        
                        Label(availability.matchType.rawValue, systemImage: availability.matchType.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Duration badge
                    Text(availability.durationFormatted)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Divider
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            
            // Details section
            VStack(alignment: .leading, spacing: 12) {
                // Time info with weather
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(availability.startTime, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.subheadline.weight(.medium))
                        HStack {
                            Text(availability.startTime, style: .time)
                            Text("-")
                            Text(availability.endTime, style: .time)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Weather badge
                    let weather = appState.getWeather(for: availability.startTime)
                    WeatherBadge(weather: weather)
                }
                
                // Preferred Courts
                if let court = preferredCourt {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(court.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let secondary = secondaryCourt {
                            HStack(spacing: 8) {
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(secondary.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Notes
                if !availability.notes.isEmpty {
                    Text(availability.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onView) {
                    HStack {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: onMessage) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Message")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
    }
    
    var countdownColor: Color {
        let interval = availability.startTime.timeIntervalSince(Date())
        if interval < 3600 { // Less than 1 hour
            return .red
        } else if interval < 86400 { // Less than 1 day
            return .orange
        } else {
            return .blue
        }
    }
    
    func updateCountdown() {
        let interval = availability.startTime.timeIntervalSince(Date())
        
        if interval <= 0 {
            timeRemaining = "Now!"
            return
        }
        
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            timeRemaining = "\(days)d \(hours)h"
        } else if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "\(minutes)m"
        }
    }
}

// MARK: - Direct Message Sheet

struct DirectMessageSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let recipient: User
    let availability: Availability?
    
    @State private var messageText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipient info
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(recipient.skillLevel.color.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Text(recipient.initials)
                            .font(.headline)
                            .foregroundColor(recipient.skillLevel.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipient.name)
                            .font(.headline)
                        Text(recipient.skillLevel.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Previous messages
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.getDirectMessages(with: recipient.id)) { message in
                            let isFromMe = message.fromUserId == appState.currentUser?.id
                            HStack {
                                if isFromMe { Spacer() }
                                Text(message.text)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(isFromMe ? Color.green : Color(.secondarySystemBackground))
                                    .foregroundColor(isFromMe ? .white : .primary)
                                    .cornerRadius(18)
                                if !isFromMe { Spacer() }
                            }
                        }
                        
                        if appState.getDirectMessages(with: recipient.id).isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Start a conversation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(messageText.isEmpty ? .gray : .green)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                appState.markMessagesAsRead(from: recipient.id)
            }
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        appState.sendDirectMessage(to: recipient.id, text: messageText)
        messageText = ""
    }
}

// MARK: - Post Availability Sheet

struct PostAvailabilitySheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var duration: TimeInterval = 3600 // 1 hour
    @State private var matchType: MatchType = .either
    @State private var preferredCourtId: UUID?
    @State private var secondaryCourtId: UUID?
    @State private var notes = ""
    @State private var minSkill: SkillLevel = .beginner
    @State private var maxSkill: SkillLevel = .expert
    @State private var selectedCourtTab = 0
    
    let durations: [(String, TimeInterval)] = [
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("2.5 hours", 9000),
        ("3 hours", 10800)
    ]
    
    let hours = Array(6...21)  // 6 AM to 9 PM
    let minutes = [0, 15, 30, 45]
    
    var startTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = selectedHour
        components.minute = selectedMinute
        return calendar.date(from: components) ?? selectedDate
    }
    
    var recentlyPlayedCourts: [TennisCourt] {
        appState.recentlyPlayedCourts()
    }
    
    var favoritedCourts: [TennisCourt] {
        appState.favoritedCourts()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        
                        Picker("", selection: $selectedHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        
                        Text(":")
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                }
                
                Section("Match Type") {
                    Picker("Type", selection: $matchType) {
                        ForEach(MatchType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Court Selection with Tabs
                Section {
                    Picker("", selection: $selectedCourtTab) {
                        Text("Recently Played").tag(0)
                        Text("Favorites").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    if selectedCourtTab == 0 {
                        // Recently Played Courts
                        if recentlyPlayedCourts.isEmpty {
                            Text("No recently played courts")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(recentlyPlayedCourts) { court in
                                CourtSelectionRow(
                                    court: court,
                                    isPrimary: preferredCourtId == court.id,
                                    isSecondary: secondaryCourtId == court.id,
                                    onSelect: { selectCourt(court.id) }
                                )
                            }
                        }
                    } else {
                        // Favorited Courts
                        if favoritedCourts.isEmpty {
                            Text("No favorited courts yet")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(favoritedCourts) { court in
                                CourtSelectionRow(
                                    court: court,
                                    isPrimary: preferredCourtId == court.id,
                                    isSecondary: secondaryCourtId == court.id,
                                    onSelect: { selectCourt(court.id) }
                                )
                            }
                        }
                    }
                    
                    // Show selected courts
                    if preferredCourtId != nil || secondaryCourtId != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            if let primary = preferredCourtId,
                               let court = appState.courts.first(where: { $0.id == primary }) {
                                HStack {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundColor(.green)
                                    Text("1st: \(court.name)")
                                        .font(.caption)
                                }
                            }
                            if let secondary = secondaryCourtId,
                               let court = appState.courts.first(where: { $0.id == secondary }) {
                                HStack {
                                    Image(systemName: "2.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("2nd: \(court.name)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Text("Tap once for 1st choice, twice for 2nd")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Courts")
                }
                
                Section("Skill Level Range") {
                    HStack {
                        Text("Min:")
                        Picker("", selection: $minSkill) {
                            ForEach(SkillLevel.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Max:")
                        Picker("", selection: $maxSkill) {
                            ForEach(SkillLevel.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("e.g., Looking for competitive match", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Post Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        postAvailability()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize with current time rounded to next 15 minutes
                let calendar = Calendar.current
                let now = Date()
                selectedHour = calendar.component(.hour, from: now)
                let currentMinute = calendar.component(.minute, from: now)
                selectedMinute = ((currentMinute / 15) + 1) * 15
                if selectedMinute >= 60 {
                    selectedMinute = 0
                    selectedHour += 1
                }
                if selectedHour > 21 {
                    selectedHour = 9
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                }
            }
        }
    }
    
    func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 12 {
            return "12 \(hour < 12 ? "AM" : "PM")"
        } else if hour < 12 {
            return "\(hour) AM"
        } else {
            return "\(hour - 12) PM"
        }
    }
    
    func selectCourt(_ courtId: UUID) {
        if preferredCourtId == courtId {
            // Already primary, make it secondary
            preferredCourtId = nil
            secondaryCourtId = courtId
        } else if secondaryCourtId == courtId {
            // Already secondary, deselect
            secondaryCourtId = nil
        } else if preferredCourtId == nil {
            // No primary, set as primary
            preferredCourtId = courtId
        } else if secondaryCourtId == nil {
            // Has primary but no secondary, set as secondary
            secondaryCourtId = courtId
        } else {
            // Both set, replace primary
            secondaryCourtId = preferredCourtId
            preferredCourtId = courtId
        }
    }
    
    func postAvailability() {
        guard let userId = appState.currentUser?.id else { return }
        
        let availability = Availability(
            userId: userId,
            preferredCourtId: preferredCourtId,
            secondaryCourtId: secondaryCourtId,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
            skillLevelRange: skillLevelIndex(minSkill)...skillLevelIndex(maxSkill),
            matchType: matchType,
            notes: notes
        )
        
        appState.postAvailability(availability)
    }
    
    func skillLevelIndex(_ level: SkillLevel) -> Int {
        SkillLevel.allCases.firstIndex(of: level) ?? 0
    }
}

struct CourtSelectionRow: View {
    let court: TennisCourt
    let isPrimary: Bool
    let isSecondary: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(court.name)
                    Text("\(court.numberOfCourts) courts • \(court.courtType.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isPrimary {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.green)
                } else if isSecondary {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accept Match Sheet

struct AcceptMatchSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let availability: Availability
    
    @State private var selectedCourt: TennisCourt?
    @State private var message = ""
    
    var user: User? {
        appState.getUser(by: availability.userId)
    }
    
    var preferredCourt: TennisCourt? {
        guard let courtId = availability.preferredCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var secondaryCourt: TennisCourt? {
        guard let courtId = availability.secondaryCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User card
                    if let user = user {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.skillLevel.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Text(user.initials)
                                    .font(.title)
                                    .foregroundColor(user.skillLevel.color)
                            }
                            
                            Text(user.name)
                                .font(.title2.weight(.bold))
                            
                            HStack(spacing: 16) {
                                Label(user.skillLevel.rawValue, systemImage: "star.fill")
                                    .foregroundColor(user.skillLevel.color)
                                Label("\(user.matchesPlayed) matches", systemImage: "sportscourt.fill")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding()
                    }
                    
                    // Time info
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                            Text(availability.startTime, style: .date)
                                .font(.headline)
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.green)
                            Text("\(availability.startTime, style: .time) - \(availability.endTime, style: .time)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Inviter's preferred courts
                    if preferredCourt != nil || secondaryCourt != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Their Preferred Courts")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if let court = preferredCourt {
                                CourtOptionCard(
                                    court: court,
                                    label: "1st Choice",
                                    labelColor: .green,
                                    isSelected: selectedCourt?.id == court.id,
                                    busynessTime: availability.startTime
                                ) {
                                    selectedCourt = court
                                }
                                .padding(.horizontal)
                            }
                            
                            if let court = secondaryCourt {
                                CourtOptionCard(
                                    court: court,
                                    label: "2nd Choice",
                                    labelColor: .orange,
                                    isSelected: selectedCourt?.id == court.id,
                                    busynessTime: availability.startTime
                                ) {
                                    selectedCourt = court
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Or select different court
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or Choose Another Court")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(appState.courts.filter { court in
                            court.id != preferredCourt?.id && court.id != secondaryCourt?.id
                        }) { court in
                            Button(action: { selectedCourt = court }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(court.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(court.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    let busyness = court.currentBusyness(at: availability.startTime)
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(busyness.color)
                                            .frame(width: 8, height: 8)
                                        Text(busyness.label)
                                            .font(.caption)
                                            .foregroundColor(busyness.color)
                                    }
                                    
                                    if selectedCourt?.id == court.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(selectedCourt?.id == court.id ? Color.green.opacity(0.1) : Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message (Optional)")
                            .font(.headline)
                        
                        TextField("Say hi or suggest details...", text: $message, axis: .vertical)
                            .lineLimit(3...5)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Accept Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") {
                        acceptMatch()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Pre-select their preferred court
                if selectedCourt == nil {
                    selectedCourt = preferredCourt
                }
            }
        }
    }
    
    func acceptMatch() {
        guard let userId = appState.currentUser?.id else { return }
        
        var match = appState.acceptMatch(
            availability: availability,
            accepterId: userId,
            courtId: selectedCourt?.id
        )
        
        // Add court to recently played
        if let courtId = selectedCourt?.id {
            appState.addToRecentlyPlayed(courtId: courtId)
        }
        
        // Add initial message if provided
        if !message.isEmpty {
            let msg = MatchMessage(senderId: userId, text: message)
            if let index = appState.matches.firstIndex(where: { $0.id == match.id }) {
                appState.matches[index].messages.append(msg)
                appState.saveData()
            }
        }
    }
}

struct CourtOptionCard: View {
    let court: TennisCourt
    let label: String
    let labelColor: Color
    let isSelected: Bool
    let busynessTime: Date
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(labelColor)
                        Spacer()
                    }
                    Text(court.name)
                        .font(.subheadline.weight(.medium))
                    Text(court.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                let busyness = court.currentBusyness(at: busynessTime)
                HStack(spacing: 4) {
                    Circle()
                        .fill(busyness.color)
                        .frame(width: 8, height: 8)
                    Text(busyness.label)
                        .font(.caption)
                        .foregroundColor(busyness.color)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(labelColor.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Availability Detail Sheet

struct AvailabilityDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let availability: Availability
    
    var user: User? {
        appState.getUser(by: availability.userId)
    }
    
    var preferredCourt: TennisCourt? {
        guard let courtId = availability.preferredCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var secondaryCourt: TennisCourt? {
        guard let courtId = availability.secondaryCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User info
                    if let user = user {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.skillLevel.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Text(user.initials)
                                    .font(.title)
                                    .foregroundColor(user.skillLevel.color)
                            }
                            
                            Text(user.name)
                                .font(.title2.weight(.bold))
                            
                            HStack(spacing: 16) {
                                Label(user.skillLevel.rawValue, systemImage: "star.fill")
                                    .foregroundColor(user.skillLevel.color)
                                Label("\(user.matchesPlayed) matches", systemImage: "sportscourt.fill")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                            
                            // Contact info
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.green)
                                    Text(user.phone)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Time details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Availability")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.green)
                                    Text(availability.startTime, format: .dateTime.weekday(.wide).month().day())
                                }
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.green)
                                    Text("\(availability.startTime, style: .time) - \(availability.endTime, style: .time)")
                                }
                                
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundColor(.green)
                                    Text("Duration: \(availability.durationFormatted)")
                                }
                            }
                            .font(.subheadline)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Match type
                    HStack {
                        Image(systemName: availability.matchType.icon)
                            .foregroundColor(.blue)
                        Text(availability.matchType.rawValue)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Preferred courts
                    if preferredCourt != nil || secondaryCourt != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferred Courts")
                                .font(.headline)
                            
                            if let court = preferredCourt {
                                HStack {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading) {
                                        Text(court.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(court.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            
                            if let court = secondaryCourt {
                                HStack {
                                    Image(systemName: "2.circle.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading) {
                                        Text(court.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(court.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Notes
                    if !availability.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(availability.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Availability Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Invite User Sheet

struct InviteUserSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedUser: User?
    @State private var proposedTimes: [Date] = []
    @State private var preferredCourtId: UUID?
    @State private var secondaryCourtId: UUID?
    @State private var duration: TimeInterval = 3600
    @State private var matchType: MatchType = .singles
    @State private var notes = ""
    @State private var showingTimePicker = false
    @State private var newTime = Date()
    
    var otherUsers: [User] {
        guard let currentUserId = appState.currentUser?.id else { return [] }
        return appState.users.filter { $0.id != currentUserId }
    }
    
    let durations: [(String, TimeInterval)] = [
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Select user
                Section("Select Player") {
                    ForEach(otherUsers) { user in
                        Button(action: { selectedUser = user }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(user.skillLevel.color.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Text(user.initials)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(user.skillLevel.color)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(user.skillLevel.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedUser?.id == user.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Proposed times
                Section {
                    ForEach(proposedTimes.indices, id: \.self) { index in
                        HStack {
                            Text(proposedTimes[index], format: .dateTime.weekday().month().day().hour().minute())
                                .font(.subheadline)
                            Spacer()
                            Button(action: { proposedTimes.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: { showingTimePicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Time")
                        }
                    }
                } header: {
                    Text("Proposed Times (next 2 weeks)")
                } footer: {
                    Text("Add multiple time options for flexibility")
                }
                
                // Duration
                Section("Duration") {
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Match type
                Section("Match Type") {
                    Picker("Type", selection: $matchType) {
                        ForEach(MatchType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Courts
                Section("Preferred Courts") {
                    ForEach(appState.courts) { court in
                        Button(action: { selectCourt(court.id) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(court.name)
                                    Text(court.courtType.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if preferredCourtId == court.id {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundColor(.green)
                                } else if secondaryCourtId == court.id {
                                    Image(systemName: "2.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Notes
                Section("Message (Optional)") {
                    TextField("Add a personal message...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Invite Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send Invite") {
                        sendInvite()
                        dismiss()
                    }
                    .disabled(selectedUser == nil || proposedTimes.isEmpty)
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerSheet(selectedTime: $newTime) {
                    if !proposedTimes.contains(newTime) {
                        proposedTimes.append(newTime)
                        proposedTimes.sort()
                    }
                }
            }
        }
    }
    
    func selectCourt(_ courtId: UUID) {
        if preferredCourtId == courtId {
            preferredCourtId = nil
            secondaryCourtId = courtId
        } else if secondaryCourtId == courtId {
            secondaryCourtId = nil
        } else if preferredCourtId == nil {
            preferredCourtId = courtId
        } else {
            secondaryCourtId = courtId
        }
    }
    
    func sendInvite() {
        guard let fromUserId = appState.currentUser?.id,
              let toUser = selectedUser,
              !proposedTimes.isEmpty else { return }
        
        let invite = UserInvite(
            fromUserId: fromUserId,
            toUserId: toUser.id,
            preferredCourtId: preferredCourtId,
            secondaryCourtId: secondaryCourtId,
            proposedTimes: proposedTimes,
            duration: duration,
            matchType: matchType,
            notes: notes
        )
        
        appState.sendInvite(invite)
    }
}

struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @Environment(\.dismiss) var dismiss
    let onAdd: () -> Void
    
    var twoWeeksFromNow: Date {
        Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select Time",
                    selection: $selectedTime,
                    in: Date()...twoWeeksFromNow,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Add Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Invite Detail Sheet

struct InviteDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let invite: UserInvite
    
    @State private var selectedTime: Date?
    
    var fromUser: User? {
        appState.getUser(by: invite.fromUserId)
    }
    
    var preferredCourt: TennisCourt? {
        guard let courtId = invite.preferredCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var secondaryCourt: TennisCourt? {
        guard let courtId = invite.secondaryCourtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // From user
                    if let user = fromUser {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.skillLevel.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Text(user.initials)
                                    .font(.title)
                                    .foregroundColor(user.skillLevel.color)
                            }
                            
                            Text(user.name)
                                .font(.title2.weight(.bold))
                            
                            Text("wants to play \(invite.matchType.rawValue.lowercased())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Label(user.skillLevel.rawValue, systemImage: "star.fill")
                                    .foregroundColor(user.skillLevel.color)
                                Label("\(user.matchesPlayed) matches", systemImage: "sportscourt.fill")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding()
                    }
                    
                    // Select a time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select a Time")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(invite.proposedTimes, id: \.self) { time in
                            Button(action: { selectedTime = time }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(time, format: .dateTime.weekday(.wide).month().day())
                                            .font(.subheadline.weight(.medium))
                                        Text(time, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedTime == time {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(selectedTime == time ? Color.green.opacity(0.1) : Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Courts
                    if preferredCourt != nil || secondaryCourt != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferred Courts")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if let court = preferredCourt {
                                HStack {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundColor(.green)
                                    Text(court.name)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            if let court = secondaryCourt {
                                HStack {
                                    Image(systemName: "2.circle.fill")
                                        .foregroundColor(.orange)
                                    Text(court.name)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Notes
                    if !invite.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.headline)
                            Text(invite.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: declineInvite) {
                            Text("Decline")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: acceptInvite) {
                            Text("Accept")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedTime == nil ? Color.gray : Color.green)
                                .cornerRadius(12)
                        }
                        .disabled(selectedTime == nil)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    func acceptInvite() {
        guard let time = selectedTime else { return }
        appState.acceptInvite(invite, selectedTime: time)
        dismiss()
    }
    
    func declineInvite() {
        appState.declineInvite(invite)
        dismiss()
    }
}

// MARK: - Courts Map View

struct CourtsMapView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTime = Date()
    @State private var showingAddCourt = false
    @State private var selectedCourt: TennisCourt?
    @State private var selectedFilter: CourtFilter = .all
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.0654, longitude: -71.2345),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var mapCenter: Coordinate?
    
    var filteredCourts: [TennisCourt] {
        appState.filteredCourts(filter: selectedFilter, mapCenter: mapCenter)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Map
                CourtsMapRepresentable(
                    courts: filteredCourts,
                    selectedTime: selectedTime,
                    userLocation: appState.userLocation,
                    selectedCourt: $selectedCourt,
                    region: $mapRegion,
                    onRegionChange: { newCenter in
                        mapCenter = Coordinate(from: newCenter)
                    }
                )
                .ignoresSafeArea(edges: .top)
                
                VStack(spacing: 0) {
                    // Filter buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CourtFilter.allCases) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: filter.icon)
                                        Text(filter.rawValue)
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.green : Color(.systemBackground))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(.ultraThinMaterial)
                    
                    Spacer()
                    
                    // Time picker & Legend
                    VStack(spacing: 12) {
                        HStack {
                            Text("Court busyness at:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $selectedTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                        
                        // Legend
                        HStack(spacing: 16) {
                            ForEach(BusynessLevel.allCases) { level in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(level.color)
                                        .frame(width: 10, height: 10)
                                    Text(level.label)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        // Court count
                        Text("\(filteredCourts.count) courts within 50 miles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                }
            }
            .navigationTitle("Courts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCourt = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCourt) {
                AddCourtSheet(appState: appState)
            }
            .sheet(item: $selectedCourt) { court in
                CourtDetailSheet(appState: appState, court: court)
            }
        }
    }
}

struct CourtsMapRepresentable: UIViewRepresentable {
    let courts: [TennisCourt]
    let selectedTime: Date
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedCourt: TennisCourt?
    @Binding var region: MKCoordinateRegion
    var onRegionChange: ((CLLocationCoordinate2D) -> Void)?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove old annotations (except user location)
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)
        
        // Add court annotations
        for court in courts {
            let annotation = CourtAnnotation(court: court, busyness: court.currentBusyness(at: selectedTime))
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CourtsMapRepresentable
        
        init(_ parent: CourtsMapRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            guard let courtAnnotation = annotation as? CourtAnnotation else { return nil }
            
            let identifier = "CourtPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                view?.annotation = annotation
            }
            
            view?.markerTintColor = UIColor(courtAnnotation.busyness.color)
            view?.glyphImage = UIImage(systemName: "tennis.racket")
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let courtAnnotation = view.annotation as? CourtAnnotation {
                parent.selectedCourt = courtAnnotation.court
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange?(mapView.centerCoordinate)
        }
    }
}

class CourtAnnotation: NSObject, MKAnnotation {
    let court: TennisCourt
    let busyness: BusynessLevel
    
    var coordinate: CLLocationCoordinate2D {
        court.coordinate.clCoordinate
    }
    
    var title: String? {
        court.name
    }
    
    var subtitle: String? {
        "\(court.numberOfCourts) courts • \(busyness.label)"
    }
    
    init(court: TennisCourt, busyness: BusynessLevel) {
        self.court = court
        self.busyness = busyness
    }
}

// MARK: - Add Court Sheet

struct AddCourtSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var numberOfCourts = 2
    @State private var courtType: CourtType = .hardcourt
    @State private var hasLights = false
    @State private var isPublic = true
    @State private var notes = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isSearching = false
    @State private var searchResults: [MKMapItem] = []
    
    var isValid: Bool {
        !name.isEmpty && !address.isEmpty && coordinate != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Court Info") {
                    TextField("Court Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Address", text: $address)
                            .onChange(of: address) { _, newValue in
                                if newValue.count > 3 {
                                    searchAddress(newValue)
                                }
                            }
                        
                        if isSearching {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        ForEach(searchResults, id: \.self) { item in
                            Button(action: { selectSearchResult(item) }) {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if coordinate != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location set")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section("Details") {
                    Stepper("Number of Courts: \(numberOfCourts)", value: $numberOfCourts, in: 1...20)
                    
                    Picker("Court Type", selection: $courtType) {
                        ForEach(CourtType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    
                    Toggle("Has Lights", isOn: $hasLights)
                    Toggle("Public Access", isOn: $isPublic)
                }
                
                Section("Notes") {
                    TextField("Additional info...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Button("Search for Tennis Courts Nearby") {
                        searchNearbyTennisCourts()
                    }
                }
            }
            .navigationTitle("Add Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCourt()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    func searchAddress(_ query: String) {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let userLocation = appState.userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            searchResults = response?.mapItems.prefix(5).map { $0 } ?? []
        }
    }
    
    func searchNearbyTennisCourts() {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "tennis courts"
        
        if let userLocation = appState.userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 20000,
                longitudinalMeters: 20000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            searchResults = response?.mapItems ?? []
        }
    }
    
    func selectSearchResult(_ item: MKMapItem) {
        name = item.name ?? name
        address = item.placemark.title ?? ""
        coordinate = item.placemark.coordinate
        searchResults = []
    }
    
    func addCourt() {
        guard let coord = coordinate else { return }
        
        let court = TennisCourt(
            name: name,
            address: address,
            coordinate: Coordinate(from: coord),
            numberOfCourts: numberOfCourts,
            courtType: courtType,
            hasLights: hasLights,
            isPublic: isPublic,
            notes: notes,
            addedByUserId: appState.currentUser?.id
        )
        
        appState.addCourt(court)
    }
}

// MARK: - Court Detail Sheet

struct CourtDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let court: TennisCourt
    
    @State private var showingReportBusyness = false
    @State private var showingCheckIn = false
    @State private var selectedBusyness: BusynessLevel = .moderate
    
    var isFavorite: Bool {
        guard let userId = appState.currentUser?.id else { return false }
        return court.isFavorite(for: userId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Map preview
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: court.coordinate.clCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Marker(court.name, coordinate: court.coordinate.clCoordinate)
                            .tint(.green)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Info cards
                    VStack(spacing: 12) {
                        // Live Status Card (if check-ins available)
                        if let liveData = court.liveAvailability {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                            Text("LIVE")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.green)
                                        }
                                        Text("\(liveData.inUse) of \(liveData.total) courts in use")
                                            .font(.title3.weight(.semibold))
                                    }
                                    
                                    Spacer()
                                    
                                    // Availability indicator
                                    let available = liveData.total - liveData.inUse
                                    VStack(spacing: 2) {
                                        Text("\(available)")
                                            .font(.title.weight(.bold))
                                            .foregroundColor(available > 0 ? .green : .red)
                                        Text("available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Wait time & departure info
                                HStack(spacing: 20) {
                                    if let wait = court.estimatedWaitMinutes, wait > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .foregroundColor(.orange)
                                            Text("~\(wait) min wait")
                                                .font(.subheadline)
                                        }
                                    }
                                    
                                    if let leaving = court.soonestDeparture {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundColor(.blue)
                                            Text("Court opens in ~\(leaving) min")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                
                                // Last update time
                                if let lastCheckIn = court.recentCheckIns.first {
                                    Text("Updated \(lastCheckIn.timestamp, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            // Current busyness (estimated)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Estimated Busyness")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    let busyness = court.currentBusyness()
                                    HStack(spacing: 8) {
                                        Image(systemName: busyness.icon)
                                            .foregroundColor(busyness.color)
                                        Text(busyness.label)
                                            .font(.title3.weight(.semibold))
                                            .foregroundColor(busyness.color)
                                    }
                                }
                                
                                Spacer()
                                
                                Button("Report") {
                                    showingReportBusyness = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        // Check-In Button
                        Button(action: { showingCheckIn = true }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Check In at This Court")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        // Details grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            DetailCard(icon: "sportscourt.fill", title: "Courts", value: "\(court.numberOfCourts)")
                            DetailCard(icon: court.courtType.icon, title: "Type", value: court.courtType.rawValue)
                            DetailCard(icon: "lightbulb.fill", title: "Lights", value: court.hasLights ? "Yes" : "No")
                            DetailCard(icon: "person.fill", title: "Access", value: court.isPublic ? "Public" : "Private")
                        }
                        
                        // Busyness pattern hint
                        if !court.busynessPatterns.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Typical Busyness")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Show busiest times
                                let busiestPatterns = court.busynessPatterns
                                    .filter { $0.averageBusyness >= 0.7 }
                                    .sorted { $0.averageBusyness > $1.averageBusyness }
                                    .prefix(3)
                                
                                if !busiestPatterns.isEmpty {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Usually busy: ")
                                            .font(.caption)
                                        Text(busiestPatterns.map { formatPatternTime($0) }.joined(separator: ", "))
                                            .font(.caption.weight(.medium))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        // Verified badge
                        if court.isVerifiedPublic {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                                Text("Verified Public Court")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Address
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(court.address)
                                .font(.subheadline)
                            Spacer()
                            
                            Button(action: openInMaps) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Notes
                        if !court.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(court.notes)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        // Recent check-ins
                        if !court.recentCheckIns.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Check-ins")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(court.recentCheckIns.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5)) { checkIn in
                                    if let user = appState.getUser(by: checkIn.userId) {
                                        HStack {
                                            Text(user.name)
                                                .font(.caption.weight(.medium))
                                            Text("• \(checkIn.courtsInUse)/\(checkIn.totalCourts) in use")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(checkIn.timestamp, style: .relative)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if !checkIn.note.isEmpty {
                                            Text(checkIn.note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.leading)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        // Recent reports
                        if !court.busynessReports.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Reports")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(court.busynessReports.suffix(5).reversed()) { report in
                                    HStack {
                                        Circle()
                                            .fill(report.level.color)
                                            .frame(width: 8, height: 8)
                                        Text(report.level.label)
                                            .font(.caption)
                                        Spacer()
                                        Text(report.date, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(court.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .gray)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CourtCheckInSheet(appState: appState, court: court)
            }
            .alert("Report Busyness", isPresented: $showingReportBusyness) {
                Button("Low - Courts Available", action: { reportBusyness(.low) })
                Button("Moderate - Some Wait", action: { reportBusyness(.moderate) })
                Button("Busy - Long Wait", action: { reportBusyness(.high) })
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("How busy is \(court.name) right now?")
            }
        }
    }
    
    func toggleFavorite() {
        appState.toggleFavorite(court: court)
    }
    
    func reportBusyness(_ level: BusynessLevel) {
        appState.reportBusyness(courtId: court.id, level: level)
    }
    
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: court.coordinate.clCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = court.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func formatPatternTime(_ pattern: CourtBusynessPattern) -> String {
        let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = days[pattern.dayOfWeek]
        let hour = pattern.hourOfDay
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(day) \(displayHour)\(period)"
    }
}

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - My Matches View

struct MyMatchesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedMatch: Match?
    @State private var matchToRate: Match?
    
    var myAvailabilities: [Availability] {
        appState.myActiveAvailabilities()
            .sorted { $0.startTime < $1.startTime }
    }
    
    var myMatches: [Match] {
        guard let userId = appState.currentUser?.id else { return [] }
        return appState.matchesForUser(userId)
            .filter { $0.status != .cancelled }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    var matchesNeedingRating: [Match] {
        appState.getMatchesNeedingRating()
    }
    
    var upcomingMatches: [Match] {
        myMatches.filter { $0.scheduledTime > Date() && ($0.status == .pending || $0.status == .confirmed) }
    }
    
    var pastMatches: [Match] {
        myMatches.filter { ($0.scheduledTime <= Date() || $0.status == .completed) && !matchesNeedingRating.contains(where: { $0.id == $0.id }) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Matches needing rating (top priority)
                if !matchesNeedingRating.isEmpty {
                    Section {
                        ForEach(matchesNeedingRating) { match in
                            RatingNeededRow(match: match, appState: appState, onRate: {
                                matchToRate = match
                            })
                        }
                    } header: {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.orange)
                            Text("Rate Your Matches")
                            Spacer()
                            Text("\(matchesNeedingRating.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(10)
                        }
                    } footer: {
                        Text("Help build trust in the community by rating your matches")
                    }
                }
                
                // My posted availabilities
                if !myAvailabilities.isEmpty {
                    Section {
                        ForEach(myAvailabilities) { availability in
                            MyAvailabilityRow(availability: availability)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        appState.cancelAvailability(availability)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("My Available Times")
                            Spacer()
                            Text("\(myAvailabilities.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                        }
                    }
                }
                
                // Upcoming matches
                if !upcomingMatches.isEmpty {
                    Section("Upcoming Matches") {
                        ForEach(upcomingMatches) { match in
                            MatchRow(match: match, appState: appState)
                                .onTapGesture {
                                    selectedMatch = match
                                }
                        }
                    }
                }
                
                // Past matches
                if !pastMatches.isEmpty {
                    Section("Past Matches") {
                        ForEach(pastMatches.prefix(10)) { match in
                            MatchRow(match: match, appState: appState)
                                .onTapGesture {
                                    selectedMatch = match
                                }
                        }
                    }
                }
                
                if myAvailabilities.isEmpty && myMatches.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No matches yet")
                                .font(.headline)
                            
                            Text("Post your availability or browse available players to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("My Matches")
            .sheet(item: $selectedMatch) { match in
                MatchDetailSheet(appState: appState, match: match)
            }
            .sheet(item: $matchToRate) { match in
                let partnerId = match.requesterId == appState.currentUser?.id ? match.accepterId : match.requesterId
                if let partner = appState.getUser(by: partnerId) {
                    RateMatchSheet(appState: appState, match: match, partnerToRate: partner)
                }
            }
        }
    }
}

struct RatingNeededRow: View {
    let match: Match
    @ObservedObject var appState: AppState
    var onRate: () -> Void
    
    var partner: User? {
        let partnerId = match.requesterId == appState.currentUser?.id ? match.accepterId : match.requesterId
        return appState.getUser(by: partnerId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let partner = partner {
                ZStack {
                    Circle()
                        .fill(partner.skillLevel.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(partner.initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(partner.skillLevel.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Match with \(partner.name)")
                        .font(.subheadline.weight(.medium))
                    Text(match.scheduledTime, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onRate) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("Rate")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(16)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MyAvailabilityRow: View {
    let availability: Availability
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(availability.startTime, style: .date)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(availability.matchType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            
            HStack {
                Text("\(availability.startTime, style: .time) - \(availability.endTime, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Waiting for match...")
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MatchRow: View {
    let match: Match
    @ObservedObject var appState: AppState
    
    var otherUser: User? {
        guard let currentUserId = appState.currentUser?.id else { return nil }
        let otherId = match.requesterId == currentUserId ? match.accepterId : match.requesterId
        return appState.getUser(by: otherId)
    }
    
    var court: TennisCourt? {
        guard let courtId = match.courtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let user = otherUser {
                    ZStack {
                        Circle()
                            .fill(user.skillLevel.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text(user.initials)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(user.skillLevel.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.subheadline.weight(.medium))
                        Text(user.skillLevel.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(match.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(match.status.color.opacity(0.15))
                    .foregroundColor(match.status.color)
                    .cornerRadius(6)
            }
            
            Divider()
            
            HStack {
                Image(systemName: "calendar")
                Text(match.scheduledTime, style: .date)
                    .font(.caption)
                Text("•")
                    .foregroundColor(.secondary)
                Image(systemName: "clock")
                Text(match.scheduledTime, style: .time)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            if let court = court {
                Label(court.name, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show message count
            if !match.messages.isEmpty {
                HStack {
                    Image(systemName: "bubble.left.fill")
                    Text("\(match.messages.count) messages")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Match Detail Sheet

struct MatchDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let match: Match
    
    @State private var messageText = ""
    
    var otherUser: User? {
        guard let currentUserId = appState.currentUser?.id else { return nil }
        let otherId = match.requesterId == currentUserId ? match.accepterId : match.requesterId
        return appState.getUser(by: otherId)
    }
    
    var court: TennisCourt? {
        guard let courtId = match.courtId else { return nil }
        return appState.courts.first { $0.id == courtId }
    }
    
    var isUpcoming: Bool {
        match.scheduledTime > Date() && (match.status == .pending || match.status == .confirmed)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Match info header
                VStack(spacing: 16) {
                    if let user = otherUser {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.skillLevel.color.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                Text(user.initials)
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(user.skillLevel.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.skillLevel.rawValue)
                                    .font(.caption)
                                    .foregroundColor(user.skillLevel.color)
                                Text(user.phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(match.status.rawValue)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(match.status.color.opacity(0.15))
                                .foregroundColor(match.status.color)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Date/time/location
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                            Text(match.scheduledTime, format: .dateTime.weekday(.wide).month().day())
                            Spacer()
                            Text(match.scheduledTime, style: .time)
                        }
                        .font(.subheadline)
                        
                        if let court = court {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(court.name)
                                Spacer()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Quick alerts (only for upcoming matches)
                if isUpcoming {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(QuickAlertType.allCases, id: \.self) { alertType in
                                Button(action: { sendQuickAlert(alertType) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: alertType.icon)
                                        Text(alertType.rawValue)
                                    }
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(alertType.color.opacity(0.15))
                                    .foregroundColor(alertType.color)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemBackground))
                }
                
                Divider()
                
                // Messages
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(match.messages) { message in
                            let isFromMe = message.senderId == appState.currentUser?.id
                            
                            if message.isQuickAlert, let alertType = message.alertType {
                                // Quick alert bubble
                                HStack {
                                    if isFromMe { Spacer() }
                                    HStack(spacing: 8) {
                                        Image(systemName: alertType.icon)
                                        Text(alertType.rawValue)
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(alertType.color.opacity(0.2))
                                    .foregroundColor(alertType.color)
                                    .cornerRadius(18)
                                    if !isFromMe { Spacer() }
                                }
                            } else {
                                // Regular message
                                HStack {
                                    if isFromMe { Spacer() }
                                    VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                                        Text(message.text)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(isFromMe ? Color.green : Color(.secondarySystemBackground))
                                            .foregroundColor(isFromMe ? .white : .primary)
                                            .cornerRadius(18)
                                        
                                        Text(message.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !isFromMe { Spacer() }
                                }
                            }
                        }
                        
                        if match.messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("No messages yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(messageText.isEmpty ? .gray : .green)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Match Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        appState.addMessageToMatch(matchId: match.id, text: messageText)
        messageText = ""
    }
    
    func sendQuickAlert(_ alertType: QuickAlertType) {
        appState.sendQuickAlert(matchId: match.id, alertType: alertType)
    }
}

// MARK: - Friends & Groups View

struct FriendsGroupsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0
    @State private var showingCreateGroup = false
    @State private var showingAddFriend = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    Text("Groups").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    FriendsListView(appState: appState, showingAddFriend: $showingAddFriend)
                } else {
                    GroupsListView(appState: appState, showingCreateGroup: $showingCreateGroup)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Friends & Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if selectedTab == 0 {
                            showingAddFriend = true
                        } else {
                            showingCreateGroup = true
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendSheet(appState: appState)
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupSheet(appState: appState)
            }
        }
    }
}

struct FriendsListView: View {
    @ObservedObject var appState: AppState
    @Binding var showingAddFriend: Bool
    
    var friends: [User] {
        appState.getFriends()
    }
    
    var friendsAvailabilities: [Availability] {
        appState.getFriendsAvailabilities()
    }
    
    var body: some View {
        List {
            if !friendsAvailabilities.isEmpty {
                Section("Friends Available Now") {
                    ForEach(friendsAvailabilities) { availability in
                        if let user = appState.getUser(by: availability.userId) {
                            FriendAvailabilityRow(user: user, availability: availability)
                        }
                    }
                }
            }
            
            Section("My Friends (\(friends.count))") {
                if friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No friends yet")
                            .font(.headline)
                        Text("Add players you've played with to see their availability")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Add Friend") {
                            showingAddFriend = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(friends) { friend in
                        FriendRow(user: friend, appState: appState)
                    }
                }
            }
        }
    }
}

struct FriendRow: View {
    let user: User
    @ObservedObject var appState: AppState
    @State private var showingProfile = false
    
    var body: some View {
        Button(action: { showingProfile = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(user.skillLevel.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(user.initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(user.skillLevel.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 4) {
                        Image(systemName: user.trustLevel.icon)
                            .font(.caption2)
                        Text(user.trustLevel.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(user.trustLevel.color)
                }
                
                Spacer()
                
                // Trust score
                if user.trustScore > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text(String(format: "%.1f", user.trustScore))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProfile) {
            FriendProfileSheet(user: user, appState: appState)
        }
    }
}

struct FriendAvailabilityRow: View {
    let user: User
    let availability: Availability
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(user.initials)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline.weight(.medium))
                Text("\(availability.startTime, style: .time) • \(availability.matchType.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}

struct AddFriendSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var searchResults: [User] {
        guard let currentUserId = appState.currentUser?.id else { return [] }
        let friendIds = appState.currentUser?.friendIds ?? []
        
        return appState.users.filter { user in
            user.id != currentUserId &&
            !friendIds.contains(user.id) &&
            (searchText.isEmpty || user.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search by name", text: $searchText)
                }
                
                Section("Players") {
                    ForEach(searchResults) { user in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.skillLevel.color.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Text(user.initials)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(user.skillLevel.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.subheadline.weight(.medium))
                                Text(formatSkillLevels(user.skillLevels))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                appState.addFriend(user.id)
                            }) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FriendProfileSheet: View {
    let user: User
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(user.skillLevel.color.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Text(user.initials)
                                .font(.title)
                                .foregroundColor(user.skillLevel.color)
                        }
                        
                        Text(user.name)
                            .font(.title2.weight(.bold))
                        
                        // Trust badge
                        HStack(spacing: 6) {
                            Image(systemName: user.trustLevel.icon)
                            Text(user.trustLevel.rawValue)
                            if user.trustScore > 0 {
                                Text("•")
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                Text(String(format: "%.1f", user.trustScore))
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(user.trustLevel.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(user.trustLevel.color.opacity(0.15))
                        .cornerRadius(20)
                    }
                    .padding()
                    
                    // Stats
                    HStack(spacing: 30) {
                        StatBox(value: "\(user.matchesPlayed)", label: "Matches")
                        StatBox(value: formatSkillLevels(user.skillLevels), label: "Level")
                        StatBox(value: "\(user.currentStreak)", label: "Streak")
                    }
                    .padding(.horizontal)
                    
                    // Recent ratings
                    if !user.ratingsReceived.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Reviews")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(user.ratingsReceived.suffix(3).reversed()) { rating in
                                if let reviewer = appState.getUser(by: rating.fromUserId) {
                                    RatingCard(rating: rating, reviewer: reviewer)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            // TODO: Send invite
                        }) {
                            Label("Invite to Play", systemImage: "paperplane.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        
                        if appState.isFriend(user.id) {
                            Button(action: {
                                appState.removeFriend(user.id)
                                dismiss()
                            }) {
                                Label("Remove Friend", systemImage: "person.badge.minus")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Player Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RatingCard: View {
    let rating: PlayerRating
    let reviewer: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reviewer.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < Int(rating.overallScore.rounded()) ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !rating.comment.isEmpty {
                Text(rating.comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label("On time", systemImage: rating.punctuality >= 4 ? "checkmark.circle.fill" : "clock")
                    .font(.caption2)
                    .foregroundColor(rating.punctuality >= 4 ? .green : .secondary)
                
                if rating.wouldPlayAgain {
                    Label("Would play again", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Groups Views

struct GroupsListView: View {
    @ObservedObject var appState: AppState
    @Binding var showingCreateGroup: Bool
    
    var myGroups: [TennisGroup] {
        appState.getMyGroups()
    }
    
    var body: some View {
        List {
            if myGroups.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No groups yet")
                            .font(.headline)
                        Text("Create a group to organize matches with friends")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Create Group") {
                            showingCreateGroup = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                }
            } else {
                Section("My Groups") {
                    ForEach(myGroups) { group in
                        NavigationLink(destination: GroupDetailView(group: group, appState: appState)) {
                            GroupRow(group: group, appState: appState)
                        }
                    }
                }
            }
        }
    }
}

struct GroupRow: View {
    let group: TennisGroup
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline.weight(.medium))
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !group.messages.isEmpty {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct CreateGroupSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = true
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Toggle("Private Group", isOn: $isPrivate)
                } footer: {
                    Text("Private groups are invite-only. Public groups can be found by anyone.")
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        _ = appState.createGroup(name: name, description: description, isPrivate: isPrivate)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

struct GroupDetailView: View {
    let group: TennisGroup
    @ObservedObject var appState: AppState
    @State private var messageText = ""
    
    var members: [User] {
        appState.getGroupMembers(group.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Members strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(members) { member in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(member.skillLevel.color.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Text(member.initials)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(member.skillLevel.color)
                            }
                            Text(member.name.split(separator: " ").first.map(String.init) ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            
            // Messages
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(group.messages) { message in
                        GroupMessageBubble(message: message, appState: appState)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Input
            HStack(spacing: 12) {
                TextField("Message", text: $messageText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .green)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        appState.sendGroupMessage(groupId: group.id, text: messageText)
        messageText = ""
    }
}

struct GroupMessageBubble: View {
    let message: GroupMessage
    @ObservedObject var appState: AppState
    
    var sender: User? {
        appState.getUser(by: message.senderId)
    }
    
    var isCurrentUser: Bool {
        message.senderId == appState.currentUser?.id
    }
    
    var body: some View {
        if message.isSystemMessage {
            Text(message.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if isCurrentUser { Spacer() }
                
                if !isCurrentUser {
                    ZStack {
                        Circle()
                            .fill(sender?.skillLevel.color.opacity(0.2) ?? Color.gray.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Text(sender?.initials ?? "?")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(sender?.skillLevel.color ?? .gray)
                    }
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                    if !isCurrentUser {
                        Text(sender?.name ?? "Unknown")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.text)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.green : Color(.secondarySystemBackground))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                if !isCurrentUser { Spacer() }
            }
        }
    }
}

// MARK: - Rating Sheet

struct RateMatchSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let match: Match
    let partnerToRate: User
    
    @State private var punctuality = 4
    @State private var skillAccuracy = 4
    @State private var sportsmanship = 4
    @State private var wouldPlayAgain = true
    @State private var comment = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(partnerToRate.skillLevel.color.opacity(0.2))
                                .frame(width: 60, height: 60)
                            Text(partnerToRate.initials)
                                .font(.title2)
                                .foregroundColor(partnerToRate.skillLevel.color)
                        }
                        Text("How was your match with \(partnerToRate.name)?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Punctuality") {
                    StarRating(rating: $punctuality)
                    Text("Did they show up on time?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Skill Accuracy") {
                    StarRating(rating: $skillAccuracy)
                    Text("Was their skill level as expected?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Sportsmanship") {
                    StarRating(rating: $sportsmanship)
                    Text("Were they friendly and respectful?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Toggle("Would play again", isOn: $wouldPlayAgain)
                }
                
                Section("Comment (optional)") {
                    TextField("Share your experience...", text: $comment, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Rate Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submitRating()
                        dismiss()
                    }
                }
            }
        }
    }
    
    func submitRating() {
        appState.submitRating(
            matchId: match.id,
            toUserId: partnerToRate.id,
            punctuality: punctuality,
            skillAccuracy: skillAccuracy,
            sportsmanship: sportsmanship,
            wouldPlayAgain: wouldPlayAgain,
            comment: comment
        )
    }
}

struct StarRating: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundColor(star <= rating ? .orange : .gray.opacity(0.3))
                    .onTapGesture {
                        rating = star
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weather View Component

struct WeatherBadge: View {
    let weather: WeatherInfo
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: weather.condition.icon)
                .foregroundColor(weather.condition.color)
            
            Text("\(weather.temperature)°")
                .font(.subheadline.weight(.semibold))
            
            if weather.rainChance >= 30 {
                Text("\(weather.rainChance)%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(weather.isGoodForTennis ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
        .cornerRadius(12)
    }
}

struct WeatherDetailView: View {
    let weather: WeatherInfo
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weather.condition.icon)
                    .font(.largeTitle)
                    .foregroundColor(weather.condition.color)
                
                VStack(alignment: .leading) {
                    Text("\(weather.temperature)°F")
                        .font(.title.weight(.bold))
                    Text(weather.condition.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Label("\(weather.rainChance)%", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Label("\(weather.windSpeed) mph", systemImage: "wind")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recommendation
            HStack {
                Image(systemName: weather.isGoodForTennis ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(weather.isGoodForTennis ? .green : .orange)
                Text(weather.recommendation)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(weather.isGoodForTennis ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Court Check-In Sheet

struct CourtCheckInSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let court: TennisCourt
    
    @State private var courtsInUse = 0
    @State private var estimatedWait: Int?
    @State private var leavingIn: Int?
    @State private var note = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Text(court.name)
                            .font(.headline)
                        Text("Total courts: \(court.numberOfCourts)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Courts Currently In Use") {
                    Stepper("\(courtsInUse) of \(court.numberOfCourts)", value: $courtsInUse, in: 0...court.numberOfCourts)
                }
                
                Section("Estimated Wait Time") {
                    Picker("Wait time", selection: Binding(
                        get: { estimatedWait ?? -1 },
                        set: { estimatedWait = $0 == -1 ? nil : $0 }
                    )) {
                        Text("No wait").tag(-1)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                        Text("30+ min").tag(30)
                    }
                }
                
                Section("When are you leaving?") {
                    Picker("Leaving in", selection: Binding(
                        get: { leavingIn ?? -1 },
                        set: { leavingIn = $0 == -1 ? nil : $0 }
                    )) {
                        Text("Not sure").tag(-1)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                        Text("1.5 hours").tag(90)
                    }
                }
                
                Section("Note (optional)") {
                    TextField("e.g., Court 3 has net issues", text: $note)
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check In") {
                        checkIn()
                        dismiss()
                    }
                }
            }
        }
    }
    
    func checkIn() {
        appState.checkInAtCourt(
            courtId: court.id,
            courtsInUse: courtsInUse,
            totalCourts: court.numberOfCourts,
            waitMinutes: estimatedWait,
            leavingIn: leavingIn,
            note: note
        )
    }
}

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var appState: AppState
    
    var stats: MatchStats {
        appState.getMatchStats()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Trust score card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: stats.trustLevel.icon)
                            .font(.title)
                            .foregroundColor(stats.trustLevel.color)
                        
                        VStack(alignment: .leading) {
                            Text(stats.trustLevel.rawValue)
                                .font(.headline)
                            if stats.trustScore > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < Int(stats.trustScore.rounded()) ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    Text(String(format: "%.1f", stats.trustScore))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Total Matches", value: "\(stats.totalMatches)", icon: "sportscourt.fill", color: .green)
                    StatCard(title: "Current Streak", value: "\(stats.currentStreak) days", icon: "flame.fill", color: .orange)
                    StatCard(title: "Longest Streak", value: "\(stats.longestStreak) days", icon: "trophy.fill", color: .yellow)
                    StatCard(title: "Trust Score", value: String(format: "%.1f", stats.trustScore), icon: "star.fill", color: .purple)
                }
                .padding(.horizontal)
                
                // Top partners
                if !stats.topPartners.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequent Partners")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(stats.topPartners) { partner in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(partner.skillLevel.color.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Text(partner.initials)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(partner.skillLevel.color)
                                }
                                
                                Text(partner.name)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Favorite courts
                if !stats.favoriteCourts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Courts")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(stats.favoriteCourts) { court in
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text(court.name)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Favorite times
                if !stats.favoriteTimeSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Times")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(stats.favoriteTimeSlots, id: \.self) { time in
                                Text(time)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Stats")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct QuickStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var appState: AppState
    @State private var showingEditProfile = false
    @State private var showingResetConfirm = false
    @State private var showingAddTestUsers = false
    @State private var isSearchingCourts = false
    @State private var searchResultMessage = ""
    @State private var showSearchResult = false
    @State private var showingStats = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile header with trust badge
                if let user = appState.currentUser {
                    Section {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(user.skillLevel.color.opacity(0.2))
                                        .frame(width: 72, height: 72)
                                    Text(user.initials)
                                        .font(.title)
                                        .foregroundColor(user.skillLevel.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.title2.weight(.bold))
                                    
                                    Text(formatSkillLevels(user.skillLevels))
                                        .font(.subheadline)
                                        .foregroundColor(user.skillLevel.color)
                                    
                                    Text("\(user.matchesPlayed) matches played")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            // Trust badge
                            HStack(spacing: 8) {
                                Image(systemName: user.trustLevel.icon)
                                    .foregroundColor(user.trustLevel.color)
                                Text(user.trustLevel.rawValue)
                                    .font(.subheadline.weight(.medium))
                                
                                if user.trustScore > 0 {
                                    Spacer()
                                    HStack(spacing: 2) {
                                        ForEach(0..<5) { i in
                                            Image(systemName: i < Int(user.trustScore.rounded()) ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Text(String(format: "%.1f", user.trustScore))
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(user.trustLevel.color.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Quick Stats
                if let user = appState.currentUser {
                    Section("Quick Stats") {
                        HStack {
                            QuickStatItem(value: "\(user.matchesPlayed)", label: "Matches", icon: "sportscourt.fill", color: .green)
                            QuickStatItem(value: "\(user.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                            QuickStatItem(value: "\(user.friendIds.count)", label: "Friends", icon: "person.2.fill", color: .blue)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        
                        NavigationLink(destination: StatsView(appState: appState)) {
                            Label("View All Stats", systemImage: "chart.bar.fill")
                        }
                    }
                }
                
                // Contact Info
                if let user = appState.currentUser {
                    Section("Contact Info") {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            Text(user.phone)
                        }
                    }
                }
                
                // Actions
                Section {
                    Button(action: { showingEditProfile = true }) {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                }
                
                // Courts section
                Section("Courts") {
                    HStack {
                        Text("Total Courts")
                        Spacer()
                        Text("\(appState.courts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: searchForCourts) {
                        HStack {
                            if isSearchingCourts {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text("Search Courts in Local Area")
                        }
                    }
                    .disabled(isSearchingCourts)
                    
                    Text("Searches: Ashland, Hopkinton, Framingham, Southborough, Brighton")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Data management
                Section("Data") {
                    HStack {
                        Text("Players")
                        Spacer()
                        Text("\(appState.users.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Add Test Users") {
                        appState.addSampleUsers()
                    }
                    
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                if let user = appState.currentUser {
                    EditProfileSheet(appState: appState, user: user)
                }
            }
            .alert("Reset All Data?", isPresented: $showingResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    appState.resetAllData()
                }
            } message: {
                Text("This will delete all users, courts, matches, and reset the app. You'll need to set up your profile again.")
            }
            .alert("Court Search Complete", isPresented: $showSearchResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(searchResultMessage)
            }
        }
    }
    
    func searchForCourts() {
        isSearchingCourts = true
        appState.searchTennisCourtsInArea { count in
            isSearchingCourts = false
            searchResultMessage = "Found \(count) new tennis court\(count == 1 ? "" : "s") in the local area. Total courts: \(appState.courts.count)"
            showSearchResult = true
        }
    }
}

struct EditProfileSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let user: User
    
    @State private var name: String
    @State private var phone: String
    @State private var selectedSkillLevels: Set<SkillLevel>
    
    init(appState: AppState, user: User) {
        self.appState = appState
        self.user = user
        _name = State(initialValue: user.name)
        _phone = State(initialValue: user.phone)
        _selectedSkillLevels = State(initialValue: Set(user.skillLevels))
    }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedSkillLevels.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Name", text: $name)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                    }
                }
                
                Section {
                    ForEach(SkillLevel.allCases) { level in
                        Button(action: { toggleSkillLevel(level) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(level.rawValue)
                                        .font(.subheadline)
                                    Text("NTRP \(level.ntrpRange)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedSkillLevels.contains(level) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Skill Level (select 1 or 2)")
                } footer: {
                    if selectedSkillLevels.count == 2 {
                        Text("Two skill levels selected")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    func toggleSkillLevel(_ level: SkillLevel) {
        if selectedSkillLevels.contains(level) {
            if selectedSkillLevels.count > 1 {
                selectedSkillLevels.remove(level)
            }
        } else {
            if selectedSkillLevels.count < 2 {
                selectedSkillLevels.insert(level)
            } else {
                if let first = selectedSkillLevels.first {
                    selectedSkillLevels.remove(first)
                }
                selectedSkillLevels.insert(level)
            }
        }
    }
    
    func saveProfile() {
        var updatedUser = user
        updatedUser.name = name
        updatedUser.phone = phone
        updatedUser.skillLevels = Array(selectedSkillLevels).sorted { $0.sortOrder < $1.sortOrder }
        appState.updateUser(updatedUser)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
