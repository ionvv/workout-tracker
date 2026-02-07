import SwiftUI

struct SetLoggerView: View {
    let exercise: SessionExercise
    let onSave: (Double, Int, Int?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @State private var rpe: Int? = nil
    @FocusState private var focusedField: Field?
    
    enum Field {
        case weight, reps
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Weight input - compact
            HStack {
                Text("KG")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                Button {
                    weight = max(0, weight - 2.5)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Text("\(weight, specifier: "%.1f")")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .frame(minWidth: 60)
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
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Reps input - compact
            HStack {
                Text("REP")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                Button {
                    reps = max(0, reps - 1)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Text("\(Int(reps))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .frame(minWidth: 60)
                    .focusable()
                    .digitalCrownRotation(
                        $reps,
                        from: 0,
                        through: 50,
                        by: 1.0,
                        sensitivity: .low
                    )
                    .focused($focusedField, equals: .reps)
                
                Button {
                    reps += 1
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Action buttons - side by side
            HStack(spacing: 8) {
                // Same as last (if available)
                if let lastSet = exercise.sets.last {
                    Button {
                        weight = lastSet.weight
                        reps = Double(lastSet.reps)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 44)
                }
                
                // Save button
                Button {
                    onSave(weight, Int(reps), rpe)
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(weight <= 0 || reps <= 0)
            }
            
            // Exercise info below buttons
            VStack(spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("Set \(exercise.sets.count + 1)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if let lastSet = exercise.sets.last {
                    Text("Last: \(Int(lastSet.weight))kg × \(lastSet.reps)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onAppear {
            // Pre-fill with last set if available
            if let lastSet = exercise.sets.last {
                weight = lastSet.weight
                reps = Double(lastSet.reps)
            } else {
                weight = 20
                reps = 10
            }
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
