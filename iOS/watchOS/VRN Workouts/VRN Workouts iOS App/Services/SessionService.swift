import Foundation
import HealthKit

/// Timestamp helper for logging
private func ts() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return "[\(formatter.string(from: Date()))]"
}

class SessionService {
    static let shared = SessionService()
    
    private init() {
        print("\(ts()) 📋 SessionService: init")
    }
    
    /// Offline-first: load from cache, sync in background
    func fetchSessions() async throws -> [WorkoutSession] {
        // Return cached immediately if available
        let cached = LocalStorageService.shared.loadSessions()
        
        if !cached.isEmpty {
            // Have cache - sync in truly detached background
            Task.detached(priority: .background) {
                if let serverSessions = try? await self.fetchSessionsFromServer() {
                    // MERGE instead of replace - keep local sessions not yet on server
                    let localSessions = LocalStorageService.shared.loadSessions()
                    let serverIds = Set(serverSessions.map { $0.sessionId })
                    
                    // Find local sessions that aren't on server yet
                    let localOnly = localSessions.filter { !serverIds.contains($0.sessionId) }
                    
                    if !localOnly.isEmpty {
                        print("\(ts()) 📋 Keeping \(localOnly.count) local-only sessions during merge")
                    }
                    
                    // Merge: server sessions + local-only sessions, sorted by date
                    var merged = serverSessions + localOnly
                    merged.sort { $0.startTime > $1.startTime }
                    
                    LocalStorageService.shared.saveSessions(merged)
                }
            }
            return cached
        }
        
        // No cache - must fetch from server and wait
        let fresh = try await fetchSessionsFromServer()
        LocalStorageService.shared.saveSessions(fresh)
        return fresh
    }
    
    /// Direct server fetch
    func fetchSessionsFromServer() async throws -> [WorkoutSession] {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
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
    
    /// Offline-first: save locally, sync in background
    func saveSession(_ session: ActiveWorkoutSession) async throws {
        print("\(ts()) 📋 SessionService.saveSession() called")
        print("\(ts()) 📋 Session ID: \(session.sessionId)")
        print("\(ts()) 📋 Day: \(session.dayName)")
        print("\(ts()) 📋 Exercises: \(session.exercises.count)")
        
        // Convert to WorkoutSession for local storage
        let stats = session.calculateStats()
        // Use custom duration if user set it, otherwise use calculated
        let finalDuration = session.customDurationMinutes ?? stats.duration
        print("\(ts()) 📋 Stats - volume: \(stats.volume), sets: \(stats.sets), duration: \(finalDuration) (custom: \(session.customDurationMinutes != nil))")
        let workoutSession = WorkoutSession(
            dbId: UUID(),
            odid: nil,
            userId: UUID(uuidString: AuthService.shared.userId ?? ""),
            sessionId: session.sessionId,
            programId: session.programId,
            dayId: session.dayId,
            dayName: session.dayName,
            startTime: session.startTime,
            endTime: Date(),
            exercises: session.exercises,
            notes: nil,
            totalVolume: stats.volume,
            totalSets: stats.sets,
            duration: finalDuration,
            bodyWeight: session.bodyWeight,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save locally immediately
        LocalStorageService.shared.addSession(workoutSession)
        
        // Sync to server in truly detached background
        Task.detached(priority: .background) {
            try? await self.saveSessionToServer(session)
        }
    }
    
    /// Direct server save
    func saveSessionToServer(_ session: ActiveWorkoutSession) async throws {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token,
              let userId = AuthCache.shared.userId else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let stats = session.calculateStats()
        let endTime = Date()
        let finalDuration = session.customDurationMinutes ?? stats.duration
        
        // Prepare the session data
        var sessionData: [String: Any] = [
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
            "duration": finalDuration
        ]
        
        // Add body weight if logged
        if let bodyWeight = session.bodyWeight {
            sessionData["body_weight"] = bodyWeight
        }
        
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
    
    /// Direct server save from WorkoutSession (for sync)
    func saveSessionToServer(_ session: WorkoutSession) async throws {
        // Use thread-safe cache (no main thread hop)
        guard let token = AuthCache.shared.token,
              let userId = AuthCache.shared.userId else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var sessionData: [String: Any] = [
            "user_id": userId,
            "session_id": session.sessionId,
            "program_id": session.programId as Any,
            "day_id": session.dayId as Any,
            "day_name": session.dayName,
            "start_time": ISO8601DateFormatter().string(from: session.startTime),
            "end_time": session.endTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "exercises": session.exercises.map { exercise in
                [
                    "exerciseId": exercise.exerciseId,
                    "exerciseName": exercise.exerciseName,
                    "prescribedSets": exercise.prescribedSets as Any,
                    "prescribedReps": exercise.prescribedReps as Any,
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
            "total_volume": session.totalVolume as Any,
            "total_sets": session.totalSets as Any,
            "duration": session.duration as Any
        ]
        
        if let bodyWeight = session.bodyWeight {
            sessionData["body_weight"] = bodyWeight
        }
        
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
    
    /// Update an existing session on the server
    func updateSessionOnServer(_ session: WorkoutSession) async throws {
        guard let token = AuthCache.shared.token else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var sessionData: [String: Any] = [
            "exercises": session.exercises.map { exercise in
                [
                    "exerciseId": exercise.exerciseId,
                    "exerciseName": exercise.exerciseName,
                    "prescribedSets": exercise.prescribedSets as Any,
                    "prescribedReps": exercise.prescribedReps as Any,
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
            "notes": session.notes as Any,
            "total_volume": session.totalVolume as Any,
            "total_sets": session.totalSets as Any,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let bodyWeight = session.bodyWeight {
            sessionData["body_weight"] = bodyWeight
        }
        
        // Use PATCH to update existing session
        let urlString = "\(Config.supabaseURL)/rest/v1/sessions?session_id=eq.\(session.sessionId)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "SessionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: sessionData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("SessionService: Update failed with status \(statusCode)")
            throw NSError(domain: "SessionService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update session"])
        }
        
        print("SessionService: Session updated successfully")
    }
    
    // MARK: - Delete
    
    /// Delete session from server
    func deleteSessionFromServer(_ sessionId: String) async throws {
        guard let token = AuthCache.shared.token else {
            throw NSError(domain: "SessionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let urlString = "\(Config.supabaseURL)/rest/v1/sessions?session_id=eq.\(sessionId)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "SessionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("SessionService: Delete failed with status \(statusCode)")
            throw NSError(domain: "SessionService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete session"])
        }
        
        print("SessionService: Session deleted from server")
    }
    
    /// Delete matching workout from HealthKit
    func deleteFromHealthKit(session: WorkoutSession) async {
        let healthStore = HKHealthStore()
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit: Not available")
            return
        }
        
        // Query for workouts matching this session's time range
        let workoutType = HKObjectType.workoutType()
        
        // Find workouts within a few minutes of session start time
        let startDate = session.startTime.addingTimeInterval(-60) // 1 min buffer
        let endDate = session.startTime.addingTimeInterval(60)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: predicate,
                    limit: 10,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples as? [HKWorkout] ?? [])
                    }
                }
                healthStore.execute(query)
            }
            
            // Find strength training workout matching our session
            for workout in workouts {
                if workout.workoutActivityType == .traditionalStrengthTraining {
                    try await healthStore.delete(workout)
                    print("HealthKit: Deleted workout from \(workout.startDate)")
                    return
                }
            }
            
            print("HealthKit: No matching workout found to delete")
        } catch {
            print("HealthKit: Failed to delete workout - \(error)")
        }
    }
}
