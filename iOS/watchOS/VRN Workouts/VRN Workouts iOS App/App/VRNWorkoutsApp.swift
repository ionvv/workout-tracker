import SwiftUI

@main
struct VRNWorkoutsApp: App {
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .onAppear {
                            print("📱 MainTabView appeared at \(Date())")
                        }
                } else {
                    LoginView()
                        .onAppear {
                            print("📱 LoginView appeared at \(Date())")
                        }
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                print("📱 isAuthenticated changed: \(oldValue) -> \(newValue) at \(Date())")
            }
            .onAppear {
                print("🚀 App: onAppear at \(Date()), isAuthenticated=\(authService.isAuthenticated)")
            }
            // HealthKit workout continues in background - only stopped when user ends workout
        }
    }
}
