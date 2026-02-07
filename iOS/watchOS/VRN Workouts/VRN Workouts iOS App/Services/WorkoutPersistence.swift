import Foundation

/// Persists active workout session to device storage
class WorkoutPersistence {
    static let shared = WorkoutPersistence()
    
    private let key = "activeWorkoutSession"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    /// Save active session to device
    func saveSession(_ session: ActiveWorkoutSession) {
        let data = PersistableSession(from: session)
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
            print("💾 Saved workout session to device")
        }
    }
    
    /// Load active session from device
    func loadSession() -> PersistableSession? {
        guard let data = defaults.data(forKey: key),
              let session = try? JSONDecoder().decode(PersistableSession.self, from: data) else {
            return nil
        }
        print("💾 Loaded workout session from device")
        return session
    }
    
    /// Clear saved session
    func clearSession() {
        defaults.removeObject(forKey: key)
        print("💾 Cleared workout session from device")
    }
    
    /// Check if there's an active session saved
    func hasActiveSession() -> Bool {
        return defaults.data(forKey: key) != nil
    }
}

/// Codable version of ActiveWorkoutSession for persistence
struct PersistableSession: Codable {
    let sessionId: String
    let programId: String
    let programName: String
    let dayId: String
    let dayName: String
    let startTime: Date
    var exercises: [PersistableExercise]
    var currentExerciseIndex: Int
    
    init(from session: ActiveWorkoutSession) {
        self.sessionId = session.sessionId
        self.programId = session.programId
        self.programName = "" // We'll need to add this
        self.dayId = session.dayId
        self.dayName = session.dayName
        self.startTime = session.startTime
        self.exercises = session.exercises.map { PersistableExercise(from: $0) }
        self.currentExerciseIndex = session.currentExerciseIndex
    }
}

struct PersistableExercise: Codable {
    let exerciseId: String
    let exerciseName: String
    let prescribedSets: Int?
    let prescribedReps: String?
    var sets: [PersistableSet]
    var skipped: Bool
    
    init(from exercise: SessionExercise) {
        self.exerciseId = exercise.exerciseId
        self.exerciseName = exercise.exerciseName
        self.prescribedSets = exercise.prescribedSets
        self.prescribedReps = exercise.prescribedReps
        self.sets = exercise.sets.map { PersistableSet(from: $0) }
        self.skipped = exercise.skipped
    }
}

struct PersistableSet: Codable {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let timestamp: Date
    let rpe: Int?
    
    init(from set: SetLog) {
        self.setNumber = set.setNumber
        self.weight = set.weight
        self.reps = set.reps
        self.timestamp = set.timestamp
        self.rpe = set.rpe
    }
}
