import SwiftUI

@main
struct VRNWorkoutsApp: App {
    @StateObject private var authService = AuthService.shared
    
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
        }
    }
}
