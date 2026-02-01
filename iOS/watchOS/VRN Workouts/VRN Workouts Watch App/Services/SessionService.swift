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
        
        // Create properly typed parameters struct
        struct SaveSessionParams: Encodable {
            let p_device_id: String
            let p_session_id: String
            let p_program_id: String
            let p_day_id: String
            let p_day_name: String
            let p_start_time: String
            let p_end_time: String
            let p_exercises: String // JSON string
            let p_notes: String?
            let p_total_volume: Int
            let p_total_sets: Int
            let p_duration: Int
        }
        
        let params = SaveSessionParams(
            p_device_id: deviceId,
            p_session_id: activeSession.sessionId,
            p_program_id: activeSession.programId,
            p_day_id: activeSession.dayId,
            p_day_name: activeSession.dayName,
            p_start_time: ISO8601DateFormatter().string(from: activeSession.startTime),
            p_end_time: ISO8601DateFormatter().string(from: endTime),
            p_exercises: exercisesJsonString,
            p_notes: notes.isEmpty ? nil : notes,
            p_total_volume: stats.volume,
            p_total_sets: stats.sets,
            p_duration: stats.duration
        )
        
        let _: UUID = try await client.rpc(
            "insert_session_for_device",
            params: params
        ).execute().value
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
            // Use RPC function to fetch sessions for this device
            struct GetSessionsParams: Encodable {
                let p_device_id: String
            }
            
            let response: [WorkoutSession] = try await client.rpc(
                "get_sessions_for_device",
                params: GetSessionsParams(p_device_id: deviceId)
            ).execute().value
            
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
