import Foundation

/// Service for AI-powered workout program generation
actor AIProgramGenerator {
    static let shared = AIProgramGenerator()
    
    private let edgeFunctionURL = "\(Config.supabaseURL)/functions/v1/ai-workout-review"
    
    private init() {}
    
    struct GenerationResult {
        let program: Program?
        let remainingCredits: Int
        let error: String?
    }
    
    /// Generate a personalized workout program using AI
    func generateProgram(
        goal: FitnessGoal,
        daysPerWeek: Int,
        experience: ExperienceLevel,
        equipment: EquipmentType,
        sessionLength: Int,
        injuries: String?,
        preferences: String?,
        weight: Double?,
        height: Double?,
        age: Int?,
        gender: UserProfile.Gender?
    ) async -> GenerationResult {
        
        guard let token = await AuthService.shared.getAccessToken() else {
            return GenerationResult(program: nil, remainingCredits: 0, error: "Please log in again")
        }
        
        // Build the request
        let requestBody: [String: Any] = [
            "action": "generate_program",
            "params": [
                "goal": goal.rawValue,
                "daysPerWeek": daysPerWeek,
                "experience": experience.rawValue,
                "equipment": equipment.rawValue,
                "sessionLength": sessionLength,
                "injuries": injuries ?? "",
                "preferences": preferences ?? "",
                "weight": weight ?? 0,
                "height": height ?? 0,
                "age": age ?? 0,
                "gender": gender?.rawValue ?? ""
            ]
        ]
        
        var request = URLRequest(url: URL(string: edgeFunctionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // Program generation takes longer
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    return GenerationResult(program: nil, remainingCredits: 0, error: "PRO subscription required")
                }
                if httpResponse.statusCode == 429 {
                    return GenerationResult(program: nil, remainingCredits: 0, error: "Monthly limit reached")
                }
                if httpResponse.statusCode >= 400 {
                    let errorJson = try? JSONDecoder().decode(ProgramErrorResponse.self, from: data)
                    return GenerationResult(program: nil, remainingCredits: 0, error: errorJson?.error ?? "Failed to generate program")
                }
            }
            
            let result = try JSONDecoder().decode(GenerateProgramResponse.self, from: data)
            return GenerationResult(
                program: result.program,
                remainingCredits: result.usage.remaining,
                error: nil
            )
        } catch {
            return GenerationResult(program: nil, remainingCredits: 0, error: error.localizedDescription)
        }
    }
}

// MARK: - Response Models

private struct GenerateProgramResponse: Codable, Sendable {
    let program: Program
    let usage: ProgramUsageInfo
}

private struct ProgramUsageInfo: Codable, Sendable {
    let used: Int
    let limit: Int
    let remaining: Int
}

private struct ProgramErrorResponse: Codable, Sendable {
    let error: String
}
