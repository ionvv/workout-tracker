import Foundation
import Combine

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var weeklyWorkouts = 0
    @Published var weeklyTotalVolume = 0
    @Published var weeklySets = 0
    @Published var weeklyVolume: [DailyVolume] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var muscleGroupStats: [MuscleGroupStat] = []
    @Published var isLoading = false
    
    func loadAnalytics() async {
        isLoading = true
        
        do {
            let sessions = try await SessionService.shared.fetchSessions()
            calculateWeeklyStats(from: sessions)
            calculatePersonalRecords(from: sessions)
            calculateStreak(from: sessions)
            calculateMuscleGroups(from: sessions)
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
    
    private func calculateStreak(from sessions: [WorkoutSession]) {
        let calendar = Calendar.current
        let sortedDates = sessions
            .map { calendar.startOfDay(for: $0.startTime) }
            .sorted(by: >)
        
        guard !sortedDates.isEmpty else {
            currentStreak = 0
            longestStreak = 0
            return
        }
        
        // Remove duplicates (multiple sessions on same day)
        let uniqueDates = Array(Set(sortedDates)).sorted(by: >)
        
        // Calculate current streak
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        for date in uniqueDates {
            if date == checkDate || date == calendar.date(byAdding: .day, value: -1, to: checkDate) {
                streak += 1
                checkDate = date
            } else if date < calendar.date(byAdding: .day, value: -1, to: checkDate)! {
                break
            }
        }
        currentStreak = streak
        
        // Calculate longest streak
        var longest = 0
        var current = 1
        for i in 1..<uniqueDates.count {
            let diff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i-1]).day ?? 0
            if diff == 1 {
                current += 1
            } else {
                longest = max(longest, current)
                current = 1
            }
        }
        longestStreak = max(longest, current)
    }
    
    private func calculateMuscleGroups(from sessions: [WorkoutSession]) {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        let thisWeekSessions = sessions.filter { $0.startTime >= startOfWeek }
        
        // Map exercise names to muscle groups (simplified)
        let muscleMapping: [String: String] = [
            "bench": "Chest",
            "press": "Shoulders",
            "squat": "Legs",
            "deadlift": "Back",
            "row": "Back",
            "curl": "Biceps",
            "tricep": "Triceps",
            "pullup": "Back",
            "pull-up": "Back",
            "lunge": "Legs",
            "leg": "Legs",
            "calf": "Legs",
            "shoulder": "Shoulders",
            "lateral": "Shoulders",
            "fly": "Chest",
            "dip": "Chest"
        ]
        
        var setsByMuscle: [String: Int] = [:]
        
        for session in thisWeekSessions {
            for exercise in session.exercises where !exercise.skipped {
                let name = exercise.exerciseName.lowercased()
                var muscleGroup = "Other"
                
                for (keyword, muscle) in muscleMapping {
                    if name.contains(keyword) {
                        muscleGroup = muscle
                        break
                    }
                }
                
                setsByMuscle[muscleGroup, default: 0] += exercise.sets.count
            }
        }
        
        let totalSets = setsByMuscle.values.reduce(0, +)
        guard totalSets > 0 else {
            muscleGroupStats = []
            return
        }
        
        muscleGroupStats = setsByMuscle
            .map { MuscleGroupStat(name: $0.key, sets: $0.value, percentage: Double($0.value) / Double(totalSets)) }
            .sorted { $0.sets > $1.sets }
    }
}
