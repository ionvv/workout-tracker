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
            supabaseKey: Config.supabaseAnonKey
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
        
        // Try to get session with 2 second timeout
        var didComplete = false
        
        Task {
            print("🔐 checkSession: Timeout task started")
            try? await Task.sleep(for: .seconds(2))
            print("🔐 checkSession: Timeout reached, didComplete=\(didComplete)")
            if !didComplete {
                await MainActor.run {
                    print("🔐 checkSession: TIMEOUT - showing login")
                    self.isAuthenticated = false
                }
            }
        }
        
        print("🔐 checkSession: Calling client.auth.session...")
        do {
            let session = try await client.auth.session
            print("🔐 checkSession: Got session! user=\(session.user.email ?? "no email") at \(Date())")
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
