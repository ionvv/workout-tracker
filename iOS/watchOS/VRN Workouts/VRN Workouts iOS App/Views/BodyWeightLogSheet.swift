import SwiftUI

struct BodyWeightLogSheet: View {
    let sessionDurationMinutes: Int
    let onSave: (Double?, Int?) -> Void  // (weight, customDurationMinutes)
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = ProfileService.shared
    @State private var weightText: String = ""
    @State private var showDurationPicker = false
    @State private var customDurationMinutes: Int = 30
    
    private var unitSystem: UserProfile.UnitSystem {
        profileService.profile.unitSystem
    }
    
    private var isShortSession: Bool {
        sessionDurationMinutes < 5
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Body Weight Section
                    VStack(spacing: 16) {
                        Text("Log Body Weight")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Track your weight with each workout")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // Weight input
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
                        
                        // Quick weight buttons
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
                    }
                    .padding()
                    
                    // Duration correction section (only for short sessions)
                    if isShortSession {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "clock.badge.questionmark")
                                    .foregroundStyle(.orange)
                                Text("Session was \(sessionDurationMinutes) min")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            
                            Toggle(isOn: $showDurationPicker) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set actual duration")
                                        .font(.headline)
                                    Text("If you logged exercises after the workout")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.orange)
                            
                            if showDurationPicker {
                                VStack(spacing: 12) {
                                    HStack(spacing: 16) {
                                        Button {
                                            if customDurationMinutes > 5 {
                                                customDurationMinutes -= 5
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                        }
                                        
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("\(customDurationMinutes)")
                                                .font(.system(size: 44, weight: .bold))
                                            Text("min")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Button {
                                            customDurationMinutes += 5
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                        }
                                    }
                                    
                                    // Quick duration buttons
                                    HStack(spacing: 8) {
                                        ForEach([20, 30, 45, 60, 90], id: \.self) { mins in
                                            Button {
                                                customDurationMinutes = mins
                                            } label: {
                                                Text("\(mins)")
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(customDurationMinutes == mins ? Color.orange : Color(.systemGray5))
                                                    .foregroundStyle(customDurationMinutes == mins ? .white : .primary)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            let weight = parseWeight()
                            let duration = showDurationPicker ? customDurationMinutes : nil
                            onSave(weight, duration)
                        } label: {
                            Text("Save Workout")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            let duration = showDurationPicker ? customDurationMinutes : nil
                            onSave(nil, duration)
                        } label: {
                            Text("Skip Weight Logging")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onSave(nil, nil)
                    }
                }
            }
            .interactiveDismissDisabled()
            .onAppear {
                if let weight = profileService.profile.weightInDisplayUnit {
                    weightText = formatWeight(weight)
                }
            }
        }
    }
    
    private var quickWeights: [Double] {
        if let baseWeight = profileService.profile.weightInDisplayUnit {
            let rounded = (baseWeight / 5).rounded() * 5
            return stride(from: rounded - 5, through: rounded + 5, by: 5).map { $0 }
        }
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
        return profileService.profile.weightFromDisplayUnit(displayValue)
    }
}

#Preview {
    BodyWeightLogSheet(sessionDurationMinutes: 2) { weight, duration in
        print("Weight: \(weight ?? 0), Duration: \(duration ?? 0)")
    }
}
