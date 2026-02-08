import Foundation
import Supabase

class ProgramService {
    static let shared = ProgramService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    /// Offline-first: load from cache, sync in background
    func fetchPrograms() async throws -> [Program] {
        // Return cached immediately if available
        let cached = LocalStorageService.shared.loadPrograms()
        
        if !cached.isEmpty {
            // Have cache - sync in truly detached background task
            Task.detached(priority: .background) {
                if let fresh = try? await self.fetchProgramsFromServer() {
                    LocalStorageService.shared.savePrograms(fresh)
                }
            }
            return cached
        }
        
        // No cache - must fetch from server and wait
        let fresh = try await fetchProgramsFromServer()
        LocalStorageService.shared.savePrograms(fresh)
        return fresh
    }
    
    /// Direct server fetch
    func fetchProgramsFromServer() async throws -> [Program] {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token else {
            throw NSError(domain: "ProgramService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/programs?select=*&order=created_at.desc")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ProgramService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch programs"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Program].self, from: data)
    }
    
    /// Offline-first: save locally, sync in background
    func saveProgram(_ program: Program) async throws {
        // Save locally immediately
        LocalStorageService.shared.saveProgram(program)
        
        // Sync to server in truly detached background
        Task.detached(priority: .background) {
            try? await self.saveProgramToServer(program)
        }
    }
    
    /// Direct server save
    func saveProgramToServer(_ program: Program) async throws {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token,
              let userId = AuthCache.shared.userId else {
            throw NSError(domain: "ProgramService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Build the payload
        let payload: [String: Any] = [
            "program_id": program.programId,
            "program_name": program.programName,
            "user_id": userId,
            "workout_days": program.days.map { day in
                [
                    "dayId": day.dayId,
                    "dayName": day.dayName,
                    "exercises": day.exerciseList.map { ex in
                        [
                            "exerciseId": ex.exerciseId ?? UUID().uuidString,
                            "name": ex.name,
                            "workingSets": ex.sets,
                            "prescribedReps": ex.reps,
                            "restSeconds": ex.rest,
                            "rpe": ex.rpe as Any,
                            "formCues": ex.formCues as Any
                        ]
                    },
                    "warmup": day.warmup.map { w in
                        ["duration": w.duration as Any, "exercises": w.exercises?.map { ["name": $0.name, "duration": $0.duration as Any, "reps": $0.reps as Any] } as Any]
                    } as Any,
                    "cooldown": day.cooldown.map { c in
                        ["duration": c.duration as Any, "exercises": c.exercises?.map { ["name": $0.name, "duration": $0.duration as Any, "reps": $0.reps as Any] } as Any]
                    } as Any
                ]
            },
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        // Upsert - if program exists, update; otherwise insert
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/programs?on_conflict=program_id")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ProgramService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save program"])
        }
    }
    
    /// Offline-first: delete locally, sync in background
    func deleteProgram(_ program: Program) async throws {
        // Delete locally immediately
        LocalStorageService.shared.deleteProgram(program.programId)
        
        // Sync to server in truly detached background
        Task.detached(priority: .background) {
            try? await self.deleteProgramFromServer(program)
        }
    }
    
    /// Direct server delete
    func deleteProgramFromServer(_ program: Program) async throws {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token else {
            throw NSError(domain: "ProgramService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/programs?program_id=eq.\(program.programId)")!)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ProgramService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete program"])
        }
    }
}
