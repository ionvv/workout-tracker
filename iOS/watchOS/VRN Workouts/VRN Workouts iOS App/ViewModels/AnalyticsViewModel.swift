import Foundation

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var weeklyWorkouts = 0
    @Published var weeklyTotalVolume = 0
    @Published var weeklySets = 0
    @Published var weeklyVolume: [DailyVolume] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var isLoading = false
    
    func loadAnalytics() async {
        isLoading = true
        
        do {
            let sessions = try await SessionService.shared.fetchSessions()
            calculateWeeklyStats(from: sessions)
            calculatePersonalRecords(from: sessions)
        } catch {
            print("Failed to load analytics:", error)
        }
        
        isLoading = false
    }
    
    private func calculateWeeklyStats(from sessions: [WorkoutSession]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        let thisWeekSessions = sessions.filter { $0.startTime >= startOfWeek }
        
        weeklyWorkouts = thisWeekSessions.count
        weeklyTotalVolume = thisWeekSessions.reduce(0) { $0 + ($1.totalVolume ?? 0) }
        weeklySets = thisWeekSessions.reduce(0) { $0 + ($1.totalSets ?? 0) }
        
        // Daily breakdown
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        
        var volumeByDay: [String: Int] = [:]
        for session in thisWeekSessions {
            let day = dayFormatter.string(from: session.startTime)
            volumeByDay[day, default: 0] += session.totalVolume ?? 0
        }
        
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        weeklyVolume = days.map { DailyVolume(day: $0, volume: volumeByDay[$0] ?? 0) }
    }
    
    private func calculatePersonalRecords(from sessions: [WorkoutSession]) {
        var recordsByExercise: [String: (weight: Double, reps: Int, date: Date)] = [:]
        
        for session in sessions {
            for exercise in session.exercises where !exercise.skipped {
                for set in exercise.sets {
                    let key = exercise.exerciseName
                    let current = recordsByExercise[key]
                    
                    // PR is the heaviest weight for the same or more reps
                    if current == nil || set.weight > current!.weight {
                        recordsByExercise[key] = (set.weight, set.reps, session.startTime)
                    }
                }
            }
        }
        
        personalRecords = recordsByExercise.map { key, value in
            PersonalRecord(exerciseName: key, weight: value.weight, reps: value.reps, date: value.date)
        }
        .sorted { $0.date > $1.date }
    }
}
