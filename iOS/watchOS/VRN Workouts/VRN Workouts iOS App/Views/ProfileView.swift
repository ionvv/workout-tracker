import SwiftUI

struct ProfileView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User info
                Section {
                    if let email = authService.userEmail {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(email)
                                    .font(.headline)
                                Text("Signed in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Body Stats
                Section("Body Stats") {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack {
                            Label("Weight", systemImage: "scalemass")
                            Spacer()
                            if let weight = profileService.profile.weightInDisplayUnit {
                                Text(String(format: "%.1f %@", weight, profileService.profile.unitSystem.weightUnit))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack {
                            Label("Height", systemImage: "ruler")
                            Spacer()
                            if let height = profileService.profile.heightInDisplayUnit {
                                Text(String(format: "%.0f %@", height, profileService.profile.unitSystem.heightUnit))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let bmi = profileService.profile.bmi, let category = profileService.profile.bmiCategory {
                        HStack {
                            Label("BMI", systemImage: "heart.text.square")
                            Spacer()
                            Text(String(format: "%.1f (%@)", bmi, category))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Settings
                Section("Settings") {
                    Picker(selection: $profileService.profile.unitSystem) {
                        ForEach(UserProfile.UnitSystem.allCases, id: \.self) { system in
                            Text(system.displayName).tag(system)
                        }
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                    .onChange(of: profileService.profile.unitSystem) { _, newValue in
                        profileService.updateUnitSystem(newValue)
                    }
                    
                    NavigationLink {
                        Text("Notifications settings coming soon")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink {
                        Text("Rest timer settings coming soon")
                    } label: {
                        Label("Rest Timer", systemImage: "timer")
                    }
                }
                
                // Health & Devices
                Section("Health & Devices") {
                    NavigationLink {
                        Text("HealthKit settings coming soon")
                    } label: {
                        Label("Apple Health", systemImage: "heart.fill")
                    }
                    
                    NavigationLink {
                        WatchPairingView()
                    } label: {
                        HStack {
                            Label("Apple Watch", systemImage: "applewatch")
                            Spacer()
                            WatchStatusIndicator()
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://workout-tracker-963.pages.dev")!) {
                        Label("Web App", systemImage: "globe")
                    }
                }
                
                // Sign out
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            } message: {
                Text("You'll need to sign in again to access your workouts.")
            }
        }
    }
}

// MARK: - Watch Status Indicator

struct WatchStatusIndicator: View {
    @StateObject private var watchService = WatchConnectivityService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusText: String {
        if watchService.isReachable {
            return "Connected"
        } else if watchService.isPaired {
            return "Paired"
        } else {
            return "Not paired"
        }
    }
    
    private var statusColor: Color {
        if watchService.isReachable {
            return .green
        } else if watchService.isPaired {
            return .orange
        } else {
            return .gray
        }
    }
}

#Preview {
    ProfileView()
}
