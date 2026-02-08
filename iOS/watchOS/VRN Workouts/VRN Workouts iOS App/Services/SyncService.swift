import Foundation
import Combine

/// Timestamp helper for logging (cached formatter)
private let tsFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

private func ts() -> String {
    return "[\(tsFormatter.string(from: Date()))]"
}

/// Handles background sync between local storage and server
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var pendingSyncCount = 0
    
    private let localStorage = LocalStorageService.shared
    private var syncTask: Task<Void, Never>?
    
    private init() {
        updatePendingCount()
    }
    
    // MARK: - Public Methods
    
    /// Sync all data in background
    func syncAll() {
        guard !isSyncing else { return }
        
        syncTask = Task {
            isSyncing = true
            lastSyncError = nil
            
            // Process pending syncs first
            await processPendingSyncs()
            
            // Then fetch latest from server
            await fetchLatestData()
            
            isSyncing = false
            localStorage.setLastSync(Date())
        }
    }
    
    /// Cancel ongoing sync
    func cancelSync() {
        syncTask?.cancel()
        isSyncing = false
    }
    
    // MARK: - Programs (Offline-First)
    
    /// Load programs - returns cache immediately, syncs in background
    func loadPrograms() async -> [Program] {
        // Return cached data immediately
        let cached = localStorage.loadPrograms()
        
        // Sync in background (don't await)
        Task {
            await fetchProgramsFromServer()
        }
        
        return cached
    }
    
    /// Save program - saves locally, syncs in background
    func saveProgram(_ program: Program) async {
        // Save locally immediately
        localStorage.saveProgram(program)
        
        // Queue for sync
        if let data = try? JSONEncoder().encode(program) {
            let sync = PendingSync(type: .saveProgram, data: data)
            localStorage.addPendingSync(sync)
            updatePendingCount()
        }
        
        // Try to sync immediately in background
        Task {
            await syncProgramToServer(program)
        }
    }
    
    /// Delete program - deletes locally, syncs in background
    func deleteProgram(_ program: Program) async {
        // Delete locally immediately
        localStorage.deleteProgram(program.programId)
        
        // Queue for sync
        if let data = program.programId.data(using: .utf8) {
            let sync = PendingSync(type: .deleteProgram, data: data)
            localStorage.addPendingSync(sync)
            updatePendingCount()
        }
        
        // Try to sync immediately in background
        Task {
            await deleteProgramFromServer(program)
        }
    }
    
    // MARK: - Sessions (Offline-First)
    
    /// Load sessions - returns cache immediately, syncs in background
    func loadSessions() async -> [WorkoutSession] {
        let cached = localStorage.loadSessions()
        
        Task {
            await fetchSessionsFromServer()
        }
        
        return cached
    }
    
    /// Save session - saves locally, syncs in background
    func saveSession(_ session: WorkoutSession) async {
        // Save locally immediately
        localStorage.addSession(session)
        
        // Queue for sync
        if let data = try? JSONEncoder().encode(session) {
            let sync = PendingSync(type: .saveSession, data: data)
            localStorage.addPendingSync(sync)
            updatePendingCount()
        }
        
        // Try to sync immediately in background
        Task {
            await syncSessionToServer(session)
        }
    }
    
    // MARK: - Private Sync Methods
    
    private func fetchLatestData() async {
        await fetchProgramsFromServer()
        await fetchSessionsFromServer()
    }
    
    private func fetchProgramsFromServer() async {
        do {
            let programs = try await ProgramService.shared.fetchProgramsFromServer()
            localStorage.savePrograms(programs)
            print("\(ts()) ✅ Synced \(programs.count) programs from server")
        } catch {
            print("\(ts()) ⚠️ Failed to fetch programs: \(error.localizedDescription)")
        }
    }
    
    private func fetchSessionsFromServer() async {
        do {
            let sessions = try await SessionService.shared.fetchSessionsFromServer()
            localStorage.saveSessions(sessions)
            print("\(ts()) ✅ Synced \(sessions.count) sessions from server")
        } catch {
            print("\(ts()) ⚠️ Failed to fetch sessions: \(error.localizedDescription)")
        }
    }
    
    private func syncProgramToServer(_ program: Program) async {
        do {
            try await ProgramService.shared.saveProgramToServer(program)
            removePendingSync(for: program.programId, type: .saveProgram)
            print("\(ts()) ✅ Program synced to server")
        } catch {
            print("\(ts()) ⚠️ Failed to sync program: \(error.localizedDescription)")
            // Will retry on next sync
        }
    }
    
    private func deleteProgramFromServer(_ program: Program) async {
        do {
            try await ProgramService.shared.deleteProgramFromServer(program)
            removePendingSync(for: program.programId, type: .deleteProgram)
            print("\(ts()) ✅ Program deletion synced")
        } catch {
            print("\(ts()) ⚠️ Failed to delete program from server: \(error.localizedDescription)")
        }
    }
    
    private func syncSessionToServer(_ session: WorkoutSession) async {
        do {
            try await SessionService.shared.saveSessionToServer(session)
            removePendingSync(for: session.sessionId, type: .saveSession)
            print("\(ts()) ✅ Session synced to server")
        } catch {
            print("\(ts()) ⚠️ Failed to sync session: \(error.localizedDescription)")
        }
    }
    
    private func processPendingSyncs() async {
        let pending = localStorage.loadPendingSyncs()
        
        for sync in pending {
            switch sync.type {
            case .saveProgram:
                if let program = try? JSONDecoder().decode(Program.self, from: sync.data) {
                    await syncProgramToServer(program)
                }
            case .deleteProgram:
                if let programId = String(data: sync.data, encoding: .utf8) {
                    let program = Program(dbId: nil, userId: nil, programId: programId, programName: "", workoutDays: nil, createdAt: nil, updatedAt: nil)
                    await deleteProgramFromServer(program)
                }
            case .saveSession:
                if let session = try? JSONDecoder().decode(WorkoutSession.self, from: sync.data) {
                    await syncSessionToServer(session)
                }
            }
        }
        
        updatePendingCount()
    }
    
    private func removePendingSync(for id: String, type: PendingSync.SyncType) {
        let pending = localStorage.loadPendingSyncs()
        for sync in pending where sync.type == type {
            if type == .saveProgram || type == .deleteProgram {
                if let program = try? JSONDecoder().decode(Program.self, from: sync.data),
                   program.programId == id {
                    localStorage.removePendingSync(sync.id)
                }
            } else if type == .saveSession {
                if let session = try? JSONDecoder().decode(WorkoutSession.self, from: sync.data),
                   session.sessionId == id {
                    localStorage.removePendingSync(sync.id)
                }
            }
        }
        updatePendingCount()
    }
    
    private func updatePendingCount() {
        pendingSyncCount = localStorage.loadPendingSyncs().count
    }
}
