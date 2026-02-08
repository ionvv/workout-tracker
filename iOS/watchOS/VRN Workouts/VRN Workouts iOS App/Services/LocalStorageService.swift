import Foundation

/// Offline-first local storage using UserDefaults
class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Keys
    private let programsKey = "cached_programs"
    private let sessionsKey = "cached_sessions"
    private let pendingSyncsKey = "pending_syncs"
    private let lastSyncKey = "last_sync_timestamp"
    
    private init() {}
    
    // MARK: - Programs
    
    func savePrograms(_ programs: [Program]) {
        if let data = try? encoder.encode(programs) {
            defaults.set(data, forKey: programsKey)
            print("💾 Cached \(programs.count) programs locally")
        }
    }
    
    func loadPrograms() -> [Program] {
        guard let data = defaults.data(forKey: programsKey),
              let programs = try? decoder.decode([Program].self, from: data) else {
            return []
        }
        print("💾 Loaded \(programs.count) programs from cache")
        return programs
    }
    
    func saveProgram(_ program: Program) {
        var programs = loadPrograms()
        if let index = programs.firstIndex(where: { $0.programId == program.programId }) {
            programs[index] = program
        } else {
            programs.insert(program, at: 0)
        }
        savePrograms(programs)
    }
    
    func deleteProgram(_ programId: String) {
        var programs = loadPrograms()
        programs.removeAll { $0.programId == programId }
        savePrograms(programs)
    }
    
    // MARK: - Sessions
    
    func saveSessions(_ sessions: [WorkoutSession]) {
        if let data = try? encoder.encode(sessions) {
            defaults.set(data, forKey: sessionsKey)
            print("💾 Cached \(sessions.count) sessions locally")
        }
    }
    
    func loadSessions() -> [WorkoutSession] {
        guard let data = defaults.data(forKey: sessionsKey),
              let sessions = try? decoder.decode([WorkoutSession].self, from: data) else {
            return []
        }
        print("💾 Loaded \(sessions.count) sessions from cache")
        return sessions
    }
    
    func addSession(_ session: WorkoutSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0)
        saveSessions(sessions)
    }
    
    // MARK: - Pending Syncs
    
    func addPendingSync(_ sync: PendingSync) {
        var pending = loadPendingSyncs()
        pending.append(sync)
        if let data = try? encoder.encode(pending) {
            defaults.set(data, forKey: pendingSyncsKey)
        }
        print("💾 Added pending sync: \(sync.type)")
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
