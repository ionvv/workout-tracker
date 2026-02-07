import Foundation
import Combine
import Supabase

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var isLoading = true
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
        isLoading = true
        
        // Race between session check and timeout
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                return false // timeout reached
            }
            
            group.addTask { @MainActor in
                do {
                    let session = try await self.client.auth.session
                    self.isAuthenticated = true
                    self.userEmail = session.user.email
                    self.userId = session.user.id.uuidString
                    return true
                } catch {
                    self.isAuthenticated = false
                    self.userEmail = nil
                    self.userId = nil
                    return true // completed (even if failed)
                }
            }
            
            // Wait for first to complete
            if let _ = await group.next() {
                group.cancelAll()
            }
        }
        
        isLoading = false
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
