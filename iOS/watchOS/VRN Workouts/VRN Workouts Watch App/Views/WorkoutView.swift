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
                if session.currentExercise != nil {
                    // Active workout - swipeable exercise pages
                    TabView(selection: $currentExerciseIndex) {
                        ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ExercisePage(
                                exercise: exercise,
                                index: index,
                                total: session.exercises.count,
                                heartRate: viewModel.heartRate,
                                calories: viewModel.activeCalories,
                                startTime: session.startTime,
                                restTime: viewModel.restTimeRemaining,
                                isPaused: viewModel.isPaused,
                                onAddSet: { showingSetLogger = true },
                                onSkip: { skipAndNext() },
                                onPause: { viewModel.togglePause() },
                                onStop: { showingEndOptions = true }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.verticalPage)
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

// MARK: - Exercise Page (Full screen for each exercise)

struct ExercisePage: View {
    let exercise: SessionExercise
    let index: Int
    let total: Int
    let heartRate: Double
    let calories: Double
    let startTime: Date
    let restTime: Int
    let isPaused: Bool
    let onAddSet: () -> Void
    let onSkip: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Stats header
                StatsHeader(
                    heartRate: heartRate,
                    calories: calories,
                    startTime: startTime,
                    restTime: restTime
                )
                
                // 2x2 Action buttons
                ActionButtonGrid(
                    onAddSet: onAddSet,
                    onSkip: onSkip,
                    onPause: onPause,
                    onStop: onStop,
                    isPaused: isPaused
                )
                
                // Exercise name & progress
                VStack(spacing: 4) {
                    Text("\(index + 1)/\(total)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(exercise.exerciseName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if let sets = exercise.prescribedSets, let reps = exercise.prescribedReps {
                        Text("\(sets) × \(reps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Logged sets
                if !exercise.sets.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(exercise.sets) { set in
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
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Exercise image placeholder (if available in future)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 60)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Stats Header

struct StatsHeader: View {
    let heartRate: Double
    let calories: Double
    let startTime: Date
    let restTime: Int
    
    var body: some View {
        HStack(spacing: 8) {
            // Heart rate
            if heartRate > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(heartRate))")
                }
                .font(.caption2)
            }
            
            // Calories
            if calories > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(Int(calories))")
                }
                .font(.caption2)
            }
            
            Spacer()
            
            // Timer or Rest
            if restTime > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                    Text(formatRest(restTime))
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(from: startTime, to: context.date))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.3))
        .cornerRadius(10)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
            // Row 1: Add | Skip
            HStack(spacing: 6) {
                ActionButton(
                    title: "Add",
                    icon: "plus",
                    color: .green,
                    action: onAddSet
                )
                
                ActionButton(
                    title: "Skip",
                    icon: "forward.fill",
                    color: .gray,
                    action: onSkip
                )
            }
            
            // Row 2: Pause | Stop
            HStack(spacing: 6) {
                ActionButton(
                    title: isPaused ? "Resume" : "Pause",
                    icon: isPaused ? "play.fill" : "pause.fill",
                    color: .yellow,
                    action: onPause
                )
                
                ActionButton(
                    title: "Stop",
                    icon: "stop.fill",
                    color: .red,
                    action: onStop
                )
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color.opacity(0.3))
            .foregroundColor(color == .yellow ? .primary : color)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
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
                .font(.system(size: 44))
                .foregroundColor(.green)
            
            Text("Complete!")
                .font(.title3)
                .fontWeight(.bold)
            
            let stats = session.calculateStats()
            VStack(spacing: 4) {
                Text("\(stats.sets) sets")
                    .font(.headline)
                Text("\(stats.volume) kg total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(stats.duration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save Workout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
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
