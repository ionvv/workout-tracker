import SwiftUI

// MARK: - Program Editor

struct ProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var programName: String
    @State private var workoutDays: [EditableWorkoutDay]
    @State private var showingAddDay = false
    @State private var isSaving = false
    
    let program: Program?
    let onSave: (Program) -> Void
    
    init(program: Program? = nil, onSave: @escaping (Program) -> Void) {
        self.program = program
        self.onSave = onSave
        _programName = State(initialValue: program?.programName ?? "")
        _workoutDays = State(initialValue: program?.days.map { EditableWorkoutDay(from: $0) } ?? [])
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Program Name") {
                    TextField("e.g., Push Pull Legs", text: $programName)
                }
                
                Section("Workout Days") {
                    if workoutDays.isEmpty {
                        Text("No workout days yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($workoutDays) { $day in
                            NavigationLink {
                                DayEditorView(day: $day)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.dayName)
                                        .font(.headline)
                                    Text("\(day.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteDay)
                        .onMove(perform: moveDay)
                    }
                    
                    Button {
                        showingAddDay = true
                    } label: {
                        Label("Add Workout Day", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(program == nil ? "New Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProgram()
                    }
                    .disabled(programName.isEmpty || isSaving)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddDay) {
                AddDaySheet { dayName in
                    let newDay = EditableWorkoutDay(
                        dayId: UUID().uuidString,
                        dayName: dayName,
                        exercises: []
                    )
                    workoutDays.append(newDay)
                }
            }
        }
    }
    
    private func deleteDay(at offsets: IndexSet) {
        workoutDays.remove(atOffsets: offsets)
    }
    
    private func moveDay(from source: IndexSet, to destination: Int) {
        workoutDays.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveProgram() {
        isSaving = true
        
        let newProgram = Program(
            dbId: program?.dbId,
            userId: program?.userId,
            programId: program?.programId ?? UUID().uuidString,
            programName: programName,
            workoutDays: workoutDays.map { $0.toWorkoutDay() },
            createdAt: program?.createdAt,
            updatedAt: nil
        )
        
        onSave(newProgram)
        dismiss()
    }
}

// MARK: - Day Editor

struct DayEditorView: View {
    @Binding var day: EditableWorkoutDay
    @State private var showingAddExercise = false
    
    var body: some View {
        Form {
            Section("Day Name") {
                TextField("e.g., Push Day", text: $day.dayName)
            }
            
            Section("Exercises") {
                if day.exercises.isEmpty {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($day.exercises) { $exercise in
                        NavigationLink {
                            ExerciseEditorView(exercise: $exercise)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text("\(exercise.sets) sets × \(exercise.reps)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)
                }
                
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            }
            
            Section("Warmup (Optional)") {
                NavigationLink {
                    WarmupEditorView(warmup: $day.warmup)
                } label: {
                    HStack {
                        Text("Warmup")
                        Spacer()
                        Text("\(day.warmup?.exercises.count ?? 0) exercises")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Cooldown (Optional)") {
                NavigationLink {
                    CooldownEditorView(cooldown: $day.cooldown)
                } label: {
                    HStack {
                        Text("Cooldown")
                        Spacer()
                        Text("\(day.cooldown?.exercises.count ?? 0) exercises")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(day.dayName.isEmpty ? "New Day" : day.dayName)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet { name, sets, reps, rest in
                let newExercise = EditableExercise(
                    exerciseId: UUID().uuidString,
                    name: name,
                    sets: sets,
                    reps: reps,
                    rest: rest
                )
                day.exercises.append(newExercise)
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        day.exercises.remove(atOffsets: offsets)
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        day.exercises.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Exercise Editor

struct ExerciseEditorView: View {
    @Binding var exercise: EditableExercise
    
    var body: some View {
        Form {
            Section("Exercise Name") {
                TextField("e.g., Barbell Bench Press", text: $exercise.name)
            }
            
            Section("Sets & Reps") {
                Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...10)
                TextField("Reps (e.g., 8-10)", text: $exercise.reps)
            }
            
            Section("Rest Time") {
                Stepper("Rest: \(exercise.rest)s", value: $exercise.rest, in: 30...300, step: 15)
            }
            
            Section("Target RPE (Optional)") {
                Picker("RPE", selection: $exercise.rpe) {
                    Text("None").tag(nil as Int?)
                    ForEach(6...10, id: \.self) { value in
                        Text("\(value)").tag(value as Int?)
                    }
                }
            }
            
            Section("Form Cues (Optional)") {
                ForEach(exercise.formCues.indices, id: \.self) { index in
                    TextField("Cue \(index + 1)", text: $exercise.formCues[index])
                }
                .onDelete { offsets in
                    exercise.formCues.remove(atOffsets: offsets)
                }
                
                Button("Add Cue") {
                    exercise.formCues.append("")
                }
            }
        }
        .navigationTitle(exercise.name.isEmpty ? "New Exercise" : exercise.name)
    }
}

// MARK: - Warmup/Cooldown Editors

struct WarmupEditorView: View {
    @Binding var warmup: EditableWarmupCooldown?
    @State private var exercises: [EditableWarmupExercise] = []
    
    var body: some View {
        Form {
            Section("Warmup Exercises") {
                if exercises.isEmpty {
                    Text("No warmup exercises")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($exercises) { $ex in
                        VStack(alignment: .leading) {
                            TextField("Name", text: $ex.name)
                            HStack {
                                TextField("Duration (s)", value: $ex.duration, format: .number)
                                    .keyboardType(.numberPad)
                                TextField("Reps", value: $ex.reps, format: .number)
                                    .keyboardType(.numberPad)
                            }
                            .font(.caption)
                        }
                    }
                    .onDelete { offsets in
                        exercises.remove(atOffsets: offsets)
                        updateWarmup()
                    }
                }
                
                Button("Add Exercise") {
                    exercises.append(EditableWarmupExercise(name: "", duration: 30, reps: nil))
                    updateWarmup()
                }
            }
        }
        .navigationTitle("Warmup")
        .onAppear {
            exercises = warmup?.exercises ?? []
        }
        .onChange(of: exercises) { _, _ in
            updateWarmup()
        }
    }
    
    private func updateWarmup() {
        if exercises.isEmpty {
            warmup = nil
        } else {
            warmup = EditableWarmupCooldown(duration: nil, exercises: exercises)
        }
    }
}

struct CooldownEditorView: View {
    @Binding var cooldown: EditableWarmupCooldown?
    @State private var exercises: [EditableWarmupExercise] = []
    
    var body: some View {
        Form {
            Section("Cooldown Exercises") {
                if exercises.isEmpty {
                    Text("No cooldown exercises")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($exercises) { $ex in
                        VStack(alignment: .leading) {
                            TextField("Name", text: $ex.name)
                            HStack {
                                TextField("Duration (s)", value: $ex.duration, format: .number)
                                    .keyboardType(.numberPad)
                                TextField("Reps", value: $ex.reps, format: .number)
                                    .keyboardType(.numberPad)
                            }
                            .font(.caption)
                        }
                    }
                    .onDelete { offsets in
                        exercises.remove(atOffsets: offsets)
                        updateCooldown()
                    }
                }
                
                Button("Add Exercise") {
                    exercises.append(EditableWarmupExercise(name: "", duration: 30, reps: nil))
                    updateCooldown()
                }
            }
        }
        .navigationTitle("Cooldown")
        .onAppear {
            exercises = cooldown?.exercises ?? []
        }
        .onChange(of: exercises) { _, _ in
            updateCooldown()
        }
    }
    
    private func updateCooldown() {
        if exercises.isEmpty {
            cooldown = nil
        } else {
            cooldown = EditableWarmupCooldown(duration: nil, exercises: exercises)
        }
    }
}

// MARK: - Add Sheets

struct AddDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dayName = ""
    let onAdd: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Day Name (e.g., Push Day)", text: $dayName)
            }
            .navigationTitle("Add Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(dayName)
                        dismiss()
                    }
                    .disabled(dayName.isEmpty)
                }
            }
        }
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sets = 3
    @State private var reps = "8-10"
    @State private var rest = 90
    let onAdd: (String, Int, String, Int) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)
                Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                TextField("Reps", text: $reps)
                Stepper("Rest: \(rest)s", value: $rest, in: 30...300, step: 15)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, sets, reps, rest)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Editable Models

struct EditableWorkoutDay: Identifiable {
    let id = UUID()
    var dayId: String
    var dayName: String
    var exercises: [EditableExercise]
    var warmup: EditableWarmupCooldown?
    var cooldown: EditableWarmupCooldown?
    
    init(dayId: String, dayName: String, exercises: [EditableExercise], warmup: EditableWarmupCooldown? = nil, cooldown: EditableWarmupCooldown? = nil) {
        self.dayId = dayId
        self.dayName = dayName
        self.exercises = exercises
        self.warmup = warmup
        self.cooldown = cooldown
    }
    
    init(from day: WorkoutDay) {
        self.dayId = day.dayId
        self.dayName = day.dayName
        self.exercises = day.exerciseList.map { EditableExercise(from: $0) }
        self.warmup = day.warmup.map { EditableWarmupCooldown(from: $0) }
        self.cooldown = day.cooldown.map { EditableWarmupCooldown(from: $0) }
    }
    
    func toWorkoutDay() -> WorkoutDay {
        WorkoutDay(
            dayId: dayId,
            dayName: dayName,
            exercises: exercises.map { $0.toExercise() },
            dayType: nil,
            estimatedTime: nil,
            warmup: warmup?.toWarmupCooldown(),
            cooldown: cooldown?.toWarmupCooldown(),
            finisher: nil,
            focusMuscles: nil,
            secondaryMuscles: nil
        )
    }
}

struct EditableExercise: Identifiable {
    let id = UUID()
    var exerciseId: String
    var name: String
    var sets: Int
    var reps: String
    var rest: Int
    var rpe: Int?
    var formCues: [String]
    
    init(exerciseId: String, name: String, sets: Int, reps: String, rest: Int, rpe: Int? = nil, formCues: [String] = []) {
        self.exerciseId = exerciseId
        self.name = name
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.rpe = rpe
        self.formCues = formCues
    }
    
    init(from exercise: Exercise) {
        self.exerciseId = exercise.exerciseId ?? UUID().uuidString
        self.name = exercise.name
        self.sets = exercise.sets
        self.reps = exercise.reps
        self.rest = exercise.rest
        self.rpe = exercise.rpe
        self.formCues = exercise.formCues ?? []
    }
    
    func toExercise() -> Exercise {
        Exercise(
            exerciseId: exerciseId,
            exerciseDbId: nil,
            name: name,
            slug: nil,
            workingSets: sets,
            repsMin: nil,
            repsMax: nil,
            restSeconds: rest,
            category: nil,
            difficulty: nil,
            rpe: rpe,
            rir: nil,
            tempo: nil,
            tempoDescription: nil,
            media: nil,
            warmupSets: nil,
            formCues: formCues.isEmpty ? nil : formCues,
            equipment: nil,
            muscleGroups: nil,
            supersetWith: nil,
            supersetType: nil,
            prescribedSets: nil,
            prescribedReps: reps,
            notes: nil,
            demoUrl: nil,
            gifUrl: nil,
            type: nil
        )
    }
}

struct EditableWarmupCooldown {
    var duration: Int?
    var exercises: [EditableWarmupExercise]
    
    init(duration: Int?, exercises: [EditableWarmupExercise]) {
        self.duration = duration
        self.exercises = exercises
    }
    
    init(from wc: WarmupCooldown) {
        self.duration = wc.duration
        self.exercises = wc.exercises?.map { EditableWarmupExercise(from: $0) } ?? []
    }
    
    func toWarmupCooldown() -> WarmupCooldown {
        WarmupCooldown(
            duration: duration,
            exercises: exercises.map { $0.toWarmupExercise() }
        )
    }
}

struct EditableWarmupExercise: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var duration: Int?
    var reps: Int?
    
    static func == (lhs: EditableWarmupExercise, rhs: EditableWarmupExercise) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.duration == rhs.duration && lhs.reps == rhs.reps
    }
    
    init(name: String, duration: Int?, reps: Int?) {
        self.name = name
        self.duration = duration
        self.reps = reps
    }
    
    init(from ex: WarmupExercise) {
        self.name = ex.name
        self.duration = ex.duration
        self.reps = ex.reps
    }
    
    func toWarmupExercise() -> WarmupExercise {
        WarmupExercise(name: name, duration: duration, reps: reps, sets: nil, notes: nil)
    }
}

#Preview {
    ProgramEditorView(onSave: { _ in })
}
