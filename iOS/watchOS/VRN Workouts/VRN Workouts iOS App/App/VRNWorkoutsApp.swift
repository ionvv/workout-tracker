import SwiftUI

@main
struct VRNWorkoutsApp: App {
    @StateObject private var authService = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase
    
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
            .task {
                print("🚀 App: task started at \(Date())")
                // Check session in background - UI shows immediately
                await authService.checkSession()
                print("🚀 App: task completed at \(Date())")
            }
            .onAppear {
                print("🚀 App: onAppear at \(Date())")
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
