import SwiftUI

extension Notification.Name {
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let appWillEnterForeground = Notification.Name("appWillEnterForeground")
}

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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    print("📱 App entered background")
                    NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
                } else if newPhase == .active && oldPhase == .background {
                    print("📱 App returned to foreground")
                    NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
                }
            }
            .onAppear {
                print("🚀 App: onAppear at \(Date()), isAuthenticated=\(authService.isAuthenticated)")
            }
        }
    }
}
