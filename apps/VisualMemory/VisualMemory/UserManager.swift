//
//  UserManager.swift
//  VisualMemory - Phase 1
//  User profile and family member management
//

import SwiftUI
import Combine

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var users: [UserProfile] = []
    @Published var currentUser: UserProfile?
    
    private let currentUserKey = "currentUser"
    private let usersKey = "familyUsers"
    
    init() {
        loadCurrentUser()
        loadUsers()
        
        print("👤 UserManager initialized")
        print("   Current user: \(currentUser?.name ?? "none")")
        print("   Total users: \(users.count)")
    }
    
    // MARK: - Current User Management
    
    func loadCurrentUser() {
        if let userData = UserDefaults.standard.data(forKey: currentUserKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            currentUser = user
            print("✅ Current user loaded: \(user.name)")
        } else {
            currentUser = nil
            print("⚠️ No current user found")
        }
    }
    
    func setCurrentUser(_ user: UserProfile) {
        var updatedUser = user
        updatedUser.isCurrentUser = true
        currentUser = updatedUser
        
        // Update in users list
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            // Remove current status from all others
            for i in users.indices {
                users[i].isCurrentUser = false
            }
            users[index] = updatedUser
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(updatedUser) {
            UserDefaults.standard.set(encoded, forKey: currentUserKey)
        }
        
        saveUsers()
        print("✅ Current user set: \(updatedUser.name)")
    }
    
    // MARK: - Users List Management
    
    func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let decoded = try? JSONDecoder().decode([UserProfile].self, from: data) {
            users = decoded
            print("✅ Loaded \(users.count) family members")
        }
    }
    
    func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
        }
    }
    
    func addUser(_ user: UserProfile) {
        guard !users.contains(where: { $0.id == user.id }) else { return }
        users.append(user)
        saveUsers()
        print("✅ Added user: \(user.name)")
    }
    
    func removeUser(_ user: UserProfile) {
        users.removeAll { $0.id == user.id }
        saveUsers()
        print("🗑️ Removed user: \(user.name)")
    }
    
    func updateUser(_ user: UserProfile) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
            saveUsers()
            
            // Update current user if it's the same person
            if currentUser?.id == user.id {
                currentUser = user
                if let encoded = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(encoded, forKey: currentUserKey)
                }
            }
            
            print("✅ Updated user: \(user.name)")
        }
    }
    
    // MARK: - Helpers
    
    func user(withId id: UUID) -> UserProfile? {
        users.first { $0.id == id }
    }
    
    var otherUsers: [UserProfile] {
        users.filter { $0.id != currentUser?.id }
    }
}
