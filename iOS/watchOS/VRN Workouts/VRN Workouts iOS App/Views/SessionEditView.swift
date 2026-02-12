import SwiftUI

struct SessionEditView: View {
    @Binding var session: WorkoutSession
    let onSave: (WorkoutSession) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [SessionExercise]
    @State private var notes: String
    @State private var bodyWeight: String
    @State private var isSaving = false
    
    init(session: Binding<WorkoutSession>, onSave: @escaping (WorkoutSession) -> Void) {
        self._session = session
        self.onSave = onSave
        self._exercises = State(initialValue: session.wrappedValue.exercises)
        self._notes = State(initialValue: session.wrappedValue.notes ?? "")
        self._bodyWeight = State(initialValue: session.wrappedValue.bodyWeight.map { String(format: "%.1f", $0) } ?? "")
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Body Weight
                Section("Body Weight") {
                    HStack {
                        TextField("Not logged", text: $bodyWeight)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // Exercises
                ForEach(exercises.indices, id: \.self) { exerciseIndex in
                    let isTimed = isTimedExercise(exercises[exerciseIndex].exerciseName)
                    Section(exercises[exerciseIndex].exerciseName) {
                        ForEach(exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in
                            EditableSetRow(
                                set: $exercises[exerciseIndex].sets[setIndex],
                                isTimed: isTimed,
                                onDelete: {
                                    exercises[exerciseIndex].sets.remove(at: setIndex)
                                    renumberSets(exerciseIndex: exerciseIndex)
                                }
                            )
                        }
                        
                        Button {
                            addSet(to: exerciseIndex)
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func addSet(to exerciseIndex: Int) {
        let lastSet = exercises[exerciseIndex].sets.last
        let newSetNumber = (lastSet?.setNumber ?? 0) + 1
        let newSet = SetLog(
            setNumber: newSetNumber,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 8,
            timestamp: Date(),
            rpe: nil
        )
        exercises[exerciseIndex].sets.append(newSet)
    }
    
    private func renumberSets(exerciseIndex: Int) {
        for i in exercises[exerciseIndex].sets.indices {
            // Create new SetLog with updated setNumber
            let oldSet = exercises[exerciseIndex].sets[i]
            exercises[exerciseIndex].sets[i] = SetLog(
                setNumber: i + 1,
                weight: oldSet.weight,
                reps: oldSet.reps,
                timestamp: oldSet.timestamp,
                rpe: oldSet.rpe
            )
        }
    }
    
    private func isTimedExercise(_ name: String) -> Bool {
        let timedKeywords = ["plank", "hold", "hang", "wall sit", "l-sit", "dead hang"]
        let nameLower = name.lowercased()
        return timedKeywords.contains { nameLower.contains($0) }
    }
    
    private func saveChanges() {
        isSaving = true
        
        // Update session with edited values
        var updatedSession = session
        updatedSession.exercises = exercises
        updatedSession.notes = notes.isEmpty ? nil : notes
        updatedSession.bodyWeight = Double(bodyWeight)
        
        // Recalculate stats
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let totalVolume = exercises.reduce(0) { total, ex in
            total + ex.sets.reduce(0) { exTotal, set in
                exTotal + Int(set.weight * Double(set.reps))
            }
        }
        updatedSession.totalSets = totalSets
        updatedSession.totalVolume = totalVolume
        updatedSession.updatedAt = Date()
        
        onSave(updatedSession)
        dismiss()
    }
}

struct EditableSetRow: View {
    @Binding var set: SetLog
    var isTimed: Bool = false
    let onDelete: () -> Void
    
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpe: Int?
    
    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.subheadline)
                .frame(width: 50, alignment: .leading)
            
            if isTimed {
                // Timed exercise: just show seconds
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: repsText) { _, newValue in
                        if let reps = Int(newValue) {
                            updateSet(reps: reps)
                        }
                    }
                
                Text("sec")
                    .foregroundStyle(.secondary)
            } else {
                // Regular exercise: weight × reps
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: weightText) { _, newValue in
                        if let weight = Double(newValue) {
                            updateSet(weight: weight)
                        }
                    }
                
                Text("kg ×")
                    .foregroundStyle(.secondary)
                
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: repsText) { _, newValue in
                        if let reps = Int(newValue) {
                            updateSet(reps: reps)
                        }
                    }
            }
            
            Spacer()
            
            // RPE picker
            Menu {
                Button("None") { 
                    rpe = nil
                    updateSet(rpe: nil)
                }
                ForEach(6...10, id: \.self) { value in
                    Button("RPE \(value)") { 
                        rpe = value
                        updateSet(rpe: value)
                    }
                }
            } label: {
                if let rpe = rpe {
                    Text("RPE \(rpe)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Delete
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            weightText = String(format: "%.1f", set.weight)
            repsText = "\(set.reps)"
            rpe = set.rpe
        }
    }
    
    private func updateSet(weight: Double? = nil, reps: Int? = nil, rpe: Int?? = nil) {
        set = SetLog(
            setNumber: set.setNumber,
            weight: weight ?? set.weight,
            reps: reps ?? set.reps,
            timestamp: set.timestamp,
            rpe: rpe == nil ? set.rpe : rpe!
        )
    }
}

#Preview {
    SessionEditView(
        session: .constant(WorkoutSession(
            dbId: UUID(),
            odid: nil,
            userId: UUID(),
            sessionId: "test",
            programId: "prog1",
            dayId: "day1",
            dayName: "Day A",
            startTime: Date(),
            endTime: Date(),
            exercises: [
                SessionExercise(
                    exerciseId: "ex1",
                    exerciseName: "Bench Press",
                    prescribedSets: 4,
                    prescribedReps: "8-10",
                    sets: [
                        SetLog(setNumber: 1, weight: 60, reps: 10, timestamp: Date(), rpe: 7),
                        SetLog(setNumber: 2, weight: 60, reps: 9, timestamp: Date(), rpe: 8)
                    ],
                    skipped: false
                )
            ],
            notes: "Good session",
            totalVolume: 1140,
            totalSets: 2,
            duration: 45,
            createdAt: Date(),
            updatedAt: Date()
        )),
        onSave: { _ in }
    )
}
