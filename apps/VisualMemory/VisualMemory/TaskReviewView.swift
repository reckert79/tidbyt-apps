//
//  TaskReviewView.swift
//  VisualMemory
//  Editable task review screen after voice input
//

import SwiftUI

// MARK: - Pending Task Model (for review before saving)

struct PendingTask: Identifiable {
    let id = UUID()
    var title: String
    var deadline: Date
    var isRecurring: Bool
    var includeWeekdays: Bool
    var includeWeekends: Bool
    var priority: PriorityLevel
    var isSelected: Bool = true
    
    var recurringDays: Set<Weekday> {
        var days: Set<Weekday> = []
        if includeWeekdays {
            days.formUnion([.monday, .tuesday, .wednesday, .thursday, .friday])
        }
        if includeWeekends {
            days.formUnion([.saturday, .sunday])
        }
        return days
    }
    
    var scheduleDescription: String {
        if !isRecurring {
            return "One-time"
        }
        
        if includeWeekdays && includeWeekends {
            return "Every day"
        } else if includeWeekdays && !includeWeekends {
            return "Weekdays only"
        } else if !includeWeekdays && includeWeekends {
            return "Weekends only"
        } else {
            return "Not scheduled"
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: deadline)
    }
}

// MARK: - Task Review View

struct TaskReviewView: View {
    @Binding var tasks: [PendingTask]
    let onConfirm: () -> Void
    let onAddMore: () -> Void
    let onCancel: () -> Void
    
    @State private var editingTask: PendingTask?
    @State private var showingEditSheet = false
    
    var sortedTasks: [PendingTask] {
        tasks.sorted { $0.deadline < $1.deadline }
    }
    
    var selectedCount: Int {
        tasks.filter { $0.isSelected }.count
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Review Your Tasks")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Tap to edit, toggle to include/exclude")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Task count
                HStack {
                    Text("\(selectedCount) of \(tasks.count) tasks selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Button(action: selectAll) {
                        Text(selectedCount == tasks.count ? "Deselect All" : "Select All")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Task list
                if tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No tasks yet")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                                TaskReviewRow(
                                    task: task,
                                    number: index + 1,
                                    onToggle: { toggleTask(task) },
                                    onEdit: { 
                                        editingTask = task
                                        showingEditSheet = true
                                    },
                                    onDelete: { deleteTask(task) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // Bottom buttons
                VStack(spacing: 12) {
                    // Add more tasks button
                    Button(action: onAddMore) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16))
                            Text("Add More Tasks")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Confirm button
                    Button(action: onConfirm) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Confirm \(selectedCount) Tasks")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: selectedCount > 0 ? [.green, .cyan] : [.gray],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: selectedCount > 0 ? .green.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(selectedCount == 0)
                    
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let task = editingTask {
                TaskEditSheet(
                    task: task,
                    onSave: { updatedTask in
                        updateTask(updatedTask)
                        showingEditSheet = false
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    func toggleTask(_ task: PendingTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isSelected.toggle()
        }
    }
    
    func deleteTask(_ task: PendingTask) {
        tasks.removeAll { $0.id == task.id }
    }
    
    func updateTask(_ task: PendingTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        editingTask = nil
    }
    
    func selectAll() {
        let allSelected = selectedCount == tasks.count
        for index in tasks.indices {
            tasks[index].isSelected = !allSelected
        }
    }
}

// MARK: - Task Review Row

struct TaskReviewRow: View {
    let task: PendingTask
    let number: Int
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(task.isSelected ? task.priority.color : Color.gray)
                )
            
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(task.isSelected ? .white : .white.opacity(0.4))
                    .strikethrough(!task.isSelected)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(task.formattedTime)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    
                    // Schedule
                    if task.isRecurring {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                            Text(task.scheduleDescription)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.cyan.opacity(0.8))
                    }
                    
                    // Priority
                    HStack(spacing: 3) {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 6, height: 6)
                        Text(task.priority.name)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(task.priority.color)
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            
            // Toggle checkbox
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(task.isSelected ? Color.green : Color.white.opacity(0.1))
                        .frame(width: 26, height: 26)
                    
                    if task.isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(task.isSelected ? 0.08 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(task.isSelected ? task.priority.color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    @State var task: PendingTask
    let onSave: (PendingTask) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASK NAME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            TextField("Task name", text: $task.title)
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        
                        // Time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            DatePicker(
                                "Time",
                                selection: $task.deadline,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 120)
                            .clipped()
                            .colorScheme(.dark)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        
                        // Recurring toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SCHEDULE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Toggle(isOn: $task.isRecurring) {
                                HStack(spacing: 10) {
                                    Image(systemName: "repeat")
                                        .foregroundColor(.cyan)
                                    Text("Recurring Task")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(.cyan)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                            
                            if task.isRecurring {
                                // Weekday/Weekend toggles
                                VStack(spacing: 12) {
                                    Toggle(isOn: $task.includeWeekdays) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "briefcase")
                                                .foregroundColor(.blue)
                                            Text("Weekdays (Mon-Fri)")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .tint(.blue)
                                    
                                    Toggle(isOn: $task.includeWeekends) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "sun.max")
                                                .foregroundColor(.orange)
                                            Text("Weekends (Sat-Sun)")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .tint(.orange)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                        }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PRIORITY")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 10) {
                                ForEach([PriorityLevel.low, .medium, .high], id: \.self) { priority in
                                    Button(action: { task.priority = priority }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(priority.color)
                                                .frame(width: 10, height: 10)
                                            Text(priority.name)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(task.priority == priority ? .white : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(task.priority == priority ? priority.color.opacity(0.3) : Color.white.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(task.priority == priority ? priority.color : Color.clear, lineWidth: 2)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(task) }
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    TaskReviewView(
        tasks: .constant([
            PendingTask(title: "Brush teeth", deadline: Date(), isRecurring: true, includeWeekdays: true, includeWeekends: true, priority: .low),
            PendingTask(title: "Take vitamins", deadline: Date().addingTimeInterval(1800), isRecurring: true, includeWeekdays: true, includeWeekends: false, priority: .medium),
            PendingTask(title: "Pay rent", deadline: Date().addingTimeInterval(3600), isRecurring: false, includeWeekdays: false, includeWeekends: false, priority: .high)
        ]),
        onConfirm: {},
        onAddMore: {},
        onCancel: {}
    )
}
