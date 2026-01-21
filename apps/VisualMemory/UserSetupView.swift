//
//  UserSetupView.swift
//  VisualMemory - iOS
//  Phase 2: First-time user profile setup
//

import SwiftUI

struct UserSetupView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var name = ""
    @State private var selectedAvatar = "👤"
    @State private var selectedColor = Color.blue
    
    let avatarOptions = ["👨‍💼", "👩‍💼", "👨‍🎓", "👩‍🎓", "👦", "👧", "👶", "👴", "👵", "🧑‍🦱", "👱‍♀️", "🧔"]
    let colorOptions: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .teal]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(selectedColor)
                        
                        Text("Welcome to VisualMemory!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Let's set up your profile")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section {
                    TextField("Enter your name", text: $name)
                        .font(.headline)
                } header: {
                    Text("Your Name")
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                        ForEach(avatarOptions, id: \.self) { avatar in
                            Button(action: { selectedAvatar = avatar }) {
                                Text(avatar)
                                    .font(.system(size: 50))
                                    .frame(width: 70, height: 70)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(selectedAvatar == avatar ? selectedColor.opacity(0.3) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(selectedAvatar == avatar ? selectedColor : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 10)
                } header: {
                    Text("Choose Your Avatar")
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                        ForEach(colorOptions, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 10)
                } header: {
                    Text("Choose Your Color")
                }
                
                Section {
                    HStack(spacing: 20) {
                        Text(selectedAvatar)
                            .font(.system(size: 60))
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(name.isEmpty ? "Your Name" : name)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Family Member")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(selectedColor.opacity(0.2))
                    )
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Profile Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        createUser()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createUser() {
        let newUser = UserProfile(
            name: name,
            avatarEmoji: selectedAvatar,
            color: selectedColor.toHex() ?? "#007AFF",
            isCurrentUser: true
        )
        
        userManager.setCurrentUser(newUser)
    }
}
