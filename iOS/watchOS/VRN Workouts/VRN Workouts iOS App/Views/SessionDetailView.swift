import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession
    
    var body: some View {
        List {
            // Summary section
            Section("Summary") {
                HStack {
                    StatCard(title: "Duration", value: "\(session.duration ?? 0)", unit: "min", icon: "timer")
                    StatCard(title: "Sets", value: "\(session.totalSets ?? 0)", unit: "", icon: "number")
                    StatCard(title: "Volume", value: "\(session.totalVolume ?? 0)", unit: "kg", icon: "scalemass")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Exercises
            Section("Exercises") {
                ForEach(session.exercises) { exercise in
                    if !exercise.skipped {
                        ExerciseSessionRow(exercise: exercise)
                    }
                }
            }
            
            // Notes
            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.dayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(unit.isEmpty ? title : "\(unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ExerciseSessionRow: View {
    let exercise: SessionExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.exerciseName)
                .font(.headline)
            
            if exercise.sets.isEmpty {
                Text("No sets logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercise.sets) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .font(.subheadline)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("\(Int(set.weight)) kg × \(set.reps)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if let rpe = set.rpe {
                            Text("RPE \(rpe)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: WorkoutSession(
            id: UUID(),
            userId: UUID(),
            sessionId: "test",
            programId: "prog1",
            dayId: "day1",
            dayName: "Day A - Push",
            startTime: Date(),
            endTime: Date(),
            exercises: [],
            notes: "Great workout!",
            totalVolume: 5000,
            totalSets: 15,
            duration: 45,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
