import SwiftUI
import HealthKit

struct ActiveWorkoutView: View {
    let program: Program
    let day: WorkoutDay
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showingSetLogger = false
    @State private var showingEndAlert = false
    @State private var currentExerciseIndex = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with timer, heart rate, and rest timer
                WorkoutHeaderView(viewModel: viewModel, dayName: day.dayName)
                
                if day.exerciseList.isEmpty {
                    // Empty state
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("This workout day has no exercises.")
                    )
                } else {
                    // Exercise cards
                    TabView(selection: $currentExerciseIndex) {
                        ForEach(Array(day.exerciseList.enumerated()), id: \.element.id) { index, exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                exerciseIndex: index,
                                session: viewModel.activeSession,
                                onLogSet: {
                                    currentExerciseIndex = index
                                    showingSetLogger = true
                                },
                                onSkip: {
                                    viewModel.skipExercise(at: index)
                                    if index < day.exerciseList.count - 1 {
                                        currentExerciseIndex = index + 1
                                    }
                                }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Bottom action bar
                    WorkoutActionBar(
                        currentIndex: currentExerciseIndex,
                        totalExercises: day.exerciseList.count,
                        onPrevious: {
                            if currentExerciseIndex > 0 {
                                currentExerciseIndex -= 1
                            }
                        },
                        onNext: {
                            if currentExerciseIndex < day.exerciseList.count - 1 {
                                currentExerciseIndex += 1
                            }
                        },
                        onFinish: {
                            showingEndAlert = true
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingEndAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.restTimeRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(formatRestTime(viewModel.restTimeRemaining))
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingSetLogger) {
                if currentExerciseIndex < day.exerciseList.count {
                    let lastSet: SetLog? = {
                        guard let session = viewModel.activeSession,
                              currentExerciseIndex < session.exercises.count else {
                            return nil
                        }
                        return session.exercises[currentExerciseIndex].sets.last
                    }()
                    
                    SetLoggerSheet(
                        exercise: day.exerciseList[currentExerciseIndex],
                        lastSet: lastSet,
                        onSave: { weight, reps, rpe in
                            viewModel.logSet(at: currentExerciseIndex, weight: weight, reps: reps, rpe: rpe)
                            showingSetLogger = false
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .alert("End Workout?", isPresented: $showingEndAlert) {
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
            .task {
                print("ActiveWorkoutView: Starting workout")
                print("ActiveWorkoutView: Day = \(day.dayName)")
                print("ActiveWorkoutView: Exercises count = \(day.exerciseList.count)")
                for (i, ex) in day.exerciseList.enumerated() {
                    print("  Exercise \(i): \(ex.name)")
                }
                viewModel.startWorkout(program: program, day: day)
            }
        }
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

// MARK: - Workout Header

struct WorkoutHeaderView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let dayName: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.headline)
            
            HStack(spacing: 16) {
                // Timer
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let startTime = viewModel.activeSession?.startTime {
                        Label(formatDuration(from: startTime, to: context.date), systemImage: "timer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Heart rate
                if viewModel.heartRate > 0 {
                    Label("\(Int(viewModel.heartRate)) BPM", systemImage: "heart.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                
                // Calories
                if viewModel.activeCalories > 0 {
                    Label("\(Int(viewModel.activeCalories)) cal", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Exercise Card

struct ExerciseCardView: View {
    let exercise: Exercise
    let exerciseIndex: Int
    let session: ActiveWorkoutSession?
    let onLogSet: () -> Void
    let onSkip: () -> Void
    
    private var loggedSets: [SetLog] {
        guard let session = session,
              exerciseIndex < session.exercises.count else {
            return []
        }
        return session.exercises[exerciseIndex].sets
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Exercise image
                if let gifUrl = exercise.imageUrl, let url = URL(string: gifUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .overlay {
                                ProgressView()
                            }
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                // Exercise info
                VStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Label("\(exercise.sets) sets", systemImage: "number")
                        Label("\(exercise.reps) reps", systemImage: "arrow.counterclockwise")
                        Label("\(exercise.rest)s rest", systemImage: "timer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    if let rpe = exercise.rpe {
                        Text("Target RPE: \(rpe)")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Logged sets
                if !loggedSets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logged Sets")
                            .font(.headline)
                        
                        ForEach(loggedSets) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(set.weight)) kg × \(set.reps)")
                                if let rpe = set.rpe {
                                    Text("@ RPE \(rpe)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // Form cues
                if let cues = exercise.formCues, !cues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Form Cues")
                            .font(.headline)
                        
                        ForEach(cues, id: \.self) { cue in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(cue)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5).opacity(0.5))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed action buttons at bottom
            HStack(spacing: 16) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    onLogSet()
                } label: {
                    Label("Log Set", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Rest Timer

struct RestTimerView: View {
    let secondsLeft: Int
    
    var body: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest: \(formatTime(secondsLeft))")
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

// MARK: - Action Bar

struct WorkoutActionBar: View {
    let currentIndex: Int
    let totalExercises: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(currentIndex == 0)
            
            Spacer()
            
            Text("\(currentIndex + 1) / \(totalExercises)")
                .font(.headline)
            
            Spacer()
            
            if currentIndex == totalExercises - 1 {
                Button("Finish") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    ActiveWorkoutView(
        program: Program(dbId: nil, userId: nil, programId: "test", programName: "Test", workoutDays: nil, createdAt: nil, updatedAt: nil),
        day: WorkoutDay(dayId: "day1", dayName: "Day A", exercises: nil, dayType: nil, estimatedTime: nil, warmup: nil, cooldown: nil, finisher: nil, focusMuscles: nil, secondaryMuscles: nil)
    )
}
