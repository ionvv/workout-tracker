import Foundation
import Combine
import Supabase

/// Thread-safe cache for auth tokens (accessible without MainActor hop)
final class AuthCache: @unchecked Sendable {
    static let shared = AuthCache()
    private let lock = NSLock()
    private var _token: String?
    private var _userId: String?
    
    var token: String? {
        get { lock.withLock { _token } }
        set { lock.withLock { _token = newValue } }
    }
    
    var userId: String? {
        get { lock.withLock { _userId } }
        set { lock.withLock { _userId = newValue } }
    }
    
    func clear() {
        lock.withLock {
            _token = nil
            _userId = nil
        }
    }
}

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let client: SupabaseClient
    private let cache = AuthCache.shared
    
    @Published var isAuthenticated = false
    @Published var isLoading = false  // Start false - show login immediately
    @Published var userEmail: String?
    @Published var userId: String?
    
    private init() {
        print("🔐 AuthService: init started at \(Date())")
        // Disable auto refresh + emit local session immediately
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: false,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        print("🔐 AuthService: SupabaseClient created at \(Date())")
        
        // Check cached session synchronously in init
        if let session = client.auth.currentSession {
            print("🔐 AuthService: Found cached session in init for \(session.user.email ?? "unknown")")
            self.isAuthenticated = true
            self.userEmail = session.user.email
            self.userId = session.user.id.uuidString
            // Update thread-safe cache
            cache.token = session.accessToken
            cache.userId = session.user.id.uuidString
        }
        print("🔐 AuthService: init complete, isAuthenticated=\(isAuthenticated)")
    }
    
    func checkSession() async {
        print("🔐 checkSession: Started at \(Date())")
        
        // First try cached session (instant)
        print("🔐 checkSession: Checking currentSession...")
        let cachedSession = client.auth.currentSession
        print("🔐 checkSession: currentSession = \(cachedSession != nil ? "exists" : "nil") at \(Date())")
        
        if let session = cachedSession {
            print("🔐 checkSession: Got cached session! user=\(session.user.email ?? "no email") at \(Date())")
            print("🔐 checkSession: Setting isAuthenticated = true")
            isAuthenticated = true
            userEmail = session.user.email
            userId = session.user.id.uuidString
            cache.token = session.accessToken
            cache.userId = session.user.id.uuidString
            print("🔐 checkSession: isAuthenticated is now \(isAuthenticated)")
            print("🔐 checkSession: Finished (cached) at \(Date())")
            return
        }
        
        print("🔐 checkSession: No cached session, trying network...")
        
        // No cached session - try network with timeout
        var didComplete = false
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            if !didComplete {
                print("🔐 checkSession: TIMEOUT - showing login")
            }
        }
        
        do {
            let session = try await client.auth.session
            print("🔐 checkSession: Got session from network! user=\(session.user.email ?? "no email") at \(Date())")
            didComplete = true
            isAuthenticated = true
            userEmail = session.user.email
            userId = session.user.id.uuidString
            cache.token = session.accessToken
            cache.userId = session.user.id.uuidString
        } catch {
            print("🔐 checkSession: Error: \(error) at \(Date())")
            didComplete = true
            isAuthenticated = false
            userEmail = nil
            userId = nil
        }
        print("🔐 checkSession: Finished at \(Date())")
    }
    
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        isAuthenticated = true
        userEmail = session.user.email
        userId = session.user.id.uuidString
        cache.token = session.accessToken
        cache.userId = session.user.id.uuidString
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        userEmail = nil
        userId = nil
        cache.clear()
    }
    
    /// Get access token - uses cached session first (fast), falls back to network
    func getAccessToken() async -> String? {
        // Try thread-safe cache first (instant, no actor hop)
        if let token = cache.token {
            return token
        }
        
        // Try cached session (still fast)
        if let session = client.auth.currentSession {
            cache.token = session.accessToken
            return session.accessToken
        }
        
        // Fallback to network if needed
        do {
            let session = try await client.auth.session
            cache.token = session.accessToken
            cache.userId = session.user.id.uuidString
            return session.accessToken
        } catch {
            return nil
        }
    }
}
