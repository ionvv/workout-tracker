import Foundation
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
            await MainActor.run { self.error = "Not authenticated" }
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            // Fetch raw data first to debug
            let response = try await client.database
                .from("programs")
                .select()
                .order("created_at", ascending: false)
                .execute()
            
            print("📱 [ProgramService] Raw response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Try to decode
            let decoder = JSONDecoder()
            let programs = try decoder.decode([Program].self, from: response.data)
            
            print("📱 [ProgramService] Decoded \(programs.count) programs")
            
            await MainActor.run {
                self.programs = programs
                self.isLoading = false
                self.error = nil
            }
        } catch let decodingError as DecodingError {
            print("📱 [ProgramService] Decoding error: \(decodingError)")
            await MainActor.run {
                self.error = "Data format error: \(decodingError.localizedDescription)"
                self.isLoading = false
            }
        } catch {
            print("📱 [ProgramService] Fetch error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
