import SwiftUI
import WatchKit

struct WorkoutView: View {
    let program: Program
    let day: WorkoutDay
    
    @StateObject private var viewModel = WorkoutViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingSetLogger = false
    @State private var currentExerciseIndex = 0
    @State private var showingEndOptions = false
    
    var body: some View {
        Group {
            if let session = viewModel.activeSession {
                VStack(spacing: 0) {
                    // Compact header
                    WorkoutHeader(session: session, heartRate: viewModel.heartRate)
                    
                    if session.currentExercise != nil {
                        // Exercise slides
                        TabView(selection: $currentExerciseIndex) {
                            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                                ExerciseSlide(
                                    exercise: exercise,
                                    index: index,
                                    total: session.exercises.count,
                                    restTime: viewModel.restTimeRemaining
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.verticalPage)
                        
                        // Action buttons - 2x2 grid
                        ActionButtonGrid(
                            onAddSet: { showingSetLogger = true },
                            onSkip: { skipAndNext() },
                            onPause: { viewModel.togglePause() },
                            onStop: { showingEndOptions = true },
                            isPaused: viewModel.isPaused
                        )
                    } else {
                        // Workout complete
                        WorkoutCompleteView(
                            session: session,
                            isSaving: viewModel.isSaving,
                            onSave: {
                                Task {
                                    await viewModel.endWorkout()
                                    dismiss()
                                }
                            }
                        )
                    }
                }
            } else {
                ProgressView("Starting...")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSetLogger) {
            if currentExerciseIndex < (viewModel.activeSession?.exercises.count ?? 0) {
                SetLoggerView(
                    exercise: viewModel.activeSession!.exercises[currentExerciseIndex],
                    onSave: { weight, reps, rpe in
                        viewModel.logSet(at: currentExerciseIndex, weight: weight, reps: reps, rpe: rpe)
                        WKInterfaceDevice.current().play(.click)
                        showingSetLogger = false
                    }
                )
            }
        }
        .confirmationDialog("End Workout", isPresented: $showingEndOptions) {
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
            Button("Continue", role: .cancel) { }
        }
        .task {
            viewModel.startWorkout(program: program, day: day)
        }
        .onChange(of: currentExerciseIndex) { _, newIndex in
            viewModel.setCurrentExercise(index: newIndex)
        }
    }
    
    private func skipAndNext() {
        viewModel.skipExercise(at: currentExerciseIndex)
        if currentExerciseIndex < (viewModel.activeSession?.exercises.count ?? 1) - 1 {
            withAnimation {
                currentExerciseIndex += 1
            }
        }
    }
}

// MARK: - Workout Header

struct WorkoutHeader: View {
    let session: ActiveWorkoutSession
    let heartRate: Double
    
    var body: some View {
        HStack {
            // Timer
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatDuration(from: session.startTime, to: context.date))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Heart rate
            if heartRate > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption2)
                    Text("\(Int(heartRate))")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.3))
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Exercise Slide

struct ExerciseSlide: View {
    let exercise: SessionExercise
    let index: Int
    let total: Int
    let restTime: Int
    
    var body: some View {
        VStack(spacing: 6) {
            // Progress indicator
            Text("\(index + 1)/\(total)")
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Exercise name
            Text(exercise.exerciseName)
                .font(.headline)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Prescription
            if let sets = exercise.prescribedSets, let reps = exercise.prescribedReps {
                Text("\(sets) × \(reps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Rest timer (if active)
            if restTime > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(formatRest(restTime))
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .padding(.vertical, 4)
            }
            
            // Logged sets
            if !exercise.sets.isEmpty {
                VStack(spacing: 2) {
                    ForEach(exercise.sets.suffix(3)) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(set.weight))kg × \(set.reps)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(6)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
    
    private func formatRest(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

// MARK: - Action Button Grid (2x2)

struct ActionButtonGrid: View {
    let onAddSet: () -> Void
    let onSkip: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let isPaused: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // Row 1: Add Set | Skip
            HStack(spacing: 6) {
                Button(action: onAddSet) {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("Set")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button(action: onSkip) {
                    VStack(spacing: 2) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                        Text("Skip")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            // Row 2: Pause | Stop
            HStack(spacing: 6) {
                Button(action: onPause) {
                    VStack(spacing: 2) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
                
                Button(action: onStop) {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                        Text("End")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Workout Complete View

struct WorkoutCompleteView: View {
    let session: ActiveWorkoutSession
    let isSaving: Bool
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Complete!")
                .font(.headline)
            
            let stats = session.calculateStats()
            VStack(spacing: 4) {
                Text("\(stats.sets) sets")
                Text("\(stats.volume) kg total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
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
