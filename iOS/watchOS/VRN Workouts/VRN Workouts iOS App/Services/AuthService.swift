import Foundation
import Combine

/// Timestamp helper
private let tsFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()
private func ts() -> String { "[\(tsFormatter.string(from: Date()))]" }

/// Thread-safe cache for auth tokens
final class AuthCache: @unchecked Sendable {
    static let shared = AuthCache()
    private let lock = NSLock()
    private var _token: String?
    private var _userId: String?
    private var _refreshToken: String?
    
    var token: String? {
        get { lock.withLock { _token } }
        set { lock.withLock { _token = newValue } }
    }
    
    var userId: String? {
        get { lock.withLock { _userId } }
        set { lock.withLock { _userId = newValue } }
    }
    
    var refreshToken: String? {
        get { lock.withLock { _refreshToken } }
        set { lock.withLock { _refreshToken = newValue } }
    }
    
    func clear() {
        lock.withLock {
            _token = nil
            _userId = nil
            _refreshToken = nil
        }
    }
}

/// Lightweight auth service using direct REST calls (no Supabase SDK)
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let cache = AuthCache.shared
    private let keychainKey = "supabase_session"
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var userEmail: String?
    @Published var userId: String?
    
    private init() {
        print("\(ts()) 🔐 AuthService: init started")
        loadCachedSession()
        print("\(ts()) 🔐 AuthService: init complete, isAuthenticated=\(isAuthenticated)")
    }
    
    // MARK: - Session Persistence
    
    private func loadCachedSession() {
        print("\(ts()) 🔐 Loading cached session...")
        guard let data = UserDefaults.standard.data(forKey: keychainKey),
              let session = try? JSONDecoder().decode(StoredSession.self, from: data) else {
            print("\(ts()) 🔐 No cached session found")
            return
        }
        
        // Check if token is expired
        if session.expiresAt > Date() {
            print("\(ts()) 🔐 Found valid cached session for \(session.email ?? "unknown")")
            applySession(session)
        } else if session.refreshToken != nil {
            print("\(ts()) 🔐 Token expired, will refresh on next API call")
            // Still load it - we'll refresh when needed
            applySession(session)
        } else {
            print("\(ts()) 🔐 Cached session expired and no refresh token")
        }
    }
    
    private func applySession(_ session: StoredSession) {
        isAuthenticated = true
        userEmail = session.email
        userId = session.userId
        cache.token = session.accessToken
        cache.userId = session.userId
        cache.refreshToken = session.refreshToken
    }
    
    private func saveSession(_ session: StoredSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: keychainKey)
        }
        applySession(session)
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: keychainKey)
        isAuthenticated = false
        userEmail = nil
        userId = nil
        cache.clear()
    }
    
    // MARK: - Auth API
    
    func signIn(email: String, password: String) async throws {
        print("\(ts()) 🔐 Signing in...")
        
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode == 400 {
            throw AuthError.invalidCredentials
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.serverError(httpResponse.statusCode)
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        let session = StoredSession(
            accessToken: authResponse.access_token,
            refreshToken: authResponse.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(authResponse.expires_in)),
            userId: authResponse.user.id,
            email: authResponse.user.email
        )
        
        saveSession(session)
        print("\(ts()) 🔐 Sign in successful")
    }
    
    func signOut() async throws {
        print("\(ts()) 🔐 Signing out...")
        
        // Try to invalidate token on server (best effort)
        if let token = cache.token {
            var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/auth/v1/logout")!)
            request.httpMethod = "POST"
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        
        clearSession()
        print("\(ts()) 🔐 Signed out")
    }
    
    /// Get current access token
    func getAccessToken() async -> String? {
        // Refresh if needed first
        _ = await refreshTokenIfNeeded()
        return AuthCache.shared.token
    }
    
    /// Get current user ID
    func getCurrentUserId() async -> String? {
        return userId
    }
    
    func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = cache.refreshToken else { return false }
        
        print("\(ts()) 🔐 Refreshing token...")
        
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("\(ts()) 🔐 Token refresh failed")
                return false
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            let session = StoredSession(
                accessToken: authResponse.access_token,
                refreshToken: authResponse.refresh_token,
                expiresAt: Date().addingTimeInterval(TimeInterval(authResponse.expires_in)),
                userId: authResponse.user.id,
                email: authResponse.user.email
            )
            
            saveSession(session)
            print("\(ts()) 🔐 Token refreshed")
            return true
        } catch {
            print("\(ts()) 🔐 Token refresh error: \(error)")
            return false
        }
    }
}

// MARK: - Models

private struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let userId: String
    let email: String?
}

private struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let user: AuthUser
}

private struct AuthUser: Codable {
    let id: String
    let email: String?
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password"
        case .networkError: return "Network error"
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}
