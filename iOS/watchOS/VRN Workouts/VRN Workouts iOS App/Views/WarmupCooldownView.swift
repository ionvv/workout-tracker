import SwiftUI

enum WorkoutPhase: String, CaseIterable {
    case warmup = "Warm-up"
    case workout = "Workout"
    case cooldown = "Cool-down"
}

// MARK: - Warmup/Cooldown Section View

struct WarmupCooldownSectionView: View {
    let title: String
    let section: WarmupCooldown
    let onComplete: () -> Void
    
    @State private var completedExercises: Set<String> = []
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let duration = section.duration {
                    Text("~\(duration) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Progress
                if let exercises = section.exercises, !exercises.isEmpty {
                    Text("\(completedExercises.count)/\(exercises.count) complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            // Exercise list
            if let exercises = section.exercises, !exercises.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(exercises.enumerated()), id: \.element.name) { index, exercise in
                            WarmupExerciseCard(
                                exercise: exercise,
                                isCompleted: completedExercises.contains(exercise.name),
                                onToggle: {
                                    if completedExercises.contains(exercise.name) {
                                        completedExercises.remove(exercise.name)
                                    } else {
                                        completedExercises.insert(exercise.name)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "figure.flexibility",
                    description: Text("This section has no exercises defined")
                )
            }
            
            Spacer()
            
            // Complete button
            Button {
                onComplete()
            } label: {
                Text(completedExercises.count == (section.exercises?.count ?? 0) ? "Continue to Workout" : "Skip \(title)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(completedExercises.count == (section.exercises?.count ?? 0) ? .green : .gray)
            .padding()
        }
    }
}

// MARK: - Warmup Exercise Card

struct WarmupExerciseCard: View {
    let exercise: WarmupExercise
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isCompleted ? .green : .secondary)
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                    
                    HStack(spacing: 12) {
                        if let duration = exercise.duration {
                            Label("\(duration)s", systemImage: "timer")
                        }
                        if let reps = exercise.reps {
                            Label("\(reps) reps", systemImage: "arrow.counterclockwise")
                        }
                        if let sets = exercise.sets {
                            Label("\(sets) sets", systemImage: "number")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    if let notes = exercise.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Phase Indicator

struct WorkoutPhaseIndicator: View {
    let currentPhase: WorkoutPhase
    let hasWarmup: Bool
    let hasCooldown: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if hasWarmup {
                PhaseChip(
                    title: "Warm-up",
                    isActive: currentPhase == .warmup,
                    isCompleted: currentPhase == .workout || currentPhase == .cooldown
                )
            }
            
            PhaseChip(
                title: "Workout",
                isActive: currentPhase == .workout,
                isCompleted: currentPhase == .cooldown
            )
            
            if hasCooldown {
                PhaseChip(
                    title: "Cool-down",
                    isActive: currentPhase == .cooldown,
                    isCompleted: false
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct PhaseChip: View {
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.blue.opacity(0.2) : Color(.systemGray5))
        .foregroundStyle(isActive ? .blue : .secondary)
        .cornerRadius(16)
    }
}

#Preview {
    WarmupCooldownSectionView(
        title: "Warm-up",
        section: WarmupCooldown(
            duration: 10,
            exercises: [
                WarmupExercise(name: "Jumping Jacks", duration: 60, reps: nil, sets: nil, notes: "Get the blood flowing"),
                WarmupExercise(name: "Arm Circles", duration: 30, reps: nil, sets: nil, notes: nil),
                WarmupExercise(name: "Leg Swings", duration: nil, reps: 10, sets: 2, notes: "Each leg")
            ]
        ),
        onComplete: {}
    )
}
