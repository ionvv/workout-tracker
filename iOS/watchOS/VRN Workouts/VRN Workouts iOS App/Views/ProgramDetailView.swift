import SwiftUI

struct ProgramDetailView: View {
    let program: Program
    @State private var selectedDay: WorkoutDay?
    @State private var showingWorkout = false
    
    var body: some View {
        List {
            ForEach(program.days) { day in
                Section {
                    DayRow(day: day)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("ProgramDetailView: Tapped day \(day.dayName)")
                            print("ProgramDetailView: exerciseList count = \(day.exerciseList.count)")
                            selectedDay = day
                            showingWorkout = true
                        }
                    
                    // Exercise preview
                    ForEach(day.exerciseList.prefix(3)) { exercise in
                        ExercisePreviewRow(exercise: exercise)
                    }
                    
                    if day.exerciseList.count > 3 {
                        Text("+ \(day.exerciseList.count - 3) more exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(program.programName)
        .fullScreenCover(isPresented: $showingWorkout) {
            if let day = selectedDay {
                ActiveWorkoutView(program: program, day: day)
            }
        }
    }
}

struct DayRow: View {
    let day: WorkoutDay
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.dayName)
                    .font(.headline)
                
                HStack {
                    if let dayType = day.dayType {
                        Text(dayType.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text("\(day.exerciseList.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let time = day.estimatedTime {
                        Text("~\(time) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 8)
    }
}

struct ExercisePreviewRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack {
            Text(exercise.name)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(exercise.sets)×\(exercise.reps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 16)
    }
}

#Preview {
    NavigationStack {
        ProgramDetailView(program: Program(
            dbId: nil,
            userId: nil,
            programId: "test",
            programName: "Test Program",
            workoutDays: [],
            createdAt: nil,
            updatedAt: nil
        ))
    }
}
