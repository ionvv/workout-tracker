import Foundation
import Supabase

class SessionService {
    static let shared = SessionService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    func fetchSessions() async throws -> [WorkoutSession] {
        guard await AuthService.shared.isAuthenticated else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let token = await AuthService.shared.getAccessToken() else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/sessions?select=*&order=start_time.desc&limit=50")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("SessionService: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NSError(domain: "SessionService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch sessions"])
        }
        
        // Debug: print raw JSON
        if let jsonString = String(data: data, encoding: .utf8) {
            print("SessionService: Raw JSON: \(jsonString.prefix(500))...")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let sessions = try decoder.decode([WorkoutSession].self, from: data)
            print("SessionService: Decoded \(sessions.count) sessions")
            return sessions
        } catch {
            print("SessionService: Decode error: \(error)")
            throw error
        }
    }
    
    func saveSession(_ session: ActiveWorkoutSession) async throws {
        guard await AuthService.shared.isAuthenticated else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.userId else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let stats = session.calculateStats()
        let endTime = Date()
        
        // Prepare the session data
        let sessionData: [String: Any] = [
            "user_id": userId,
            "session_id": session.sessionId,
            "program_id": session.programId,
            "day_id": session.dayId,
            "day_name": session.dayName,
            "start_time": ISO8601DateFormatter().string(from: session.startTime),
            "end_time": ISO8601DateFormatter().string(from: endTime),
            "exercises": session.exercises.map { exercise in
                [
                    "exerciseId": exercise.exerciseId,
                    "exerciseName": exercise.exerciseName,
                    "prescribedSets": exercise.prescribedSets,
                    "prescribedReps": exercise.prescribedReps,
                    "skipped": exercise.skipped,
                    "sets": exercise.sets.map { set in
                        [
                            "setNumber": set.setNumber,
                            "weight": set.weight,
                            "reps": set.reps,
                            "timestamp": ISO8601DateFormatter().string(from: set.timestamp),
                            "rpe": set.rpe as Any
                        ]
                    }
                ]
            },
            "total_volume": stats.volume,
            "total_sets": stats.sets,
            "duration": stats.duration
        ]
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/sessions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: sessionData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SessionService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save session"])
        }
    }
}
