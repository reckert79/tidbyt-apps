//
//  AllTasksView.swift
//  VisualMemory - Phase 1
//  View all tasks organized by time period
//

import SwiftUI

struct AllTasksView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFilter: TimeFilter = .today
    @State private var showCompleted = false
    @State private var searchText = ""
    
    var filteredTasks: [VisualTask] {
        var tasks = dataManager.tasks(for: selectedFilter)
        
        if showCompleted {
            let completedInFilter = dataManager.completedTasks.filter { $0.timeFilter == selectedFilter }
            tasks.append(contentsOf: completedInFilter)
        }
        
        if !searchText.isEmpty {
            tasks = tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return tasks
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Search tasks...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Time Filter Tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                TimeFilterTab(
                                    filter: filter,
                                    isSelected: selectedFilter == filter,
                                    count: dataManager.taskCount(for: filter)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    // Show Completed Toggle
                    HStack {
                        Text("\(filteredTasks.count) tasks")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Toggle("Show Completed", isOn: $showCompleted)
                            .toggleStyle(SwitchToggleStyle(tint: .cyan))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    // Task List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if filteredTasks.isEmpty {
                                EmptyFilterView(filter: selectedFilter)
                            } else {
                                ForEach(filteredTasks) { task in
                                    CompactTaskRow(task: task)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Time Filter Tab
struct TimeFilterTab: View {
    let filter: TimeFilter
    let isSelected: Bool
    let count: Int
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: filter.icon)
                .font(.system(size: 20))
            
            Text(filter.rawValue)
                .font(.system(size: 12, weight: .semibold))
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .white : filter.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? filter.color : filter.color.opacity(0.2))
                    )
            }
        }
        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
        .frame(width: 80, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? filter.color.opacity(0.3) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? filter.color : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Compact Task Row
struct CompactTaskRow: View {
    let task: VisualTask
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator (replaces checkbox)
            Circle()
                .fill(task.effectivePriorityLevel.color)
                .frame(width: 12, height: 12)
            
            // Avatar
            Text(task.userAvatar)
                .font(.title3)
            
            // Task Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(task.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Priority
                    HStack(spacing: 2) {
                        Image(systemName: task.effectivePriorityLevel.icon)
                            .font(.system(size: 10))
                        Text(task.effectivePriorityLevel.name)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(task.effectivePriorityLevel.color)
                    
                    // Time
                    Text(task.deadlineFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Time remaining
            if !task.isCompleted {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(task.timeRemainingFormatted)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(task.urgencyColor)
                    
                    if task.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                }
            } else {
                // Show completed checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(task.isCompleted ? 0.03 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
                .environmentObject(dataManager)
        }
    }
}

// MARK: - Empty Filter View
struct EmptyFilterView: View {
    let filter: TimeFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: filter.icon)
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [filter.color, filter.color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No tasks for \(filter.rawValue.lowercased())")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Add a task to get started")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    AllTasksView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
