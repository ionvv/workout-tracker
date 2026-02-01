import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ProgramsView()
            } else {
                DevicePairingView()
            }
        }
    }
}
