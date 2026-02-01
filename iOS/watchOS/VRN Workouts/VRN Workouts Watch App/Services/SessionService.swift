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
        guard let userId = AuthService.shared.userId else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let stats = activeSession.calculateStats()
        
        let session = WorkoutSession(
            id: UUID(),
            userId: userId,
            sessionId: activeSession.sessionId,
            programId: activeSession.programId,
            dayId: activeSession.dayId,
            dayName: activeSession.dayName,
            startTime: activeSession.startTime,
            endTime: Date(),
            exercises: activeSession.exercises,
            notes: notes.isEmpty ? nil : notes,
            totalVolume: stats.volume,
            totalSets: stats.sets,
            duration: stats.duration,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await client.database
            .from("sessions")
            .insert(session)
            .execute()
    }
    
    func fetchSessions() async {
        guard AuthService.shared.isAuthenticated else {
            self.error = "Not authenticated"
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let response: [WorkoutSession] = try await client.database
                .from("sessions")
                .select()
                .order("start_time", ascending: false)
                .limit(50)
                .execute()
                .value
            
            await MainActor.run {
                self.sessions = response
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
