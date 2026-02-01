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
    
    nonisolated func fetchPrograms() async {
        guard await AuthService.shared.isAuthenticated else {
            await MainActor.run {
                self.error = "Not authenticated"
            }
            return
        }
        
        // Get device ID
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else {
            await MainActor.run {
                self.error = "Device not paired"
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            // Use RPC function to fetch programs for this device
            let response: [Program] = try await client.rpc(
                "get_programs_for_device",
                params: GetProgramsParams(p_device_id: deviceId)
            ).execute().value
            
            await MainActor.run {
                self.programs = response
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                print("Error fetching programs:", error)
            }
        }
    }
}
