import Foundation

struct Program: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let programId: String
    let programName: String
    let workoutDays: [WorkoutDay]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case programId = "program_id"
        case programName = "program_name"
        case workoutDays = "workout_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutDay: Codable, Identifiable {
    let dayId: String
    let dayName: String
    let exercises: [Exercise]
    
    var id: String { dayId }
    
    enum CodingKeys: String, CodingKey {
        case dayId = "dayId"
        case dayName = "dayName"
        case exercises
    }
}

struct Exercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let prescribedSets: Int
    let prescribedReps: String
    let notes: String?
    let restSeconds: Int
    let demoUrl: String?
    let gifUrl: String?
    let type: String
    
    var id: String { exerciseId }
    
    enum CodingKeys: String, CodingKey {
        case exerciseId = "exerciseId"
        case name
        case prescribedSets = "prescribedSets"
        case prescribedReps = "prescribedReps"
        case notes
        case restSeconds = "restSeconds"
        case demoUrl = "demoUrl"
        case gifUrl = "gifUrl"
        case type
    }
}
