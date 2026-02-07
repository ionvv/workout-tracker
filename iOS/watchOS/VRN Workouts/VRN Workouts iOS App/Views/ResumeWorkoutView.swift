import SwiftUI

/// View for resuming a persisted workout session
struct ResumeWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var persistedSession: PersistableSession?
    @State private var currentExerciseIndex = 0
    @State private var showingSetLogger = false
    @State private var showingEndAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let session = persistedSession {
                    VStack(spacing: 0) {
                        // Header
                        ResumeHeaderView(session: session, viewModel: viewModel)
                        
                        // Exercise cards
                        TabView(selection: $currentExerciseIndex) {
                            ForEach(Array(session.exercises.enumerated()), id: \.element.exerciseId) { index, exercise in
                                ResumeExerciseCard(
                                    exercise: exercise,
                                    onLogSet: {
                                        currentExerciseIndex = index
                                        showingSetLogger = true
                                    },
                                    onSkip: {
                                        skipExercise(at: index)
                                    }
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        
                        // Bottom bar
                        HStack {
                            Button(action: { if currentExerciseIndex > 0 { currentExerciseIndex -= 1 } }) {
                                Image(systemName: "chevron.left").font(.title2)
                            }
                            .disabled(currentExerciseIndex == 0)
                            
                            Spacer()
                            Text("\(currentExerciseIndex + 1) / \(session.exercises.count)")
                                .font(.headline)
                            Spacer()
                            
                            if currentExerciseIndex == session.exercises.count - 1 {
                                Button("Finish") { showingEndAlert = true }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Button(action: { currentExerciseIndex += 1 }) {
                                    Image(systemName: "chevron.right").font(.title2)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("No Active Session", systemImage: "figure.run", description: Text("Start a workout from Programs"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingEndAlert = true } label: {
                        Image(systemName: "xmark").fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.restTimeRemaining > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(formatRestTime(viewModel.restTimeRemaining))
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .sheet(isPresented: $showingSetLogger) {
                if let session = persistedSession, currentExerciseIndex < session.exercises.count {
                    ResumeSetLoggerSheet(
                        exercise: session.exercises[currentExerciseIndex],
                        onSave: { weight, reps, rpe in
                            logSet(weight: weight, reps: reps, rpe: rpe)
                            showingSetLogger = false
                        }
                    )
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("End Workout?", isPresented: $showingEndAlert) {
                Button("Continue", role: .cancel) { }
                Button("Save & End") {
                    Task {
                        await endWorkout()
                        dismiss()
                    }
                }
                Button("Discard", role: .destructive) {
                    discardWorkout()
                    dismiss()
                }
            }
        }
        .onAppear {
            loadPersistedSession()
        }
    }
    
    private func loadPersistedSession() {
        persistedSession = WorkoutPersistence.shared.loadSession()
        if let session = persistedSession {
            currentExerciseIndex = session.currentExerciseIndex
        }
    }
    
    private func logSet(weight: Double, reps: Int, rpe: Int?) {
        guard var session = persistedSession else { return }
        
        let setNumber = session.exercises[currentExerciseIndex].sets.count + 1
        let newSet = PersistableSet(from: SetLog(
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            timestamp: Date(),
            rpe: rpe
        ))
        
        session.exercises[currentExerciseIndex].sets.append(newSet)
        persistedSession = session
        
        // Save to device
        saveSession()
        
        // Start rest timer (default 90s)
        viewModel.startRestTimerPublic(seconds: 90)
    }
    
    private func skipExercise(at index: Int) {
        guard var session = persistedSession else { return }
        session.exercises[index].skipped = true
        persistedSession = session
        saveSession()
    }
    
    private func saveSession() {
        guard let session = persistedSession else { return }
        // Re-save with updated data
        let data = try? JSONEncoder().encode(session)
        if let data = data {
            UserDefaults.standard.set(data, forKey: "activeWorkoutSession")
        }
        
        let totalSets = session.exercises.reduce(0) { $0 + $1.sets.count }
        WorkoutStateManager.shared.updateSets(count: totalSets)
    }
    
    private func endWorkout() async {
        guard let session = persistedSession else { return }
        
        // Convert to SessionExercise format and save to server
        let exercises = session.exercises.map { ex in
            SessionExercise(
                exerciseId: ex.exerciseId,
                exerciseName: ex.exerciseName,
                prescribedSets: ex.prescribedSets,
                prescribedReps: ex.prescribedReps,
                sets: ex.sets.map { SetLog(setNumber: $0.setNumber, weight: $0.weight, reps: $0.reps, timestamp: $0.timestamp, rpe: $0.rpe) },
                skipped: ex.skipped
            )
        }
        
        // TODO: Save to server via SessionService
        
        WorkoutStateManager.shared.sessionEnded()
    }
    
    private func discardWorkout() {
        WorkoutStateManager.shared.sessionEnded()
    }
    
    private func formatRestTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 { return String(format: "%d:%02d", mins, secs) }
        return "\(secs)s"
    }
}

// MARK: - Supporting Views

struct ResumeHeaderView: View {
    let session: PersistableSession
    @ObservedObject var viewModel: WorkoutViewModel
    
    var body: some View {
        VStack(spacing: 4) {
            Text(session.dayName)
                .font(.headline)
            
            HStack(spacing: 16) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(formatDuration(from: session.startTime, to: context.date), systemImage: "timer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ResumeExerciseCard: View {
    let exercise: PersistableExercise
    let onLogSet: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(exercise.exerciseName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    if let sets = exercise.prescribedSets {
                        Label("\(sets) sets", systemImage: "number")
                    }
                    if let reps = exercise.prescribedReps {
                        Label("\(reps) reps", systemImage: "arrow.counterclockwise")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                // Logged sets
                if !exercise.sets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logged Sets").font(.headline)
                        ForEach(exercise.sets, id: \.setNumber) { set in
                            HStack {
                                Text("Set \(set.setNumber)").fontWeight(.medium)
                                Spacer()
                                Text("\(Int(set.weight)) kg × \(set.reps)")
                                if let rpe = set.rpe {
                                    Text("@ RPE \(rpe)").foregroundStyle(.secondary)
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
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button { onSkip() } label: {
                    Text("Skip").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button { onLogSet() } label: {
                    Label("Log Set", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

struct ResumeSetLoggerSheet: View {
    let exercise: PersistableExercise
    let onSave: (Double, Int, Int?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var rpe: Int? = nil
    @State private var showRPE = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Weight
                    VStack(spacing: 8) {
                        Text("Weight (kg)").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Button { if weight >= 2.5 { weight -= 2.5 } } label: {
                                Image(systemName: "minus.circle.fill").font(.title)
                            }
                            TextField("0", value: $weight, format: .number)
                                .font(.system(size: 48, weight: .bold))
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .frame(width: 120)
                            Button { weight += 2.5 } label: {
                                Image(systemName: "plus.circle.fill").font(.title)
                            }
                        }
                    }
                    
                    // Reps
                    VStack(spacing: 8) {
                        Text("Reps").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Button { if reps > 1 { reps -= 1 } } label: {
                                Image(systemName: "minus.circle.fill").font(.title)
                            }
                            Text("\(reps)").font(.system(size: 48, weight: .bold)).frame(width: 80)
                            Button { reps += 1 } label: {
                                Image(systemName: "plus.circle.fill").font(.title)
                            }
                        }
                    }
                    
                    // RPE
                    VStack(spacing: 8) {
                        Toggle("Log RPE", isOn: $showRPE).tint(.orange)
                        if showRPE {
                            HStack(spacing: 8) {
                                ForEach(6...10, id: \.self) { value in
                                    Button { rpe = value } label: {
                                        Text("\(value)")
                                            .font(.headline)
                                            .frame(width: 44, height: 44)
                                            .background(rpe == value ? Color.orange : Color(.systemGray5))
                                            .foregroundStyle(rpe == value ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button { onSave(weight, reps, showRPE ? rpe : nil) } label: {
                    Text("Save Set").font(.headline).frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(weight <= 0 || reps <= 0)
                .padding()
            }
            .navigationTitle(exercise.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Pre-fill from last set
                if let last = exercise.sets.last {
                    weight = last.weight
                    reps = last.reps
                }
            }
        }
    }
}

#Preview {
    ResumeWorkoutView()
}
