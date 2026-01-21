//
//  VisualMemoryApp.swift
//  VisualMemory - Main App Entry Point
//  With comprehensive onboarding
//

import SwiftUI
import UserNotifications

@main
struct VisualMemoryApp: App {
    @StateObject private var dataManager = VisualMemoryDataManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedTaskSetup") private var hasCompletedTaskSetup = false
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            }
        }
        
        // Configure appearance
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if hasCompletedOnboarding && userManager.currentUser != nil {
            if hasCompletedTaskSetup {
                mainAppView
            } else {
                taskSetupView
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
    
    @ViewBuilder
    private var mainAppView: some View {
        MainTaskView()
            .environmentObject(dataManager)
            .environmentObject(userManager)
    }
    
    @ViewBuilder
    private var taskSetupView: some View {
        ClaudeSmartOnboardingView(onComplete: { selectedTasks in
            importTasks(selectedTasks)
        })
        .environmentObject(dataManager)
        .environmentObject(userManager)
    }
    
    private func importTasks(_ selectedTasks: [SOTask]) {
        let engine = TaskPriorityEngine()
        engine.clearAllTasks()
        engine.importFromOnboarding(selectedTasks)
        hasCompletedTaskSetup = true
    }
    
    private func configureAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

