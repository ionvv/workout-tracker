import Foundation
import Combine

class ProfileService: ObservableObject {
    static let shared = ProfileService()
    
    @Published var profile: UserProfile
    
    private let profileKey = "userProfile"
    
    private init() {
        // Load profile from UserDefaults
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = UserProfile()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
            print("✅ Profile saved")
        }
    }
    
    func updateWeight(_ weight: Double?) {
        profile.weight = weight
        save()
    }
    
    func updateHeight(_ height: Double?) {
        profile.height = height
        save()
    }
    
    func updateGender(_ gender: UserProfile.Gender?) {
        profile.gender = gender
        save()
    }
    
    func updateBirthDate(_ date: Date?) {
        profile.birthDate = date
        save()
    }
    
    func updateUnitSystem(_ system: UserProfile.UnitSystem) {
        profile.unitSystem = system
        save()
    }
}
