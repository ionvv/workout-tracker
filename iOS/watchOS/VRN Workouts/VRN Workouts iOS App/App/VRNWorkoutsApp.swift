import SwiftUI

private func ts() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return "[\(f.string(from: Date()))]"
}

@main
struct VRNWorkoutsApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        print("\(ts()) 🚀 VRNWorkoutsApp: init")
    }
    
    var body: some Scene {
        print("\(ts()) 🚀 VRNWorkoutsApp: body evaluated, isAuth=\(authService.isAuthenticated)")
        return WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .onAppear { print("\(ts()) 🚀 MainTabView appeared") }
                } else {
                    LoginView()
                        .onAppear { print("\(ts()) 🚀 LoginView appeared") }
                }
            }
            .onAppear { print("\(ts()) 🚀 Root view appeared") }
        }
    }
}
