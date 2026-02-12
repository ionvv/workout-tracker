import SwiftUI

struct SessionDetailView: View {
    @State var session: WorkoutSession
    let onUpdate: ((WorkoutSession) -> Void)?
    var program: Program?
    var allSessions: [Session]?
    
    @State private var showingEditSheet = false
    @State private var showingAIReview = false
    
    init(session: WorkoutSession, program: Program? = nil, allSessions: [Session]? = nil, onUpdate: ((WorkoutSession) -> Void)? = nil) {
        self._session = State(initialValue: session)
        self.program = program
        self.allSessions = allSessions
        self.onUpdate = onUpdate
    }
    
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
            
            // Body Weight
            if let bodyWeight = session.bodyWeight {
                Section("Body Weight") {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(.blue)
                        Text(String(format: "%.1f kg", bodyWeight))
                            .fontWeight(.medium)
                    }
                }
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
            
            // AI Coach Review
            Section {
                Button {
                    showingAIReview = true
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get AI Coach Review")
                                .fontWeight(.semibold)
                            Text("Personalized feedback & recommendations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.dayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            SessionEditView(session: $session) { updatedSession in
                session = updatedSession
                onUpdate?(updatedSession)
                
                // Save to storage
                Task {
                    LocalStorageService.shared.updateSession(updatedSession)
                    try? await SessionService.shared.updateSessionOnServer(updatedSession)
                }
            }
        }
        .sheet(isPresented: $showingAIReview) {
            if let convertedSession = convertToSession(session) {
                AIReviewView(
                    session: convertedSession,
                    program: program,
                    allSessions: allSessions ?? []
                )
            }
        }
    }
    
    /// Convert WorkoutSession to Session for AI review
    private func convertToSession(_ workoutSession: WorkoutSession) -> Session? {
        Session(
            id: workoutSession.dbId,
            odid: workoutSession.odid,
            userId: workoutSession.userId,
            sessionId: workoutSession.sessionId,
            programId: workoutSession.programId,
            dayId: workoutSession.dayId,
            dayName: workoutSession.dayName,
            startedAt: ISO8601DateFormatter().string(from: workoutSession.startTime),
            completedAt: workoutSession.endTime.map { ISO8601DateFormatter().string(from: $0) },
            durationMinutes: workoutSession.duration,
            exercises: workoutSession.exercises.map { exercise in
                SessionExerciseData(
                    odid: nil,
                    odidSession: nil,
                    odidExercise: nil,
                    exerciseId: exercise.exerciseId,
                    exerciseName: exercise.exerciseName,
                    prescribedSets: nil,
                    prescribedReps: nil,
                    prescribedWeight: nil,
                    notes: nil,
                    skipped: exercise.skipped,
                    sets: exercise.sets.map { set in
                        SetLog(
                            odid: nil,
                            odidSessionExercise: nil,
                            setNumber: set.setNumber,
                            weight: set.weight,
                            reps: set.reps,
                            rpe: set.rpe,
                            completed: true,
                            notes: nil,
                            completedAt: nil
                        )
                    }
                )
            },
            notes: workoutSession.notes,
            totalVolume: workoutSession.totalVolume,
            bodyWeight: workoutSession.bodyWeight,
            createdAt: workoutSession.createdAt.map { ISO8601DateFormatter().string(from: $0) },
            updatedAt: workoutSession.updatedAt.map { ISO8601DateFormatter().string(from: $0) },
            syncStatus: nil
        )
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
            dbId: UUID(),
            odid: nil,
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
