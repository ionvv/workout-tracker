import SwiftUI

struct ProfileEditView: View {
    @StateObject private var profileService = ProfileService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var selectedGender: UserProfile.Gender?
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate: Bool = false
    
    var body: some View {
        Form {
            Section("Body Measurements") {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(profileService.profile.unitSystem.weightUnit)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("0", text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(profileService.profile.unitSystem.heightUnit)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Personal Info") {
                Picker("Gender", selection: $selectedGender) {
                    Text("Not specified").tag(nil as UserProfile.Gender?)
                    ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                        Text(gender.displayName).tag(gender as UserProfile.Gender?)
                    }
                }
                
                Toggle("Birth Date", isOn: $hasBirthDate)
                
                if hasBirthDate {
                    DatePicker("Date", selection: $birthDate, displayedComponents: .date)
                }
            }
            
            if let bmi = calculateBMI(), let category = bmiCategory(bmi) {
                Section("Stats") {
                    HStack {
                        Text("BMI")
                        Spacer()
                        Text(String(format: "%.1f", bmi))
                            .fontWeight(.semibold)
                        Text("(\(category))")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let age = calculateAge() {
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(age) years")
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveProfile()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        let profile = profileService.profile
        
        if let weight = profile.weightInDisplayUnit {
            weightText = String(format: "%.1f", weight)
        }
        
        if let height = profile.heightInDisplayUnit {
            heightText = String(format: "%.0f", height)
        }
        
        selectedGender = profile.gender
        
        if let date = profile.birthDate {
            birthDate = date
            hasBirthDate = true
        }
    }
    
    private func saveProfile() {
        // Convert from display units to storage units (metric)
        if let weight = Double(weightText), weight > 0 {
            let weightInKg = profileService.profile.weightFromDisplayUnit(weight)
            profileService.updateWeight(weightInKg)
        } else {
            profileService.updateWeight(nil)
        }
        
        if let height = Double(heightText), height > 0 {
            let heightInCm = profileService.profile.heightFromDisplayUnit(height)
            profileService.updateHeight(heightInCm)
        } else {
            profileService.updateHeight(nil)
        }
        
        profileService.updateGender(selectedGender)
        profileService.updateBirthDate(hasBirthDate ? birthDate : nil)
    }
    
    private func calculateBMI() -> Double? {
        guard let weight = Double(weightText), weight > 0,
              let height = Double(heightText), height > 0 else {
            return nil
        }
        
        // Convert to metric for BMI calculation
        let weightKg = profileService.profile.weightFromDisplayUnit(weight)
        let heightCm = profileService.profile.heightFromDisplayUnit(height)
        let heightM = heightCm / 100
        
        return weightKg / (heightM * heightM)
    }
    
    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    private func calculateAge() -> Int? {
        guard hasBirthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
    }
}
