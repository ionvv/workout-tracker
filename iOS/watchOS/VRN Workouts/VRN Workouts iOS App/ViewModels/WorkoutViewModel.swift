import Foundation
import Combine
import SwiftUI
import HealthKit

@MainActor
class WorkoutViewModel: NSObject, ObservableObject {
    @Published var activeSession: ActiveWorkoutSession?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var restTimeRemaining: Int = 0
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    private var restTimer: Timer?
    private var restStartTime: Date?
    private var restDuration: Int = 0
    
    // Store exercise rest times for rest timer
    private var exerciseRestTimes: [Int] = []
    
    // HealthKit
    private let healthStore = HKHealthStore()
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkWorkoutBuilder: HKLiveWorkoutBuilder?
    
    override init() {
        super.init()
    }
    
    func startWorkout(program: Program, day: WorkoutDay) {
        activeSession = ActiveWorkoutSession(program: program, day: day)
        // Store rest times for each exercise
        exerciseRestTimes = day.exerciseList.map { $0.rest }
        startHealthKitWorkout()
    }
    
    func logSet(at index: Int, weight: Double, reps: Int, rpe: Int?) {
        guard let session = activeSession else { return }
        
        session.addSet(at: index, weight: weight, reps: reps, rpe: rpe)
        
        // Start rest timer
        if index < exerciseRestTimes.count {
            let restSeconds = exerciseRestTimes[index]
            startRestTimer(seconds: restSeconds)
        }
    }
    
    func skipExercise(at index: Int) {
        activeSession?.skipExercise(at: index)
    }
    
    func nextExercise() {
        activeSession?.moveToNextExercise()
    }
    
    func endWorkout() async {
        guard let session = activeSession else { return }
        
        isSaving = true
        
        // End HealthKit workout
        await endHealthKitWorkout()
        
        do {
            try await SessionService.shared.saveSession(session)
            activeSession = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
        stopRestTimer()
    }
    
    func cancelWorkout() {
        hkWorkoutSession?.end()
        hkWorkoutSession = nil
        hkWorkoutBuilder = nil
        activeSession = nil
        stopRestTimer()
    }
    
    // MARK: - Rest Timer
    
    private func startRestTimer(seconds: Int) {
        stopRestTimer()
        restStartTime = Date()
        restDuration = seconds
        restTimeRemaining = seconds
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let startTime = self.restStartTime else { return }
                
                let elapsed = Int(Date().timeIntervalSince(startTime))
                self.restTimeRemaining = max(0, self.restDuration - elapsed)
                
                if self.restTimeRemaining <= 0 {
                    self.stopRestTimer()
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimeRemaining = 0
        restStartTime = nil
    }
    
    // MARK: - HealthKit
    
    private func startHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, _ in
            if success {
                Task { @MainActor in
                    self?.beginWorkoutSession()
                }
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
            
            hkWorkoutSession?.delegate = self
            hkWorkoutBuilder?.delegate = self
            
            let startDate = Date()
            hkWorkoutSession?.startActivity(with: startDate)
            
            Task {
                try? await hkWorkoutBuilder?.beginCollection(at: startDate)
            }
        } catch {
            print("Failed to create workout session:", error)
        }
    }
    
    private func endHealthKitWorkout() async {
        guard let session = hkWorkoutSession, let builder = hkWorkoutBuilder else { return }
        
        let endDate = Date()
        session.end()
        
        do {
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
        } catch {
            print("Failed to save HealthKit workout:", error)
        }
        
        hkWorkoutSession = nil
        hkWorkoutBuilder = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutViewModel: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error:", error)
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
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
