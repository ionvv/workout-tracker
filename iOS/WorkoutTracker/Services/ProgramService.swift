import Foundation
import Combine
import Supabase

class ProgramService: ObservableObject {
    static let shared = ProgramService()
    
    private let client: SupabaseClient
    @Published var programs: [Program] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    func fetchPrograms() async {
        guard AuthService.shared.isAuthenticated else {
            self.error = "Not authenticated"
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let response: [Program] = try await client.database
                .from("programs")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.programs = response
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
