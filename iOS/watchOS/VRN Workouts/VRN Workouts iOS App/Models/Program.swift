import Foundation

struct Program: Codable, Identifiable {
    let dbId: UUID?
    let userId: UUID?
    let programId: String
    let programName: String
    let workoutDays: [WorkoutDay]?
    let createdAt: String?
    let updatedAt: String?
    
    // Identifiable conformance - use programId as stable identifier
    var id: String { programId }
    
    // Helper to get workout days safely
    var days: [WorkoutDay] { workoutDays ?? [] }
    
    enum CodingKeys: String, CodingKey {
        case dbId = "id"
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
    let exercises: [Exercise]?
    let dayType: String?
    let estimatedTime: Int?
    let warmup: WarmupCooldown?
    let cooldown: WarmupCooldown?
    let finisher: WarmupCooldown?
    let focusMuscles: [String]?
    let secondaryMuscles: [String]?
    
    var id: String { dayId }
    var exerciseList: [Exercise] { exercises ?? [] }
    
    enum CodingKeys: String, CodingKey {
        case dayId
        case dayName
        case exercises
        case dayType
        case estimatedTime
        case warmup
        case cooldown
        case finisher
        case focusMuscles
        case secondaryMuscles
    }
}

struct WarmupCooldown: Codable {
    let duration: Int?
    let exercises: [WarmupExercise]?
}

struct WarmupExercise: Codable {
    let name: String
    let duration: Int?
    let reps: Int?
    let sets: Int?
    let notes: String?
}

struct Exercise: Codable, Identifiable {
    let exerciseId: String?
    let exerciseDbId: String?
    let name: String
    let slug: String?
    
    // Core workout fields (new format)
    let workingSets: Int?
    let repsMin: Int?
    let repsMax: Int?
    let restSeconds: Int?
    let category: String?
    let difficulty: String?
    
    // Intensity fields
    let rpe: Int?
    let rir: Int?
    let tempo: String?
    let tempoDescription: String?
    
    // Media
    let media: ExerciseMedia?
    
    // Warmup info
    let warmupSets: Int?
    
    // Form guidance
    let formCues: [String]?
    
    // Equipment & muscles
    let equipment: [String]?
    let muscleGroups: MuscleGroups?
    
    // Superset info
    let supersetWith: String?
    let supersetType: String?
    
    // Legacy format fields (for backwards compatibility)
    let prescribedSets: Int?
    let prescribedReps: String?
    let notes: String?
    let demoUrl: String?
    let gifUrl: String?
    let type: String?
    
    var id: String { exerciseId ?? UUID().uuidString }
    
    // Computed properties for unified access
    var sets: Int { workingSets ?? prescribedSets ?? 3 }
    var reps: String { 
        if let min = repsMin, let max = repsMax {
            return min == max ? "\(min)" : "\(min)-\(max)"
        }
        return prescribedReps ?? "8-10"
    }
    var rest: Int { restSeconds ?? 90 }
    var imageUrl: String? { media?.gifUrl ?? gifUrl ?? demoUrl }
    
    /// Check if this is a timed exercise (planks, holds, etc.)
    var isTimed: Bool {
        // Check type field
        if let t = type?.lowercased() {
            if t.contains("timed") || t.contains("hold") || t.contains("isometric") {
                return true
            }
        }
        // Check category field
        if let c = category?.lowercased() {
            if c.contains("timed") || c.contains("hold") || c.contains("isometric") {
                return true
            }
        }
        // Check exercise name for common timed exercises
        let timedKeywords = ["plank", "hold", "hang", "wall sit", "l-sit", "dead hang"]
        let nameLower = name.lowercased()
        return timedKeywords.contains { nameLower.contains($0) }
    }
    
    /// Unit label for reps/seconds
    var repUnit: String { isTimed ? "sec" : "reps" }
}

struct MuscleGroups: Codable {
    let primary: [String]?
    let secondary: [String]?
}

struct ExerciseMedia: Codable {
    let gifUrl: String?
    let videoUrl: String?
    let thumbnailUrl: String?
}
