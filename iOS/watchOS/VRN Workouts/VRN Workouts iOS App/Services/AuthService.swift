import Foundation
import Combine
import Supabase

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var isLoading = false  // Start false - show login immediately
    @Published var userEmail: String?
    @Published var userId: String?
    
    private init() {
        print("🔐 AuthService: init started at \(Date())")
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true
                )
            )
        )
        print("🔐 AuthService: SupabaseClient created at \(Date())")
        
        Task {
            print("🔐 AuthService: Starting checkSession task at \(Date())")
            await checkSession()
            print("🔐 AuthService: checkSession completed at \(Date())")
        }
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
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        userEmail = nil
        userId = nil
    }
    
    func getAccessToken() async -> String? {
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }
}
