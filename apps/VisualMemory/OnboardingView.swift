//
//  OnboardingView.swift
//  VisualMemory - Simplified Quick Start
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var userName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.08, blue: 0.2),
                    Color(red: 0.06, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text("Welcome to")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("VisualMemory")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .white, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                // Name input
                VStack(spacing: 12) {
                    Text("What's your name?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    TextField("Enter your name", text: $userName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 40)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !userName.isEmpty {
                                createProfileAndStart()
                            }
                        }
                }
                
                Spacer()
                
                // Start button
                Button(action: createProfileAndStart) {
                    HStack(spacing: 10) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: userName.isEmpty ? [Color.gray.opacity(0.4), Color.gray.opacity(0.4)] : [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: userName.isEmpty ? .clear : .purple.opacity(0.5), radius: 10, y: 5)
                    )
                }
                .disabled(userName.isEmpty)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto-focus the name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }
    
    func createProfileAndStart() {
        guard !userName.isEmpty else { return }
        
        // Create and save user profile with defaults
        let profile = UserProfile(
            name: userName,
            avatarEmoji: "👤",
            color: "#00BCD4",
            isCurrentUser: true
        )
        
        UserManager.shared.addUser(profile)
        UserManager.shared.setCurrentUser(profile)
        
        // Mark onboarding complete
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
