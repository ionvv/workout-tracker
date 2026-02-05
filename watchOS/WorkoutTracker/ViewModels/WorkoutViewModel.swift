import Foundation
import SwiftUI

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var activeSession: ActiveWorkoutSession?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var restTimeRemaining: Int = 0
    
    private let sessionService = SessionService.shared
    private var restTimer: Timer?
    
    func startWorkout(program: Program, day: WorkoutDay) {
        activeSession = ActiveWorkoutSession(program: program, day: day)
    }
    
    func logSet(weight: Double, reps: Int, rpe: Int? = nil) {
        activeSession?.addSet(weight: weight, reps: reps, rpe: rpe)
        
        // Start rest timer if exercise has rest time
        if let currentEx = activeSession?.currentExercise,
           let originalEx = activeSession?.exercises.first(where: { $0.exerciseId == currentEx.exerciseId }) {
            // Get rest time from program data (would need to store this)
            startRestTimer(seconds: 120) // Default 2 min rest
        }
    }
    
    func skipCurrentExercise() {
        activeSession?.skipExercise()
    }
    
    func moveToNextExercise() {
        activeSession?.moveToNextExercise()
        stopRestTimer()
    }
    
    func endWorkout(notes: String = "") async {
        guard let session = activeSession else { return }
        
        isSaving = true
        errorMessage = nil
        
        do {
            try await sessionService.saveSession(session, notes: notes)
            activeSession = nil
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
    
    func cancelWorkout() {
        activeSession = nil
        stopRestTimer()
    }
    
    // Rest Timer
    private func startRestTimer(seconds: Int) {
        stopRestTimer()
        restTimeRemaining = seconds
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.stopRestTimer()
                    // Haptic feedback when rest is done
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimeRemaining = 0
    }
}
