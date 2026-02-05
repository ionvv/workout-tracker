import Foundation
import SwiftUI
import Combine
import HealthKit

@MainActor
class WorkoutViewModel: NSObject, ObservableObject {
    @Published var activeSession: ActiveWorkoutSession?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var restTimeRemaining: Int = 0
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    private let sessionService = SessionService.shared
    private var restTimer: Timer?
    
    // HealthKit
    private let healthStore = HKHealthStore()
    
    override init() {
        super.init()
    }
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkWorkoutBuilder: HKLiveWorkoutBuilder?
    
    func startWorkout(program: Program, day: WorkoutDay) {
        activeSession = ActiveWorkoutSession(program: program, day: day)
        startHealthKitWorkout()
    }
    
    private func startHealthKitWorkout() {
        // Check HealthKit availability
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        // Request authorization
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            if success {
                Task { @MainActor in
                    self?.beginWorkoutSession()
                }
            } else if let error = error {
                print("❌ HealthKit auth error:", error)
            }
        }
    }
    
    private func beginWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            hkWorkoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            hkWorkoutBuilder = hkWorkoutSession?.associatedWorkoutBuilder()
            
            hkWorkoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Set delegate to receive heart rate updates
            hkWorkoutSession?.delegate = self
            hkWorkoutBuilder?.delegate = self
            
            // Start the workout session
            let startDate = Date()
            hkWorkoutSession?.startActivity(with: startDate)
            
            Task {
                do {
                    try await hkWorkoutBuilder?.beginCollection(at: startDate)
                    print("✅ HealthKit workout started")
                } catch {
                    print("❌ Failed to begin collection:", error)
                }
            }
        } catch {
            print("❌ Failed to create workout session:", error)
        }
    }
    
    func logSet(weight: Double, reps: Int, rpe: Int? = nil) {
        activeSession?.addSet(weight: weight, reps: reps, rpe: rpe)
        
        // Start rest timer
        startRestTimer(seconds: 120) // Default 2 min rest
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
        
        // End HealthKit workout
        await endHealthKitWorkout()
        
        do {
            try await sessionService.saveSession(session, notes: notes)
            activeSession = nil
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
    
    private func endHealthKitWorkout() async {
        guard let session = hkWorkoutSession, let builder = hkWorkoutBuilder else { return }
        
        let endDate = Date()
        session.end()
        
        do {
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
            print("✅ HealthKit workout saved")
        } catch {
            print("❌ Failed to save HealthKit workout:", error)
        }
        
        hkWorkoutSession = nil
        hkWorkoutBuilder = nil
    }
    
    func cancelWorkout() {
        // End HealthKit session without saving
        hkWorkoutSession?.end()
        hkWorkoutSession = nil
        hkWorkoutBuilder = nil
        
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

// MARK: - HKWorkoutSessionDelegate
extension WorkoutViewModel: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("📱 Workout state: \(fromState.rawValue) → \(toState.rawValue)")
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session error:", error)
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutViewModel: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            Task { @MainActor in
                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let value = statistics?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
                        self.heartRate = value
                    }
                case HKQuantityType(.activeEnergyBurned):
                    if let value = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeCalories = value
                    }
                default:
                    break
                }
            }
        }
    }
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
