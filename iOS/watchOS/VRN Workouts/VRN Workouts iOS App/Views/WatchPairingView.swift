import SwiftUI

struct WatchPairingView: View {
    @StateObject private var watchService = WatchConnectivityService.shared
    
    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    Image(systemName: "applewatch")
                        .font(.title)
                        .foregroundStyle(watchService.isPaired ? .green : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Watch")
                            .font(.headline)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }
                .padding(.vertical, 8)
            }
            
            // Details Section
            Section("Connection Details") {
                StatusRow(title: "Watch Paired", isActive: watchService.isPaired)
                StatusRow(title: "App Installed", isActive: watchService.isWatchAppInstalled)
                StatusRow(title: "Reachable", isActive: watchService.isReachable)
                
                if let lastSync = watchService.lastSyncDate {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Actions Section
            if watchService.isPaired && watchService.isWatchAppInstalled {
                Section("Actions") {
                    Button {
                        syncAuthToWatch()
                    } label: {
                        Label("Sync Login to Watch", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button {
                        watchService.openWatchApp()
                    } label: {
                        Label("Open Watch App", systemImage: "arrow.up.forward.app")
                    }
                }
            }
            
            // Help Section
            Section {
                if !watchService.isPaired {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to pair your Apple Watch")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HelpStep(number: 1, text: "Open the Watch app on your iPhone")
                            HelpStep(number: 2, text: "Tap 'All Watches' then 'Add Watch'")
                            HelpStep(number: 3, text: "Follow the pairing instructions")
                        }
                    }
                    .padding(.vertical, 8)
                } else if !watchService.isWatchAppInstalled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Install VRN Workouts on Watch")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HelpStep(number: 1, text: "Open the Watch app on your iPhone")
                            HelpStep(number: 2, text: "Scroll down to find VRN Workouts")
                            HelpStep(number: 3, text: "Tap 'Install'")
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var statusText: String {
        if !watchService.isPaired {
            return "No watch paired"
        } else if !watchService.isWatchAppInstalled {
            return "App not installed on Watch"
        } else if watchService.isReachable {
            return "Connected"
        } else {
            return "Paired but not reachable"
        }
    }
    
    private var statusColor: Color {
        if watchService.isReachable {
            return .green
        } else if watchService.isPaired && watchService.isWatchAppInstalled {
            return .orange
        } else {
            return .red
        }
    }
    
    private func syncAuthToWatch() {
        if let userId = AuthService.shared.userId,
           let email = AuthService.shared.userEmail {
            watchService.sendAuthToWatch(userId: userId, email: email)
        }
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isActive ? .green : .red)
        }
    }
}

struct HelpStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        WatchPairingView()
    }
}
