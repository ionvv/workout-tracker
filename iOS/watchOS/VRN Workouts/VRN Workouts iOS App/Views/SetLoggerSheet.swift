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
    @State private var showWeight = true
    
    private var isTimed: Bool { exercise.isTimed }
    private var valueLabel: String { isTimed ? "Seconds" : "Reps" }
    private var valueIncrement: Int { isTimed ? 5 : 1 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Weight input (optional for timed exercises)
                    if showWeight {
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
                    }
                    
                    // Reps/Seconds input
                    VStack(spacing: 8) {
                        Text(valueLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            Button {
                                if reps > valueIncrement { reps -= valueIncrement }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                            }
                            
                            Text("\(reps)")
                                .font(.system(size: 48, weight: .bold))
                                .frame(width: 100)
                            
                            Button {
                                reps += valueIncrement
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                            }
                        }
                        
                        // Quick select buttons for timed exercises
                        if isTimed {
                            HStack(spacing: 12) {
                                ForEach([30, 45, 60, 90], id: \.self) { sec in
                                    Button {
                                        reps = sec
                                    } label: {
                                        Text("\(sec)s")
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(reps == sec ? Color.blue : Color(.systemGray5))
                                            .foregroundStyle(reps == sec ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    // Weight toggle for timed exercises
                    if isTimed {
                        Toggle("Add Weight", isOn: $showWeight)
                            .tint(.blue)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
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
                    onSave(showWeight ? weight : 0, reps, showRPE ? rpe : nil)
                } label: {
                    Text("Save Set")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(reps <= 0 || (showWeight && !isTimed && weight <= 0))
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
                // For timed exercises, default to no weight
                if isTimed {
                    showWeight = false
                    reps = 30 // Default 30 seconds
                }
                
                // Pre-fill with last set data
                if let last = lastSet {
                    weight = last.weight
                    reps = last.reps
                    if last.weight > 0 { showWeight = true }
                    if let lastRpe = last.rpe {
                        rpe = lastRpe
                        showRPE = true
                    }
                } else if !isTimed {
                    // Default to target reps for non-timed
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
