//
//  SettingsView.swift
//  VisualMemory - Settings Screen
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: VisualMemoryDataManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedTaskSetup") private var hasCompletedTaskSetup = false
    
    @State private var showingResetAlert = false
    @State private var showingClearTasksAlert = false
    @State private var voiceAlertsEnabled = true
    @State private var pushNotificationsEnabled = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Section
                        userSection
                        
                        // Notifications Section
                        notificationsSection
                        
                        // App Settings Section
                        appSettingsSection
                        
                        // Data Section
                        dataSection
                        
                        // About Section
                        aboutSection
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Reset Onboarding", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetOnboarding()
            }
        } message: {
            Text("This will reset the task setup wizard. You'll need to go through it again.")
        }
        .alert("Clear All Tasks", isPresented: $showingClearTasksAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllTasks()
            }
        } message: {
            Text("This will permanently delete all your tasks. This cannot be undone.")
        }
    }
    
    // MARK: - User Section
    
    @ViewBuilder
    var userSection: some View {
        if let user = userManager.currentUser {
            VStack(spacing: 16) {
                sectionHeader("Profile")
                
                HStack(spacing: 16) {
                    Text(user.avatarEmoji)
                        .font(.system(size: 50))
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Level \(dataManager.userStats.level)")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(dataManager.userStats.currentStreak) day streak")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
    
    // MARK: - Notifications Section
    
    var notificationsSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Notifications")
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: "Push Notifications",
                    isOn: $pushNotificationsEnabled
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                SettingsToggleRow(
                    icon: "speaker.wave.2.fill",
                    iconColor: .purple,
                    title: "Voice Alerts",
                    isOn: $voiceAlertsEnabled
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - App Settings Section
    
    var appSettingsSection: some View {
        VStack(spacing: 16) {
            sectionHeader("App Settings")
            
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    icon: "clock.fill",
                    iconColor: .cyan,
                    title: "Day Start Time",
                    value: formatTime(userManager.currentUser?.dayStartTime ?? Date())
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                SettingsNavigationRow(
                    icon: "paintbrush.fill",
                    iconColor: .pink,
                    title: "Theme",
                    value: "Dark"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - Data Section
    
    var dataSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Data")
            
            VStack(spacing: 0) {
                Button(action: { showingResetAlert = true }) {
                    SettingsButtonRow(
                        icon: "arrow.counterclockwise",
                        iconColor: .yellow,
                        title: "Reset Task Setup",
                        textColor: .yellow
                    )
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                Button(action: { showingClearTasksAlert = true }) {
                    SettingsButtonRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "Clear All Tasks",
                        textColor: .red
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - About Section
    
    var aboutSection: some View {
        VStack(spacing: 16) {
            sectionHeader("About")
            
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "Version",
                    value: "1.0.0"
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                SettingsNavigationRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Made with",
                    value: "SwiftUI"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - Helpers
    
    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
            Spacer()
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    func resetOnboarding() {
        hasCompletedTaskSetup = false
        // Clear tasks from the priority engine
        let engine = TaskPriorityEngine()
        engine.clearAllTasks()
    }
    
    func clearAllTasks() {
        let engine = TaskPriorityEngine()
        engine.clearAllTasks()
        // Try to clear from dataManager if it has the method
        // dataManager.clearAllTasks()
    }
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.cyan)
        }
        .padding(14)
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(textColor)
            
            Spacer()
        }
        .padding(14)
    }
}

#Preview {
    SettingsView()
        .environmentObject(VisualMemoryDataManager.shared)
        .environmentObject(UserManager.shared)
}
