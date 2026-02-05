import SwiftUI

struct WorkoutView: View {
    let program: Program
    let day: WorkoutDay
    
    @StateObject private var viewModel = WorkoutViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingSetLogger = false
    @State private var showingSummary = false
    @State private var currentTime = Date()
    @State private var showingCancelAlert = false
    
    var body: some View {
        Group {
            if let session = viewModel.activeSession {
                VStack(spacing: 8) {
                    // Header
                    VStack(spacing: 2) {
                        Text(session.dayName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(workoutDuration(from: session.startTime, to: context.date))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            if viewModel.heartRate > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                    Text("\(Int(viewModel.heartRate))")
                                }
                                .font(.caption2)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Current Exercise
                    if let currentEx = session.currentExercise {
                        ScrollView {
                            VStack(spacing: 12) {
                                // Exercise info
                                VStack(spacing: 4) {
                                    Text("\(session.currentExerciseIndex + 1)/\(session.exercises.count)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    Text(currentEx.exerciseName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("\(currentEx.prescribedSets)×\(currentEx.prescribedReps)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Logged sets
                                if !currentEx.sets.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(currentEx.sets) { set in
                                            HStack {
                                                Text("Set \(set.setNumber):")
                                                    .font(.caption2)
                                                Spacer()
                                                Text("\(Int(set.weight))kg × \(set.reps)")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                // Rest timer
                                if viewModel.restTimeRemaining > 0 {
                                    VStack(spacing: 4) {
                                        Text("Rest")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text(formatRestTime(viewModel.restTimeRemaining))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                // Buttons
                                VStack(spacing: 8) {
                                    Button {
                                        showingSetLogger = true
                                    } label: {
                                        Label("Add Set", systemImage: "plus.circle.fill")
                                            .fontWeight(.semibold)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    HStack(spacing: 8) {
                                        Button {
                                            viewModel.skipCurrentExercise()
                                        } label: {
                                            Text("Skip")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        if session.currentExerciseIndex < session.exercises.count - 1 {
                                            Button {
                                                viewModel.moveToNextExercise()
                                            } label: {
                                                Text("Next")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Workout complete
                        VStack(spacing: 12) {
                            Text("✅")
                                .font(.system(size: 50))
                            Text("Workout Complete!")
                                .font(.headline)
                            
                            let stats = session.calculateStats()
                            VStack(spacing: 4) {
                                Text("\(stats.sets) sets · \(stats.volume)kg")
                                    .font(.caption)
                                Text("\(stats.duration) minutes")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Button {
                                Task {
                                    await viewModel.endWorkout()
                                    dismiss()
                                }
                            } label: {
                                if viewModel.isSaving {
                                    ProgressView()
                                } else {
                                    Text("Save Workout")
                                        .fontWeight(.semibold)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isSaving)
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarBackButtonHidden(viewModel.activeSession != nil)
        .toolbar {
            if viewModel.activeSession != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .alert("End Workout?", isPresented: $showingCancelAlert) {
            Button("Continue", role: .cancel) { }
            Button("Save & End") {
                Task {
                    await viewModel.endWorkout()
                    dismiss()
                }
            }
            Button("Discard", role: .destructive) {
                viewModel.cancelWorkout()
                dismiss()
            }
        } message: {
            Text("Save your progress or discard?")
        }
        .sheet(isPresented: $showingSetLogger) {
            if let currentEx = viewModel.activeSession?.currentExercise {
                SetLoggerView(
                    exercise: currentEx,
                    onSave: { weight, reps, rpe in
                        viewModel.logSet(weight: weight, reps: reps, rpe: rpe)
                        WKInterfaceDevice.current().play(.click)
                        showingSetLogger = false
                    }
                )
            }
        }
        .task {
            viewModel.startWorkout(program: program, day: day)
        }
    }
    
    private func workoutDuration(from start: Date, to end: Date = Date()) -> String {
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatRestTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

#Preview {
    WorkoutView(
        program: Program(
            dbId: UUID(),
            userId: UUID(),
            programId: "test",
            programName: "Test Program",
            workoutDays: [],
            createdAt: nil,
            updatedAt: nil
        ),
        day: WorkoutDay(
            dayId: "day-a",
            dayName: "Day A",
            exercises: [],
            dayType: nil,
            estimatedTime: nil,
            warmup: nil,
            cooldown: nil,
            finisher: nil,
            focusMuscles: nil,
            secondaryMuscles: nil
        )
    )
}
