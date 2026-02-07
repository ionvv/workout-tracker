import SwiftUI

@main
struct VRNWorkoutsApp: App {
    @StateObject private var authService = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    // Loading screen while checking session
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                } else if authService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    // App going to background - end any active HealthKit session
                    NotificationCenter.default.post(name: .appWillResignActive, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let appWillResignActive = Notification.Name("appWillResignActive")
}
