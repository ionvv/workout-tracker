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
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        // Quick check - don't block UI
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            userEmail = session.user.email
            userId = session.user.id.uuidString
        } catch {
            isAuthenticated = false
            userEmail = nil
            userId = nil
        }
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
