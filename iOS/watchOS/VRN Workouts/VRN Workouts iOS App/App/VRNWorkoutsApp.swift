import SwiftUI

private let launchFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()
private func ts() -> String { "[\(launchFormatter.string(from: Date()))]" }

@main
struct VRNWorkoutsApp: App {
    // Delay auth service access to after first frame
    @State private var isReady = false
    @StateObject private var authService = AuthService.shared
    
    init() {
        print("\(ts()) 🚀 App init START")
        print("\(ts()) 🚀 App init END")
    }
    
    var body: some Scene {
        print("\(ts()) 🚀 body START")
        return WindowGroup {
            Group {
                if !isReady {
                    // Show splash immediately, no auth check
                    ProgressView("Loading...")
                        .onAppear {
                            print("\(ts()) 🚀 Splash appeared, scheduling ready")
                            // Delay auth check to next run loop
                            DispatchQueue.main.async {
                                print("\(ts()) 🚀 Setting isReady=true")
                                isReady = true
                            }
                        }
                } else if authService.isAuthenticated {
                    MainTabView()
                        .onAppear { print("\(ts()) 🚀 MainTabView appeared") }
                } else {
                    LoginView()
                        .onAppear { print("\(ts()) 🚀 LoginView appeared") }
                }
            }
        }
    }
}
