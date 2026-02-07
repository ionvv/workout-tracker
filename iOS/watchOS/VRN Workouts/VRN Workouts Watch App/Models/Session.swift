import Foundation
import Combine

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let sessionId: String
    let programId: String
    let dayId: String
    let dayName: String
    let startTime: Date
    var endTime: Date?
    var exercises: [SessionExercise]
    var notes: String?
    var totalVolume: Int?
    var totalSets: Int?
    var duration: Int?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case programId = "program_id"
        case dayId = "day_id"
        case dayName = "day_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case exercises
        case notes
        case totalVolume = "total_volume"
        case totalSets = "total_sets"
        case duration
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SessionExercise: Codable, Identifiable {
    let exerciseId: String
    let exerciseName: String
    let prescribedSets: Int?
    let prescribedReps: String?
    var sets: [SetLog]
    var skipped: Bool
    
    var id: String { exerciseId }
    
    enum CodingKeys: String, CodingKey {
        case exerciseId = "exerciseId"
        case exerciseName = "exerciseName"
        case prescribedSets = "prescribedSets"
        case prescribedReps = "prescribedReps"
        case sets
        case skipped
    }
}

struct SetLog: Codable, Identifiable {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let timestamp: Date
    let rpe: Int?
    
    var id: String { "\(timestamp.timeIntervalSince1970)-\(setNumber)" }
    
    enum CodingKeys: String, CodingKey {
        case setNumber = "setNumber"
        case weight
        case reps
        case timestamp
        case rpe
    }
}

// Active workout session (in-memory, not saved until complete)
class ActiveWorkoutSession: ObservableObject {
    @Published var sessionId: String
    @Published var programId: String
    @Published var dayId: String
    @Published var dayName: String
    @Published var startTime: Date
    @Published var exercises: [SessionExercise]
    @Published var currentExerciseIndex: Int = 0
    
    init(program: Program, day: WorkoutDay) {
        self.sessionId = UUID().uuidString
        self.programId = program.programId
        self.dayId = day.dayId
        self.dayName = day.dayName
        self.startTime = Date()
        self.exercises = day.exerciseList.map { ex in
            SessionExercise(
                exerciseId: ex.exerciseId ?? UUID().uuidString,
                exerciseName: ex.name,
                prescribedSets: ex.sets,  // Uses computed property
                prescribedReps: ex.reps,   // Uses computed property
                sets: [],
                skipped: false
            )
        }
    }
    
    var currentExercise: SessionExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }
    
    func addSet(weight: Double, reps: Int, rpe: Int? = nil) {
        guard currentExerciseIndex < exercises.count else { return }
        
        let setNumber = exercises[currentExerciseIndex].sets.count + 1
        let newSet = SetLog(
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            timestamp: Date(),
            rpe: rpe
        )
        
        exercises[currentExerciseIndex].sets.append(newSet)
    }
    
    func addSet(at index: Int, weight: Double, reps: Int, rpe: Int? = nil) {
        guard index < exercises.count else { return }
        
        let setNumber = exercises[index].sets.count + 1
        let newSet = SetLog(
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            timestamp: Date(),
            rpe: rpe
        )
        
        exercises[index].sets.append(newSet)
    }
    
    func skipExercise() {
        guard currentExerciseIndex < exercises.count else { return }
        exercises[currentExerciseIndex].skipped = true
        moveToNextExercise()
    }
    
    func skipExercise(at index: Int) {
        guard index < exercises.count else { return }
        exercises[index].skipped = true
    }
    
    func moveToNextExercise() {
        if currentExerciseIndex < exercises.count - 1 {
            currentExerciseIndex += 1
        }
    }
    
    var isComplete: Bool {
        currentExerciseIndex >= exercises.count - 1 &&
        (currentExercise?.sets.count ?? 0) >= (currentExercise?.prescribedSets ?? 1)
    }
    
    func calculateStats() -> (volume: Int, sets: Int, duration: Int) {
        let volume = exercises.reduce(0) { total, ex in
            total + ex.sets.reduce(0) { exTotal, set in
                exTotal + Int(set.weight * Double(set.reps))
            }
        }
        
        let sets = exercises.reduce(0) { $0 + $1.sets.count }
        let duration = Int(Date().timeIntervalSince(startTime) / 60)
        
        return (volume, sets, duration)
    }
}
