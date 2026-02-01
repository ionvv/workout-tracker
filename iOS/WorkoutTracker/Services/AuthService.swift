import Foundation
import Combine
import Supabase

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = User(
                id: session.user.id,
                email: session.user.email ?? "",
                createdAt: session.user.createdAt
            )
            self.isAuthenticated = true
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        self.currentUser = User(
            id: response.user.id,
            email: response.user.email ?? "",
            createdAt: response.user.createdAt
        )
        self.isAuthenticated = true
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    var userId: UUID? {
        return currentUser?.id
    }
}
