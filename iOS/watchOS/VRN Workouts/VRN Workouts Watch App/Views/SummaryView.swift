import SwiftUI

struct SummaryView: View {
    let session: ActiveWorkoutSession
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 50))
                    
                    Text("Workout Complete!")
                        .font(.headline)
                    
                    let stats = session.calculateStats()
                    
                    // Stats cards
                    VStack(spacing: 12) {
                        StatRow(label: "Sets", value: "\(stats.sets)")
                        StatRow(label: "Volume", value: "\(stats.volume)kg")
                        StatRow(label: "Duration", value: "\(stats.duration) min")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Exercises completed
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exercises")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ForEach(session.exercises.filter { !$0.skipped }) { ex in
                            HStack {
                                Text(ex.exerciseName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(ex.sets.count) sets")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    SummaryView(
        session: ActiveWorkoutSession(
            program: Program(
                id: UUID(),
                userId: UUID(),
                programId: "test",
                programName: "Test",
                workoutDays: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            day: WorkoutDay(
                dayId: "day-a",
                dayName: "Day A",
                exercises: []
            )
        )
    )
}
