import Foundation
import Combine
import SwiftUI

/// Global manager for active workout state - observable from any view
@MainActor
class WorkoutStateManager: ObservableObject {
    static let shared = WorkoutStateManager()
    
    @Published var hasActiveSession = false
    @Published var activeSessionSummary: SessionSummary?
    
    private init() {
        // Check for saved session on init
        checkForSavedSession()
    }
    
    func checkForSavedSession() {
        if let saved = WorkoutPersistence.shared.loadSession() {
            hasActiveSession = true
            activeSessionSummary = SessionSummary(
                dayName: saved.dayName,
                startTime: saved.startTime,
                exerciseCount: saved.exercises.count,
                completedSets: saved.exercises.reduce(0) { $0 + $1.sets.count }
            )
            print("📍 Found active session: \(saved.dayName)")
        } else {
            hasActiveSession = false
            activeSessionSummary = nil
        }
    }
    
    func sessionStarted(dayName: String, exerciseCount: Int) {
        hasActiveSession = true
        activeSessionSummary = SessionSummary(
            dayName: dayName,
            startTime: Date(),
            exerciseCount: exerciseCount,
            completedSets: 0
        )
    }
    
    func sessionEnded() {
        hasActiveSession = false
        activeSessionSummary = nil
        WorkoutPersistence.shared.clearSession()
    }
    
    func updateSets(count: Int) {
        activeSessionSummary?.completedSets = count
    }
}

struct SessionSummary {
    let dayName: String
    let startTime: Date
    let exerciseCount: Int
    var completedSets: Int
    
    var elapsedTime: String {
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        return "\(minutes) min"
    }
}
