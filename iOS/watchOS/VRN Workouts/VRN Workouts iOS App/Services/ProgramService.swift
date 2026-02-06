import Foundation
import Supabase

class ProgramService {
    static let shared = ProgramService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    func fetchPrograms() async throws -> [Program] {
        guard await AuthService.shared.isAuthenticated else {
            throw NSError(domain: "ProgramService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let token = await AuthService.shared.getAccessToken() else {
            throw NSError(domain: "ProgramService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/programs?select=*&order=created_at.desc")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ProgramService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch programs"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Program].self, from: data)
    }
}
