//
//  AddTaskView.swift
//  VisualMemory - FULL SCREEN, 2-Month Calendar
//  No scrolling, everything visible
//

import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var taskTitle = ""
    @State private var selectedPriority: PriorityLevel = .medium
    
    // Date & Time
    @State private var selectedDate = Date()
    @State private var selectedHour = Calendar.current.component(.hour, from: Date()) % 12
    @State private var selectedMinute = Calendar.current.component(.minute, from: Date())
    @State private var selectedAMPM = Calendar.current.component(.hour, from: Date()) >= 12 ? 1 : 0
    
    // Recurring
    @State private var isRecurring = false
    @State private var recurringDays: Set<Weekday> = []
    
    // Voice Alerts
    @State private var voiceAlertsEnabled = false
    
    // Reminder
    @State private var reminderEnabled = false
    @State private var reminderMinutes = 5
    @State private var reminderType: ReminderType = .notification
    @State private var selectedAlarmSound: AlarmSound = .radar
    
    // Calendar
    @State private var baseMonth = Date()
    
    enum ReminderType: String, CaseIterable {
        case siri = "Siri"
        case sound = "Sound"
        case notification = "Alert"
        
        var icon: String {
            switch self {
            case .siri: return "mic.fill"
            case .sound: return "speaker.wave.3.fill"
            case .notification: return "bell.fill"
            }
        }
    }
    
    enum AlarmSound: String, CaseIterable {
        case radar = "Radar"
        case beacon = "Beacon"
        case chimes = "Chimes"
        case circuit = "Circuit"
        case cosmic = "Cosmic"
        case illuminate = "Illuminate"
        case presto = "Presto"
        case ripples = "Ripples"
        case signal = "Signal"
        case summit = "Summit"
        case twinkle = "Twinkle"
        case uplift = "Uplift"
    }
    
    var calculatedDeadline: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        var hour = selectedHour == 0 ? 12 : selectedHour
        if selectedAMPM == 1 && hour != 12 {
            hour += 12
        } else if selectedAMPM == 0 && hour == 12 {
            hour = 0
        }
        
        components.hour = hour
        components.minute = selectedMinute
        
        return calendar.date(from: components) ?? Date()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen dark background
                Color(red: 0.06, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("New Task")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Invisible button for balance
                        Text("Cancel")
                            .font(.system(size: 17))
                            .foregroundColor(.clear)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // MARK: - Task Name (Large & Prominent)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHAT NEEDS TO BE DONE?")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                            .tracking(1)
                        
                        TextField("Enter your task...", text: $taskTitle)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(taskTitle.isEmpty ? Color.white.opacity(0.15) : Color.cyan, lineWidth: 2)
                                    )
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - 2-Month Calendar (Large)
                    TwoMonthCalendarView(
                        selectedDate: $selectedDate,
                        baseMonth: $baseMonth,
                        tasks: dataManager.tasks
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // MARK: - Time Picker (Large)
                    HStack(spacing: 0) {
                        Spacer()
                        
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(1...12, id: \.self) { hour in
                                Text("\(hour)")
                                    .font(.system(size: 24))
                                    .tag(hour % 12)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 120)
                        .clipped()
                        
                        Text(":")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(0...59, id: \.self) { minute in
                                Text(String(format: "%02d", minute))
                                    .font(.system(size: 24))
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 120)
                        .clipped()
                        
                        Picker("AM/PM", selection: $selectedAMPM) {
                            Text("AM").font(.system(size: 20, weight: .semibold)).tag(0)
                            Text("PM").font(.system(size: 20, weight: .semibold)).tag(1)
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 120)
                        .clipped()
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Priority (Large Buttons)
                    HStack(spacing: 12) {
                        ForEach(PriorityLevel.allCases, id: \.self) { priority in
                            Button(action: { selectedPriority = priority }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(priority.color)
                                        .frame(width: 14, height: 14)
                                    Text(priority.name)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(selectedPriority == priority ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedPriority == priority ? priority.color.opacity(0.35) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedPriority == priority ? priority.color : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Options Row (Repeat, Siri, Reminder)
                    HStack(spacing: 12) {
                        LargeToggleButton(isOn: $isRecurring, icon: "repeat", title: "Repeat", color: .cyan)
                        LargeToggleButton(isOn: $voiceAlertsEnabled, icon: "mic.fill", title: "Siri", color: .purple)
                        LargeToggleButton(isOn: $reminderEnabled, icon: "bell.fill", title: "Remind", color: .orange)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Reminder Options (if enabled)
                    if reminderEnabled {
                        HStack(spacing: 10) {
                            // Minutes picker
                            HStack(spacing: 4) {
                                Picker("Minutes", selection: $reminderMinutes) {
                                    ForEach([1, 2, 3, 5, 10, 15, 20, 30], id: \.self) { mins in
                                        Text("\(mins)").font(.system(size: 18)).tag(mins)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 50, height: 80)
                                .clipped()
                                
                                Text("min")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.05))
                            )
                            
                            // Type buttons
                            ForEach(ReminderType.allCases, id: \.self) { type in
                                Button(action: { reminderType = type }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 16))
                                        Text(type.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(reminderType == type ? .white : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(reminderType == type ? Color.orange.opacity(0.4) : Color.white.opacity(0.05))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // MARK: - Add Button (Large)
                    Button(action: addTask) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            Text("Add Task")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(taskTitle.isEmpty ? Color.gray.opacity(0.4) : Color.cyan)
                                .shadow(color: taskTitle.isEmpty ? .clear : .cyan.opacity(0.5), radius: 12, y: 6)
                        )
                    }
                    .disabled(taskTitle.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func addTask() {
        guard !taskTitle.isEmpty else { return }
        guard let currentUser = userManager.currentUser else { return }
        
        let task = VisualTask(
            title: taskTitle,
            deadlineTime: calculatedDeadline,
            isRecurring: isRecurring,
            recurringDays: recurringDays,
            userId: currentUser.id,
            userName: currentUser.name,
            userAvatar: currentUser.avatarEmoji,
            userColor: currentUser.color,
            basePriority: selectedPriority,
            voiceAlertsEnabled: voiceAlertsEnabled,
            voiceAlertMinutesBefore: reminderEnabled ? reminderMinutes : 2,
            reminderEnabled: reminderEnabled,
            reminderMinutesBefore: reminderMinutes,
            reminderType: reminderType.rawValue,
            reminderSound: selectedAlarmSound.rawValue
        )
        
        dataManager.addTask(task)
        dismiss()
    }
}

// MARK: - Large Toggle Button
struct LargeToggleButton: View {
    @Binding var isOn: Bool
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isOn ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? color.opacity(0.3) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isOn ? color : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Two Month Calendar View
struct TwoMonthCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var baseMonth: Date
    let tasks: [VisualTask]
    
    private let calendar = Calendar.current
    
    var twoMonths: [Date] {
        let month1 = baseMonth
        let month2 = calendar.date(byAdding: .month, value: 1, to: baseMonth) ?? baseMonth
        return [month1, month2]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Navigation
            HStack {
                Button(action: previousMonths) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                
                Spacer()
                
                Text("\(monthYearShort(twoMonths[0])) - \(monthYearShort(twoMonths[1]))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: nextMonths) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
            }
            
            // Two month grids side by side
            HStack(spacing: 16) {
                ForEach(twoMonths, id: \.self) { month in
                    MonthGridView(
                        month: month,
                        selectedDate: $selectedDate,
                        tasks: tasks
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    func previousMonths() {
        if let newDate = calendar.date(byAdding: .month, value: -2, to: baseMonth) {
            baseMonth = newDate
        }
    }
    
    func nextMonths() {
        if let newDate = calendar.date(byAdding: .month, value: 2, to: baseMonth) {
            baseMonth = newDate
        }
    }
    
    func monthYearShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Month Grid View
struct MonthGridView: View {
    let month: Date
    @Binding var selectedDate: Date
    let tasks: [VisualTask]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: month)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Month name
            Text(monthName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            // Day headers
            HStack(spacing: 2) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            tasks: tasksForDate(date)
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Text("").frame(height: 28)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func daysInMonth() -> [Date?] {
        var days: [Date?] = []
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        for _ in 1..<firstWeekday { days.append(nil) }
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
    
    func tasksForDate(_ date: Date) -> [VisualTask] {
        tasks.filter {
            calendar.isDate($0.deadlineTime, inSameDayAs: date) && !$0.isCompleted
        }
    }
}

// MARK: - Day Cell View (with dots and X marks)
struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let tasks: [VisualTask]
    
    private let calendar = Calendar.current
    
    var dayNumber: Int { calendar.component(.day, from: date) }
    var isPast: Bool { date < calendar.startOfDay(for: Date()) }
    
    // Get task indicators - X for overdue, dot for normal
    var taskIndicators: [(Color, Bool)] { // (color, isOverdue)
        let sorted = tasks.sorted { $0.effectivePriority > $1.effectivePriority }
        return Array(sorted.prefix(3).map { ($0.effectivePriorityLevel.color, $0.isOverdue) })
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    isToday ? .cyan :
                    isPast ? .white.opacity(0.3) :
                    .white.opacity(0.8)
                )
            
            // Task indicators
            HStack(spacing: 2) {
                ForEach(0..<taskIndicators.count, id: \.self) { index in
                    let (color, isOverdue) = taskIndicators[index]
                    if isOverdue {
                        Text("✕")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(color)
                    } else {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 6)
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.cyan.opacity(0.4) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isToday && !isSelected ? Color.cyan : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    AddTaskView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
