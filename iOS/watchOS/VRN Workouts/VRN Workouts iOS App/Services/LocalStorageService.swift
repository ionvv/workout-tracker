import Foundation

/// Timestamp helper for logging
private func ts() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return "[\(formatter.string(from: Date()))]"
}

/// Offline-first local storage using UserDefaults
class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    // In-memory cache to avoid re-decoding
    private var programsCache: [Program]?
    private var sessionsCache: [WorkoutSession]?
    private let cacheLock = NSLock()
    
    // Keys
    private let programsKey = "cached_programs"
    private let sessionsKey = "cached_sessions"
    private let pendingSyncsKey = "pending_syncs"
    private let lastSyncKey = "last_sync_timestamp"
    
    private init() {
        print("\(ts()) 💾 LocalStorageService: init")
    }
    
    // MARK: - Programs
    
    func savePrograms(_ programs: [Program]) {
        // Update in-memory cache first
        cacheLock.withLock { programsCache = programs }
        
        // Then persist to disk
        if let data = try? encoder.encode(programs) {
            defaults.set(data, forKey: programsKey)
            print("\(ts()) 💾 Cached \(programs.count) programs locally")
        }
    }
    
    func loadPrograms() -> [Program] {
        print("\(ts()) 💾 loadPrograms: start")
        guard let data = defaults.data(forKey: programsKey) else {
            print("\(ts()) 💾 loadPrograms: no data in UserDefaults")
            return []
        }
        print("\(ts()) 💾 loadPrograms: got data, size=\(data.count) bytes")
        
        guard let programs = try? decoder.decode([Program].self, from: data) else {
            print("\(ts()) 💾 loadPrograms: decode failed")
            return []
        }
        print("\(ts()) 💾 loadPrograms: decoded \(programs.count) programs")
        return programs
    }
    
    /// Async version - uses in-memory cache, decodes on background if needed
    func loadProgramsAsync() async -> [Program] {
        print("\(ts()) 💾 loadProgramsAsync: start")
        
        // Check in-memory cache first (instant)
        if let cached = cacheLock.withLock({ programsCache }) {
            print("\(ts()) 💾 loadProgramsAsync: returning \(cached.count) from memory cache")
            return cached
        }
        
        guard let data = defaults.data(forKey: programsKey) else {
            print("\(ts()) 💾 loadProgramsAsync: no data")
            return []
        }
        print("\(ts()) 💾 loadProgramsAsync: got data, size=\(data.count) bytes, decoding...")
        
        // Decode on background thread
        let programs = await Task.detached(priority: .userInitiated) {
            let result = (try? self.decoder.decode([Program].self, from: data)) ?? []
            print("\(ts()) 💾 loadProgramsAsync: decoded \(result.count) programs")
            return result
        }.value
        
        // Cache in memory for next time
        cacheLock.withLock { programsCache = programs }
        
        print("\(ts()) 💾 loadProgramsAsync: done")
        return programs
    }
    
    func saveProgram(_ program: Program) {
        var programs = cacheLock.withLock { programsCache } ?? loadPrograms()
        if let index = programs.firstIndex(where: { $0.programId == program.programId }) {
            programs[index] = program
        } else {
            programs.insert(program, at: 0)
        }
        savePrograms(programs)
    }
    
    func deleteProgram(_ programId: String) {
        var programs = cacheLock.withLock { programsCache } ?? loadPrograms()
        programs.removeAll { $0.programId == programId }
        savePrograms(programs)
    }
    
    // MARK: - Sessions
    
    func saveSessions(_ sessions: [WorkoutSession]) {
        // Update in-memory cache first
        cacheLock.withLock { sessionsCache = sessions }
        
        do {
            let data = try encoder.encode(sessions)
            defaults.set(data, forKey: sessionsKey)
            defaults.synchronize()
            print("\(ts()) 💾 Cached \(sessions.count) sessions locally (\(data.count) bytes)")
        } catch {
            print("\(ts()) ❌ Failed to encode sessions: \(error)")
        }
    }
    
    func loadSessions() -> [WorkoutSession] {
        // Check in-memory cache first
        if let cached = cacheLock.withLock({ sessionsCache }) {
            print("\(ts()) 💾 Loaded \(cached.count) sessions from memory cache")
            return cached
        }
        
        guard let data = defaults.data(forKey: sessionsKey) else {
            print("\(ts()) 💾 No sessions data in UserDefaults")
            return []
        }
        
        print("\(ts()) 💾 Found \(data.count) bytes of session data")
        
        do {
            let sessions = try decoder.decode([WorkoutSession].self, from: data)
            // Cache in memory
            cacheLock.withLock { sessionsCache = sessions }
            print("\(ts()) 💾 Loaded \(sessions.count) sessions from cache")
            return sessions
        } catch {
            print("\(ts()) ❌ Failed to decode sessions: \(error)")
            return []
        }
    }
    
    func addSession(_ session: WorkoutSession) {
        print("\(ts()) 💾 Adding session: \(session.sessionId) - \(session.dayName)")
        print("\(ts()) 💾 Session has \(session.exercises.count) exercises")
        for (i, ex) in session.exercises.enumerated() {
            print("\(ts()) 💾   Exercise \(i): \(ex.exerciseName) with \(ex.sets.count) sets")
        }
        
        var sessions = cacheLock.withLock { sessionsCache } ?? loadSessions()
        print("\(ts()) 💾 Current cache has \(sessions.count) sessions")
        sessions.insert(session, at: 0)
        saveSessions(sessions)
    }
    
    func updateSession(_ session: WorkoutSession) {
        var sessions = cacheLock.withLock { sessionsCache } ?? loadSessions()
        if let index = sessions.firstIndex(where: { $0.sessionId == session.sessionId }) {
            sessions[index] = session
            saveSessions(sessions)
            print("\(ts()) 💾 Updated session \(session.sessionId)")
        }
    }
    
    func deleteSession(_ sessionId: String) {
        var sessions = cacheLock.withLock { sessionsCache } ?? loadSessions()
        sessions.removeAll { $0.sessionId == sessionId }
        saveSessions(sessions)
        print("\(ts()) 💾 Deleted session \(sessionId)")
    }
    
    // MARK: - Pending Syncs
    
    func addPendingSync(_ sync: PendingSync) {
        var pending = loadPendingSyncs()
        pending.append(sync)
        if let data = try? encoder.encode(pending) {
            defaults.set(data, forKey: pendingSyncsKey)
        }
        print("\(ts()) 💾 Added pending sync: \(sync.type)")
    }
    
    func loadPendingSyncs() -> [PendingSync] {
        guard let data = defaults.data(forKey: pendingSyncsKey),
              let syncs = try? decoder.decode([PendingSync].self, from: data) else {
            return []
        }
        return syncs
    }
    
    func removePendingSync(_ syncId: String) {
        var pending = loadPendingSyncs()
        pending.removeAll { $0.id == syncId }
        if let data = try? encoder.encode(pending) {
            defaults.set(data, forKey: pendingSyncsKey)
        }
    }
    
    func clearPendingSyncs() {
        defaults.removeObject(forKey: pendingSyncsKey)
    }
    
    // MARK: - Sync Timestamp
    
    func setLastSync(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastSyncKey)
    }
    
    func getLastSync() -> Date? {
        let timestamp = defaults.double(forKey: lastSyncKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
}

// MARK: - Pending Sync Model

struct PendingSync: Codable, Identifiable {
    let id: String
    let type: SyncType
    let data: Data
    let timestamp: Date
    
    enum SyncType: String, Codable {
        case saveProgram
        case deleteProgram
        case saveSession
    }
    
    init(type: SyncType, data: Data) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}
