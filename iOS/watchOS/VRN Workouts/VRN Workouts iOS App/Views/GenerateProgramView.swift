import SwiftUI

/// AI-powered workout program generator (PRO feature)
struct GenerateProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    
    // Questionnaire state
    @State private var currentStep = 0
    @State private var goal: FitnessGoal = .muscleGain
    @State private var daysPerWeek = 3
    @State private var experience: ExperienceLevel = .intermediate
    @State private var equipment: EquipmentType = .fullGym
    @State private var sessionLength = 60
    @State private var injuries = ""
    @State private var preferences = ""
    
    // Generation state
    @State private var isGenerating = false
    @State private var generatedProgram: Program?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingUpgrade = false
    @State private var reviewsRemaining = 0
    
    let onProgramGenerated: (Program) -> Void
    
    private let totalSteps = 6
    
    var body: some View {
        NavigationStack {
            Group {
                if !storeKit.isPro {
                    proRequiredView
                } else if isGenerating {
                    generatingView
                } else if let program = generatedProgram {
                    programPreviewView(program)
                } else {
                    questionnaireView
                }
            }
            .navigationTitle("Generate Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
            .sheet(isPresented: $showingUpgrade) {
                ProUpgradeView()
            }
        }
        .task {
            await checkCredits()
        }
    }
    
    // MARK: - PRO Required View
    
    private var proRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("AI Program Generator")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Let Arnold create a personalized workout program tailored to your goals, schedule, and equipment.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                showingUpgrade = true
            } label: {
                Text("Upgrade to PRO")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    // MARK: - Questionnaire View
    
    private var questionnaireView: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .padding()
            
            // Credits remaining
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("\(reviewsRemaining) credits remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
            
            // Question content
            TabView(selection: $currentStep) {
                goalStep.tag(0)
                daysStep.tag(1)
                experienceStep.tag(2)
                equipmentStep.tag(3)
                sessionLengthStep.tag(4)
                additionalInfoStep.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation {
                            currentStep -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < totalSteps - 1 {
                    Button {
                        withAnimation {
                            currentStep += 1
                        }
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task {
                            await generateProgram()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Program")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(reviewsRemaining <= 0)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Question Steps
    
    private var goalStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "target",
                title: "What's your main goal?",
                subtitle: "This determines your training style and rep ranges"
            )
            
            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.self) { g in
                    SelectionButton(
                        title: g.title,
                        subtitle: g.subtitle,
                        icon: g.icon,
                        isSelected: goal == g
                    ) {
                        goal = g
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var daysStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "calendar",
                title: "How many days per week?",
                subtitle: "Be realistic - consistency beats intensity"
            )
            
            HStack(spacing: 12) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { days in
                    Button {
                        daysPerWeek = days
                    } label: {
                        Text("\(days)")
                            .font(.title)
                            .fontWeight(.bold)
                            .frame(width: 56, height: 56)
                            .background(daysPerWeek == days ? Color.blue : Color(.secondarySystemBackground))
                            .foregroundStyle(daysPerWeek == days ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
            
            Text(daysDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    private var daysDescription: String {
        switch daysPerWeek {
        case 2: return "Full body workouts, great for beginners or busy schedules"
        case 3: return "Perfect balance - full body or push/pull/legs"
        case 4: return "Upper/lower split or push/pull with extra focus days"
        case 5: return "More volume per muscle group, good for intermediates"
        case 6: return "High frequency, best for advanced lifters"
        default: return ""
        }
    }
    
    private var experienceStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "figure.strengthtraining.traditional",
                title: "What's your experience level?",
                subtitle: "This affects exercise selection and volume"
            )
            
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    SelectionButton(
                        title: level.title,
                        subtitle: level.subtitle,
                        icon: level.icon,
                        isSelected: experience == level
                    ) {
                        experience = level
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var equipmentStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "dumbbell.fill",
                title: "What equipment do you have?",
                subtitle: "We'll design exercises around your setup"
            )
            
            VStack(spacing: 12) {
                ForEach(EquipmentType.allCases, id: \.self) { eq in
                    SelectionButton(
                        title: eq.title,
                        subtitle: eq.subtitle,
                        icon: eq.icon,
                        isSelected: equipment == eq
                    ) {
                        equipment = eq
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var sessionLengthStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "clock",
                title: "How long per session?",
                subtitle: "Including warmup and cooldown"
            )
            
            HStack(spacing: 12) {
                ForEach([30, 45, 60, 90], id: \.self) { mins in
                    Button {
                        sessionLength = mins
                    } label: {
                        VStack {
                            Text("\(mins)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("min")
                                .font(.caption)
                        }
                        .frame(width: 70, height: 70)
                        .background(sessionLength == mins ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundStyle(sessionLength == mins ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var additionalInfoStep: some View {
        VStack(spacing: 24) {
            questionHeader(
                icon: "info.circle",
                title: "Anything else Arnold should know?",
                subtitle: "Optional but helps personalize your program"
            )
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Injuries or limitations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g., bad lower back, knee issues", text: $injuries)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences or requests")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g., love deadlifts, hate burpees", text: $preferences)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Generating View
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "brain")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            
            Text("Arnold is building your program...")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                generatingStep("Analyzing your goals")
                generatingStep("Selecting exercises")
                generatingStep("Balancing volume")
                generatingStep("Adding warmup & cooldown")
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private func generatingStep(_ text: String) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
            Text(text)
        }
    }
    
    // MARK: - Program Preview
    
    private func programPreviewView(_ program: Program) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    
                    Text("Program Created!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(program.programName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                // Days overview
                ForEach(program.days, id: \.dayId) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.dayName)
                            .font(.headline)
                        
                        ForEach(day.exerciseList, id: \.id) { exercise in
                            HStack {
                                Text("•")
                                Text(exercise.name)
                                Spacer()
                                Text("\(exercise.sets)×\(exercise.reps)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        onProgramGenerated(program)
                        dismiss()
                    } label: {
                        Text("Save Program")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        generatedProgram = nil
                        currentStep = 0
                    } label: {
                        Text("Generate Another")
                    }
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    // MARK: - Helpers
    
    private func questionHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Actions
    
    private func checkCredits() async {
        let status = await AIReviewService.shared.checkStatus()
        reviewsRemaining = status.reviewsRemaining
    }
    
    private func generateProgram() async {
        isGenerating = true
        
        let profile = ProfileService.shared.getProfile()
        
        let result = await AIProgramGenerator.shared.generateProgram(
            goal: goal,
            daysPerWeek: daysPerWeek,
            experience: experience,
            equipment: equipment,
            sessionLength: sessionLength,
            injuries: injuries.isEmpty ? nil : injuries,
            preferences: preferences.isEmpty ? nil : preferences,
            weight: profile.weight,
            height: profile.height,
            age: profile.age,
            gender: profile.gender
        )
        
        isGenerating = false
        
        if let error = result.error {
            errorMessage = error
            showingError = true
        } else if let program = result.program {
            generatedProgram = program
            reviewsRemaining = result.remainingCredits
        }
    }
}

// MARK: - Selection Button

struct SelectionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(isSelected ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enums

enum FitnessGoal: String, CaseIterable {
    case muscleGain = "muscle_gain"
    case fatLoss = "fat_loss"
    case strength = "strength"
    case recomp = "recomp"
    case generalFitness = "general_fitness"
    
    var title: String {
        switch self {
        case .muscleGain: return "Build Muscle"
        case .fatLoss: return "Lose Fat"
        case .strength: return "Get Stronger"
        case .recomp: return "Recomposition"
        case .generalFitness: return "General Fitness"
        }
    }
    
    var subtitle: String {
        switch self {
        case .muscleGain: return "Hypertrophy-focused, higher volume"
        case .fatLoss: return "Calorie burn, maintain muscle"
        case .strength: return "Heavy weights, lower reps"
        case .recomp: return "Lose fat while building muscle"
        case .generalFitness: return "Balanced health and fitness"
        }
    }
    
    var icon: String {
        switch self {
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .fatLoss: return "flame.fill"
        case .strength: return "scalemass.fill"
        case .recomp: return "arrow.triangle.2.circlepath"
        case .generalFitness: return "heart.fill"
        }
    }
}

enum ExperienceLevel: String, CaseIterable {
    case beginner
    case intermediate
    case advanced
    
    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    var subtitle: String {
        switch self {
        case .beginner: return "Less than 1 year of consistent training"
        case .intermediate: return "1-3 years, familiar with compound lifts"
        case .advanced: return "3+ years, ready for advanced techniques"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "star.fill"
        case .advanced: return "crown.fill"
        }
    }
}

enum EquipmentType: String, CaseIterable {
    case fullGym = "full_gym"
    case homeGym = "home_gym"
    case bodyweight = "bodyweight"
    
    var title: String {
        switch self {
        case .fullGym: return "Full Gym"
        case .homeGym: return "Home Gym"
        case .bodyweight: return "Bodyweight Only"
        }
    }
    
    var subtitle: String {
        switch self {
        case .fullGym: return "All machines, barbells, cables, etc."
        case .homeGym: return "Dumbbells, bench, maybe a rack"
        case .bodyweight: return "No equipment needed"
        }
    }
    
    var icon: String {
        switch self {
        case .fullGym: return "building.2.fill"
        case .homeGym: return "house.fill"
        case .bodyweight: return "figure.stand"
        }
    }
}

#Preview {
    GenerateProgramView { _ in }
}
