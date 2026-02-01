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
        print("🔍 fetchPrograms called")
        
        guard AuthService.shared.isAuthenticated else {
            print("❌ Not authenticated")
            self.error = "Not authenticated"
            return
        }
        
        print("✅ Authenticated")
        
        // Get device ID
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else {
            print("❌ No device ID found")
            await MainActor.run {
                self.error = "Device not paired"
                self.isLoading = false
            }
            return
        }
        
        print("✅ Device ID:", deviceId)
        
        await MainActor.run { self.isLoading = true }
        
        do {
            // Use raw HTTP call to avoid MainActor isolation issues
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/get_programs_for_device")!
            print("📡 Calling:", url.absoluteString)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let body = ["p_device_id": deviceId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("📤 Request body:", body)
            
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            
            if let response = httpResponse as? HTTPURLResponse {
                print("📥 Response status:", response.statusCode)
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response data:", responseString)
            }
            
            let response = try JSONDecoder().decode([Program].self, from: data)
            
            print("✅ Decoded \(response.count) programs")
            
            await MainActor.run {
                self.programs = response
                self.isLoading = false
                self.error = nil
            }
        } catch {
            print("❌ Error:", error)
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
