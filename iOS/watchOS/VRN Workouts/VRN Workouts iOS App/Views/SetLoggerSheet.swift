import SwiftUI

struct SetLoggerSheet: View {
    let exercise: Exercise
    let lastSet: SetLog?
    let onSave: (Double, Int, Int?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var rpe: Int? = nil
    @State private var showRPE = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Weight input
                VStack(spacing: 8) {
                    Text("Weight (kg)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Button {
                            if weight >= 2.5 { weight -= 2.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                        }
                        
                        TextField("0", value: $weight, format: .number)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .frame(width: 120)
                        
                        Button {
                            weight += 2.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                }
                
                // Reps input
                VStack(spacing: 8) {
                    Text("Reps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Button {
                            if reps > 1 { reps -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                        }
                        
                        Text("\(reps)")
                            .font(.system(size: 48, weight: .bold))
                            .frame(width: 80)
                        
                        Button {
                            reps += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                }
                
                // RPE toggle
                VStack(spacing: 8) {
                    Toggle("Log RPE", isOn: $showRPE)
                        .tint(.orange)
                    
                    if showRPE {
                        HStack(spacing: 8) {
                            ForEach(6...10, id: \.self) { value in
                                Button {
                                    rpe = value
                                } label: {
                                    Text("\(value)")
                                        .font(.headline)
                                        .frame(width: 44, height: 44)
                                        .background(rpe == value ? Color.orange : Color(.systemGray5))
                                        .foregroundStyle(rpe == value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                // Save button fixed at bottom
                Button {
                    onSave(weight, reps, showRPE ? rpe : nil)
                } label: {
                    Text("Save Set")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(weight <= 0 || reps <= 0)
                .padding()
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-fill with last set data
                if let last = lastSet {
                    weight = last.weight
                    reps = last.reps
                    if let lastRpe = last.rpe {
                        rpe = lastRpe
                        showRPE = true
                    }
                } else {
                    // Default to target reps
                    if let minReps = exercise.repsMin {
                        reps = minReps
                    }
                }
            }
        }
    }
}

#Preview {
    SetLoggerSheet(
        exercise: Exercise(
            exerciseId: "test",
            exerciseDbId: nil,
            name: "Bench Press",
            slug: nil,
            workingSets: 4,
            repsMin: 8,
            repsMax: 10,
            restSeconds: 90,
            category: nil,
            difficulty: nil,
            rpe: 8,
            rir: nil,
            tempo: nil,
            tempoDescription: nil,
            media: nil,
            warmupSets: nil,
            formCues: nil,
            equipment: nil,
            muscleGroups: nil,
            supersetWith: nil,
            supersetType: nil,
            prescribedSets: nil,
            prescribedReps: nil,
            notes: nil,
            demoUrl: nil,
            gifUrl: nil,
            type: nil
        ),
        lastSet: nil,
        onSave: { _, _, _ in }
    )
}
