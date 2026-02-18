import SwiftUI

struct SessionDetailView: View {
    @State var session: WorkoutSession
    let onUpdate: ((WorkoutSession) -> Void)?
    let onDelete: (() -> Void)?
    var program: Program?
    var allSessions: [WorkoutSession]?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingAIReview = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    init(session: WorkoutSession, program: Program? = nil, allSessions: [WorkoutSession]? = nil, onUpdate: ((WorkoutSession) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self._session = State(initialValue: session)
        self.program = program
        self.allSessions = allSessions
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Workout?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text("This will delete the workout from the app and Apple Health. This cannot be undone.")
        }
        .disabled(isDeleting)
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
            AIReviewView(
                session: session,
                program: program,
                allSessions: allSessions ?? []
            )
        }
    }
    
    private func deleteWorkout() {
        isDeleting = true
        
        Task {
            // Delete from local storage
            LocalStorageService.shared.deleteSession(session.sessionId)
            
            // Delete from server
            try? await SessionService.shared.deleteSessionFromServer(session.sessionId)
            
            // Delete from HealthKit
            await SessionService.shared.deleteFromHealthKit(session: session)
            
            await MainActor.run {
                onDelete?()
                dismiss()
            }
        }
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
