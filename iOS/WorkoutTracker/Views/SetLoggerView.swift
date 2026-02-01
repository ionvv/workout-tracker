import SwiftUI

struct SetLoggerView: View {
    let exercise: SessionExercise
    let onSave: (Double, Int, Int?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var rpe: Int? = nil
    @FocusState private var focusedField: Field?
    
    enum Field {
        case weight, reps
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Exercise name
                    Text(exercise.exerciseName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    // Set number
                    Text("Set \(exercise.sets.count + 1)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Last set reference
                    if let lastSet = exercise.sets.last {
                        Text("Last: \(Int(lastSet.weight))kg × \(lastSet.reps)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // Weight input (Digital Crown optimized)
                    VStack(spacing: 8) {
                        Text("Weight (kg)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Button {
                                weight = max(0, weight - 2.5)
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(weight, specifier: "%.1f")")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .frame(minWidth: 80)
                                .focusable()
                                .digitalCrownRotation(
                                    $weight,
                                    from: 0,
                                    through: 300,
                                    by: 2.5,
                                    sensitivity: .medium
                                )
                                .focused($focusedField, equals: .weight)
                            
                            Button {
                                weight += 2.5
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                    
                    // Reps input
                    VStack(spacing: 8) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Button {
                                reps = max(0, reps - 1)
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(reps)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .frame(minWidth: 60)
                                .focusable()
                                .digitalCrownRotation(
                                    $reps,
                                    from: 0,
                                    through: 50,
                                    by: 1,
                                    sensitivity: .low
                                )
                                .focused($focusedField, equals: .reps)
                            
                            Button {
                                reps += 1
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Optional RPE
                    if let rpeValue = rpe {
                        Divider()
                        
                        VStack(spacing: 8) {
                            Text("RPE (optional)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Button {
                                    if rpeValue > 1 {
                                        rpe = rpeValue - 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(rpeValue)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Button {
                                    if rpeValue < 10 {
                                        rpe = rpeValue + 1
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Buttons
                    VStack(spacing: 8) {
                        if let lastSet = exercise.sets.last {
                            Button {
                                weight = lastSet.weight
                                reps = lastSet.reps
                                rpe = lastSet.rpe
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("Same as Last")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button {
                            onSave(weight, reps, rpe)
                        } label: {
                            Label("Save Set", systemImage: "checkmark")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(weight <= 0 || reps <= 0)
                    }
                }
                .padding()
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill with last set if available
            if let lastSet = exercise.sets.last {
                weight = lastSet.weight
                reps = lastSet.reps
            } else {
                // Default starting values
                weight = 20
                reps = 10
            }
            
            // Focus weight field by default
            focusedField = .weight
        }
    }
}

#Preview {
    SetLoggerView(
        exercise: SessionExercise(
            exerciseId: "test",
            exerciseName: "Back Squat",
            prescribedSets: 4,
            prescribedReps: "6-8",
            sets: [],
            skipped: false
        ),
        onSave: { _, _, _ in }
    )
}
