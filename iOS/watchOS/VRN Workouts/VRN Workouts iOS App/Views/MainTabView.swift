import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingActiveWorkout = false
    @StateObject private var workoutState = WorkoutStateManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ProgramsView()
                    .tabItem {
                        Label("Programs", systemImage: "list.bullet.clipboard")
                    }
                    .tag(0)
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(3)
            }
            .tint(.blue)
            
            // Active session banner above tab bar
            VStack {
                Spacer()
                ActiveSessionBanner {
                    showingActiveWorkout = true
                }
                .padding(.bottom, 50) // Above tab bar
            }
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ResumeWorkoutView()
        }
        .onAppear {
            workoutState.checkForSavedSession()
        }
    }
}

#Preview {
    MainTabView()
}
