import SwiftUI

struct BodyWeightLogSheet: View {
    let onSave: (Double?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = ProfileService.shared
    @State private var weightText: String = ""
    
    private var unitSystem: UserProfile.UnitSystem {
        profileService.profile.unitSystem
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Log Body Weight")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Track your weight with each workout")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Weight input
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Button {
                            decrementWeight()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            TextField("0", text: $weightText)
                                .font(.system(size: 56, weight: .bold))
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .frame(width: 140)
                            
                            Text(unitSystem.weightUnit)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            incrementWeight()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                }
                
                // Quick buttons
                HStack(spacing: 12) {
                    ForEach(quickWeights, id: \.self) { weight in
                        Button {
                            weightText = formatWeight(weight)
                        } label: {
                            Text(formatWeight(weight))
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        let weight = parseWeight()
                        onSave(weight)
                    } label: {
                        Text("Save Workout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        onSave(nil)
                    } label: {
                        Text("Skip Weight Logging")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onSave(nil)  // Still save workout, just skip weight
                    }
                }
            }
            .interactiveDismissDisabled()  // Prevent swipe-to-dismiss losing workout
            .onAppear {
                // Pre-fill with last known weight
                if let weight = profileService.profile.weightInDisplayUnit {
                    weightText = formatWeight(weight)
                }
            }
        }
    }
    
    private var quickWeights: [Double] {
        // Generate weights around the current profile weight
        if let baseWeight = profileService.profile.weightInDisplayUnit {
            let rounded = (baseWeight / 5).rounded() * 5
            return stride(from: rounded - 5, through: rounded + 5, by: 5).map { $0 }
        }
        // Default weights based on unit system
        if unitSystem == .imperial {
            return [150, 160, 170, 180, 190]
        }
        return [65, 70, 75, 80, 85]
    }
    
    private func incrementWeight() {
        let current = Double(weightText) ?? 0
        let increment = unitSystem == .imperial ? 1.0 : 0.5
        weightText = formatWeight(current + increment)
    }
    
    private func decrementWeight() {
        let current = Double(weightText) ?? 0
        let increment = unitSystem == .imperial ? 1.0 : 0.5
        if current > increment {
            weightText = formatWeight(current - increment)
        }
    }
    
    private func formatWeight(_ value: Double) -> String {
        if unitSystem == .imperial {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
    
    private func parseWeight() -> Double? {
        guard let displayValue = Double(weightText), displayValue > 0 else {
            return nil
        }
        // Convert to kg for storage
        return profileService.profile.weightFromDisplayUnit(displayValue)
    }
}

#Preview {
    BodyWeightLogSheet { weight in
        print("Weight: \(weight ?? 0)")
    }
}
