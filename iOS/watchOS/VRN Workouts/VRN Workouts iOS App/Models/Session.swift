import Foundation
import Combine

struct WorkoutSession: Codable, Identifiable {
    let dbId: UUID?
    let odid: Int?  // Some DBs use integer IDs
    let userId: UUID?
    let sessionId: String
    let programId: String?
    let dayId: String?
    let dayName: String
    let startTime: Date
    var endTime: Date?
    var exercises: [SessionExercise]
    var notes: String?
    var totalVolume: Int?
    var totalSets: Int?
    var duration: Int?
    var bodyWeight: Double?  // User's body weight logged during this session (kg)
    var createdAt: Date?
    var updatedAt: Date?
    
    // Identifiable - use sessionId as the identifier
    var id: String { sessionId }
    
    enum CodingKeys: String, CodingKey {
        case dbId = "id"
        case odid
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
        case bodyWeight = "body_weight"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(dbId: UUID?, odid: Int? = nil, userId: UUID?, sessionId: String, programId: String?, dayId: String?, dayName: String, startTime: Date, endTime: Date?, exercises: [SessionExercise], notes: String?, totalVolume: Int?, totalSets: Int?, duration: Int?, bodyWeight: Double? = nil, createdAt: Date?, updatedAt: Date?) {
        self.dbId = dbId
        self.odid = odid
        self.userId = userId
        self.sessionId = sessionId
        self.programId = programId
        self.dayId = dayId
        self.dayName = dayName
        self.startTime = startTime
        self.endTime = endTime
        self.exercises = exercises
        self.notes = notes
        self.totalVolume = totalVolume
        self.totalSets = totalSets
        self.duration = duration
        self.bodyWeight = bodyWeight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        dbId = try container.decodeIfPresent(UUID.self, forKey: .dbId)
        odid = try container.decodeIfPresent(Int.self, forKey: .odid)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        programId = try container.decodeIfPresent(String.self, forKey: .programId)
        dayId = try container.decodeIfPresent(String.self, forKey: .dayId)
        dayName = try container.decode(String.self, forKey: .dayName)
        exercises = try container.decode([SessionExercise].self, forKey: .exercises)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        totalVolume = try container.decodeIfPresent(Int.self, forKey: .totalVolume)
        totalSets = try container.decodeIfPresent(Int.self, forKey: .totalSets)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        bodyWeight = try container.decodeIfPresent(Double.self, forKey: .bodyWeight)
        
        // Flexible date decoding
        startTime = Self.decodeDate(from: container, forKey: .startTime) ?? Date()
        endTime = Self.decodeDate(from: container, forKey: .endTime)
        createdAt = Self.decodeDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeDate(from: container, forKey: .updatedAt)
    }
    
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try ISO8601 string first
        if let dateString = try? container.decode(String.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Try with timezone offset format
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            if let date = df.date(from: dateString) {
                return date
            }
        }
        // Try unix timestamp
        if let timestamp = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
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
    
    init(setNumber: Int, weight: Double, reps: Int, timestamp: Date, rpe: Int?) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.timestamp = timestamp
        self.rpe = rpe
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setNumber = try container.decode(Int.self, forKey: .setNumber)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
        
        // Handle timestamp as either String (ISO8601) or Double (unix timestamp)
        if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                timestamp = date
            } else {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: dateString) ?? Date()
            }
        } else if let unixTimestamp = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: unixTimestamp)
        } else {
            timestamp = Date()
        }
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
    @Published var bodyWeight: Double?
    
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
        (currentExercise?.sets.count ?? 0) >= (currentExercise?.prescribedSets ?? 0)
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
