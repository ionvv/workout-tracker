import SwiftUI

struct SetLoggerView: View {
    let exercise: SessionExercise
    let onSave: (Double, Int, Int?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case weight, reps
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Weight row: [-] 20 kg [+]
            HStack(spacing: 8) {
                SquareButton(icon: "minus") {
                    weight = max(0, weight - 2.5)
                    WKInterfaceDevice.current().play(.click)
                }
                
                HStack(spacing: 2) {
                    Text(weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("kg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.7)
                    .focusable()
                    .digitalCrownRotation(
                        $weight,
                        from: 0,
                        through: 300,
                        by: 2.5,
                        sensitivity: .medium
                    )
                    .focused($focusedField, equals: .weight)
                
                SquareButton(icon: "plus") {
                    weight += 2.5
                    WKInterfaceDevice.current().play(.click)
                }
            }
            
            // Reps row: [-] x12 [+]
            HStack(spacing: 8) {
                SquareButton(icon: "minus") {
                    reps = max(0, reps - 1)
                    WKInterfaceDevice.current().play(.click)
                }
                
                HStack(spacing: 4) {
                    Text("×")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    Text("\(Int(reps))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.7)
                    .focusable()
                    .digitalCrownRotation(
                        $reps,
                        from: 0,
                        through: 50,
                        by: 1.0,
                        sensitivity: .low
                    )
                    .focused($focusedField, equals: .reps)
                
                SquareButton(icon: "plus") {
                    reps += 1
                    WKInterfaceDevice.current().play(.click)
                }
            }
            
            // Save button - full width
            Button {
                onSave(weight, Int(reps), nil)
            } label: {
                Text("Save")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(weight <= 0 || reps <= 0)
            
            // Cancel button - full width
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.bordered)
            
            // Exercise name at bottom
            Text(exercise.exerciseName)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
        .padding(.top, 32)
        .onAppear {
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

// Square +/- button
struct SquareButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .fontWeight(.semibold)
                .frame(width: 36, height: 36)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
