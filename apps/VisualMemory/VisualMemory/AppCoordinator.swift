import SwiftUI
import Combine

// MARK: - App Coordinator
// This manages the flow from onboarding to main app and transfers tasks

struct AppCoordinatorView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some View {
        Group {
            if coordinator.hasCompletedOnboarding {
                MainTaskView()
                    .environmentObject(coordinator)
            } else {
                ClaudeSmartOnboardingView(onComplete: { selectedTasks in
                    coordinator.completeOnboarding(with: selectedTasks)
                })
            }
        }
        .preferredColorScheme(.dark)
    }
}

@MainActor
class AppCoordinator: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    
    private let onboardingKey = "hasCompletedOnboarding_v2"
    private let tasksKey = "appTasks_v1"
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        
        // If user hasn't completed onboarding, clear any old task data
        if !hasCompletedOnboarding {
            UserDefaults.standard.removeObject(forKey: tasksKey)
        }
    }
    
    func completeOnboarding(with tasks: [SOTask]) {
        // Clear any existing tasks first
        UserDefaults.standard.removeObject(forKey: tasksKey)
        
        // Create engine and import tasks
        let engine = TaskPriorityEngine()
        engine.importFromOnboarding(tasks)
        
        // Mark onboarding as complete
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: onboardingKey)
        UserDefaults.standard.removeObject(forKey: tasksKey)
    }
}

// MARK: - Preview

#Preview {
    AppCoordinatorView()
}
