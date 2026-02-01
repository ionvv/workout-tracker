import Foundation
import Combine
import Supabase

class SessionService: ObservableObject {
    static let shared = SessionService()
    
    private let client: SupabaseClient
    @Published var sessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    func saveSession(_ activeSession: ActiveWorkoutSession, notes: String = "") async throws {
        guard AuthService.shared.isAuthenticated else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else {
            throw NSError(domain: "SessionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Device not paired"])
        }
        
        let stats = activeSession.calculateStats()
        let endTime = Date()
        
        // Convert exercises to JSON string for JSONB column
        let exercisesData = try JSONEncoder().encode(activeSession.exercises)
        let exercisesJsonString = String(data: exercisesData, encoding: .utf8) ?? "[]"
        
        // Use raw HTTP call to avoid MainActor isolation issues
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/insert_session_for_device")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "p_device_id": deviceId,
            "p_session_id": activeSession.sessionId,
            "p_program_id": activeSession.programId,
            "p_day_id": activeSession.dayId,
            "p_day_name": activeSession.dayName,
            "p_start_time": ISO8601DateFormatter().string(from: activeSession.startTime),
            "p_end_time": ISO8601DateFormatter().string(from: endTime),
            "p_exercises": exercisesJsonString,
            "p_notes": notes.isEmpty ? NSNull() : notes,
            "p_total_volume": stats.volume,
            "p_total_sets": stats.sets,
            "p_duration": stats.duration
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SessionService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save session"])
        }
    }
    
    func fetchSessions() async {
        guard AuthService.shared.isAuthenticated else {
            self.error = "Not authenticated"
            return
        }
        
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else {
            await MainActor.run {
                self.error = "Device not paired"
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            // Use raw HTTP call to avoid MainActor isolation issues
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/get_sessions_for_device")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let body = ["p_device_id": deviceId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Configure decoder for ISO8601 dates
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let response = try decoder.decode([WorkoutSession].self, from: data)
            
            await MainActor.run {
                self.sessions = response
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                print("Error fetching sessions:", error)
            }
        }
    }
}
