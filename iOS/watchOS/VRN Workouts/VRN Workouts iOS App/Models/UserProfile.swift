import Foundation

struct UserProfile: Codable {
    var weight: Double?      // kg
    var height: Double?      // cm
    var birthDate: Date?
    var gender: Gender?
    var unitSystem: UnitSystem
    
    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .other: return "Other"
            }
        }
    }
    
    enum UnitSystem: String, Codable, CaseIterable {
        case metric = "metric"
        case imperial = "imperial"
        
        var displayName: String {
            switch self {
            case .metric: return "Metric (kg, cm)"
            case .imperial: return "Imperial (lb, ft)"
            }
        }
        
        var weightUnit: String {
            switch self {
            case .metric: return "kg"
            case .imperial: return "lb"
            }
        }
        
        var heightUnit: String {
            switch self {
            case .metric: return "cm"
            case .imperial: return "ft/in"
            }
        }
    }
    
    init(weight: Double? = nil, height: Double? = nil, birthDate: Date? = nil, gender: Gender? = nil, unitSystem: UnitSystem = .metric) {
        self.weight = weight
        self.height = height
        self.birthDate = birthDate
        self.gender = gender
        self.unitSystem = unitSystem
    }
    
    // MARK: - Computed Properties
    
    var bmi: Double? {
        guard let weight = weight, let height = height, height > 0 else { return nil }
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
    
    var bmiCategory: String? {
        guard let bmi = bmi else { return nil }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
    }
    
    // MARK: - Unit Conversion
    
    var weightInDisplayUnit: Double? {
        guard let weight = weight else { return nil }
        return unitSystem == .imperial ? weight * 2.20462 : weight
    }
    
    var heightInDisplayUnit: Double? {
        guard let height = height else { return nil }
        return unitSystem == .imperial ? height / 2.54 : height
    }
    
    func weightFromDisplayUnit(_ value: Double) -> Double {
        return unitSystem == .imperial ? value / 2.20462 : value
    }
    
    func heightFromDisplayUnit(_ value: Double) -> Double {
        return unitSystem == .imperial ? value * 2.54 : value
    }
}
