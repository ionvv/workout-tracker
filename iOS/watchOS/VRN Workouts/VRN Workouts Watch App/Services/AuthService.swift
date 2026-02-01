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
        
        // Check for existing session or device authorization
        Task {
            await checkSession()
            await checkDeviceAuthorization()
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
    
    func checkDeviceAuthorization() async {
        // Check if device has been authorized via pairing flow
        guard let authorizedUserId = UserDefaults.standard.string(forKey: "authorizedUserId"),
              let deviceAuthorized = UserDefaults.standard.object(forKey: "deviceAuthorized") as? Bool,
              deviceAuthorized else {
            return
        }
        
        // Device is authorized, create a "virtual" user session
        // In production, you'd want to exchange this for a proper Supabase session
        if let userId = UUID(uuidString: authorizedUserId) {
            self.currentUser = User(
                id: userId,
                email: "watch-user@device",
                createdAt: Date()
            )
            self.isAuthenticated = true
        }
    }
}
