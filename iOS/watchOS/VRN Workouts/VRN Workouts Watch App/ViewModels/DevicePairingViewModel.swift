import SwiftUI
import Foundation
import Combine

@MainActor
class DevicePairingViewModel: ObservableObject {
    @Published var pairingCode: String?
    @Published var isLoading = false
    @Published var isPolling = false
    @Published var errorMessage: String?
    @Published var timeRemaining: String?
    
    private var deviceId: String
    private var codeExpiresAt: Date?
    private var pollingTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    
    init() {
        // Get or create device ID (stored in UserDefaults)
        if let savedDeviceId = UserDefaults.standard.string(forKey: "deviceId") {
            self.deviceId = savedDeviceId
        } else {
            let newDeviceId = UUID().uuidString
            UserDefaults.standard.set(newDeviceId, forKey: "deviceId")
            self.deviceId = newDeviceId
        }
    }
    
    func startPairingFlow() async {
        await requestNewCode()
    }
    
    func requestNewCode() async {
        isLoading = true
        errorMessage = nil
        pairingCode = nil
        stopPolling()
        
        do {
            let response = try await DevicePairingService.requestPairingCode(deviceId: deviceId)
            
            pairingCode = response.code
            codeExpiresAt = response.expiresAt
            
            // Start polling for authorization
            startPolling()
            
            // Start countdown timer
            startTimer()
            
        } catch {
            errorMessage = "Failed to generate code. Check internet connection."
            print("Error requesting pairing code:", error)
        }
        
        isLoading = false
    }
    
    private func startPolling() {
        isPolling = true
        
        pollingTask = Task {
            while !Task.isCancelled {
                // Check authorization status
                do {
                    let result = try await DevicePairingService.checkAuthorization(deviceId: deviceId)
                    
                    if result.authorized {
                        // Success! Device is authorized
                        await handleSuccessfulPairing(userId: result.userId)
                        break
                    }
                } catch {
                    print("Polling error:", error)
                }
                
                // Wait 3 seconds before next poll
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            
            isPolling = false
        }
    }
    
    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled, let expiresAt = codeExpiresAt {
                let remaining = expiresAt.timeIntervalSinceNow
                
                if remaining <= 0 {
                    // Code expired
                    timeRemaining = "Expired"
                    stopPolling()
                    errorMessage = "Code expired. Request a new one."
                    break
                }
                
                // Format as MM:SS
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                timeRemaining = String(format: "%d:%02d", minutes, seconds)
                
                // Update every second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        timerTask?.cancel()
        isPolling = false
    }
    
    private func handleSuccessfulPairing(userId: String?) async {
        // Device has been authorized!
        print("✅ Device paired successfully! User ID:", userId ?? "unknown")
        
        stopPolling()
        
        // Notify user with haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Store device as authorized
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: "authorizedUserId")
            UserDefaults.standard.set(true, forKey: "deviceAuthorized")
            
            // Update AuthService to trigger UI transition
            // Note: AuthService needs to check UserDefaults for device authorization
            await AuthService.shared.checkDeviceAuthorization()
        }
    }
}

// Service for API calls
struct DevicePairingService {
    static let baseURL = Config.supabaseURL
    
    struct PairingCodeResponse: Codable {
        let code: String
        let expiresAt: Date
        
        enum CodingKeys: String, CodingKey {
            case code
            case expiresAt = "expires_at"
        }
    }
    
    struct AuthorizationResponse: Codable {
        let authorized: Bool
        let userId: String?
        
        enum CodingKeys: String, CodingKey {
            case authorized
            case userId = "user_id"
        }
    }
    
    static func requestPairingCode(deviceId: String) async throws -> PairingCodeResponse {
        let url = URL(string: "\(baseURL)/rest/v1/rpc/request_pairing_code")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["device_id": deviceId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PairingCodeResponse.self, from: data)
    }
    
    static func checkAuthorization(deviceId: String) async throws -> AuthorizationResponse {
        let url = URL(string: "\(baseURL)/rest/v1/rpc/check_device_authorization")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["device_id": deviceId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(AuthorizationResponse.self, from: data)
    }
}
