import SwiftUI

/// View for displaying AI workout review
struct AIReviewView: View {
    let session: WorkoutSession
    let program: Program?
    let allSessions: [WorkoutSession]
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var reviewState: ReviewState = .checking
    @State private var reviewText: String = ""
    @State private var reviewId: String?
    @State private var reviewsRemaining: Int = 0
    @State private var errorMessage: String?
    @State private var showingFollowUp = false
    @State private var showingUpgrade = false
    @State private var followUpQuestion = ""
    @State private var followUpAnswer: String?
    @State private var isAskingFollowUp = false
    
    enum ReviewState {
        case checking
        case notPro
        case limitReached(resetsAt: String)
        case ready(remaining: Int)
        case loading
        case success
        case error(String)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch reviewState {
                    case .checking:
                        checkingView
                        
                    case .notPro:
                        notProView
                        
                    case .limitReached(let resetsAt):
                        limitReachedView(resetsAt: resetsAt)
                        
                    case .ready(let remaining):
                        readyView(remaining: remaining)
                        
                    case .loading:
                        loadingView
                        
                    case .success:
                        successView
                        
                    case .error(let message):
                        errorView(message: message)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Coach Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await checkStatus()
        }
    }
    
    // MARK: - State Views
    
    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking PRO status...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    private var notProView: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("PRO Feature")
                .font(.title)
                .fontWeight(.bold)
            
            Text("AI Coach Reviews are available for PRO members. Get personalized feedback and recommendations after every workout.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                featureRow("Personalized workout analysis")
                featureRow("Progressive overload suggestions")
                featureRow("Comparison with previous sessions")
                featureRow("Follow-up questions")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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
        .sheet(isPresented: $showingUpgrade) {
            ProUpgradeView()
        }
    }
    
    private func limitReachedView(resetsAt: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Monthly Limit Reached")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You've used all your AI reviews for this month.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            if !resetsAt.isEmpty {
                Text("Resets: \(formatDate(resetsAt))")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private func readyView(remaining: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Get AI Coach Review")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Arnold will analyze your workout and provide personalized feedback and recommendations.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("\(remaining) reviews remaining this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
            
            Button {
                Task {
                    await getReview()
                }
            } label: {
                Label("Get Review (1 credit)", systemImage: "sparkles")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "brain")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }
            
            Text("Analyzing your workout...")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                loadingStep("Comparing with last session", delay: 0)
                loadingStep("Checking progressive overload", delay: 1)
                loadingStep("Analyzing RPE trends", delay: 2)
                loadingStep("Generating recommendations", delay: 3)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading) {
                    Text("Arnold - AI Coach")
                        .font(.headline)
                    Text(session.dayName ?? "Workout Review")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(reviewsRemaining) left")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Review content
            Text(reviewText)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Follow-up answer if any
            if let answer = followUpAnswer {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Follow-up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(followUpQuestion)
                        .font(.subheadline)
                        .italic()
                    
                    Text(answer)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Divider()
            
            // Actions
            HStack {
                Button {
                    showingFollowUp = true
                } label: {
                    Label("Ask Follow-up", systemImage: "text.bubble")
                }
                .buttonStyle(.bordered)
                .disabled(reviewsRemaining <= 0)
                
                Spacer()
                
                ShareLink(item: reviewText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingFollowUp) {
            followUpSheet
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                Task {
                    await checkStatus()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Follow-up Sheet
    
    private var followUpSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Ask Arnold a question about your workout or the review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: $followUpQuestion)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                if isAskingFollowUp {
                    ProgressView("Arnold is thinking...")
                }
            }
            .padding()
            .navigationTitle("Ask Arnold")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingFollowUp = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ask") {
                        Task {
                            await askFollowUp()
                        }
                    }
                    .disabled(followUpQuestion.isEmpty || isAskingFollowUp)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Views
    
    private func featureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
        }
    }
    
    private func loadingStep(_ text: String, delay: Int) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
            Text(text)
        }
    }
    
    // MARK: - Actions
    
    private func checkStatus() async {
        reviewState = .checking
        
        // First check StoreKit for local PRO status
        await storeKit.updatePurchasedProducts()
        
        if !storeKit.isPro {
            reviewState = .notPro
            return
        }
        
        // Then check backend for usage limits
        let status = await AIReviewService.shared.checkStatus()
        
        if let error = status.error {
            switch error {
            case .proRequired:
                // StoreKit says PRO but backend doesn't know yet - sync it
                reviewState = .ready(remaining: 175)
            case .limitReached(let resetsAt):
                reviewState = .limitReached(resetsAt: resetsAt)
            case .networkError(let msg), .serverError(let msg):
                reviewState = .error(msg)
            case .unauthorized:
                reviewState = .error("Please log in again")
            }
        } else {
            reviewState = .ready(remaining: status.reviewsRemaining)
        }
    }
    
    private func getReview() async {
        reviewState = .loading
        
        let result = await AIReviewService.shared.getReview(
            for: session,
            program: program,
            allSessions: allSessions
        )
        
        if let error = result.error {
            switch error {
            case .proRequired:
                reviewState = .notPro
            case .limitReached(let resetsAt):
                reviewState = .limitReached(resetsAt: resetsAt)
            case .networkError(let msg), .serverError(let msg):
                reviewState = .error(msg)
            case .unauthorized:
                reviewState = .error("Please log in again")
            }
        } else {
            reviewText = result.review
            reviewId = result.reviewId
            reviewsRemaining = result.reviewsRemaining
            reviewState = .success
        }
    }
    
    private func askFollowUp() async {
        guard let reviewId = reviewId else { return }
        
        isAskingFollowUp = true
        
        let result = await AIReviewService.shared.askFollowUp(
            question: followUpQuestion,
            reviewId: reviewId,
            session: session,
            program: program,
            allSessions: allSessions
        )
        
        isAskingFollowUp = false
        
        if result.error == nil {
            followUpAnswer = result.answer
            reviewsRemaining = result.reviewsRemaining
            showingFollowUp = false
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - Review History View

struct AIReviewHistoryView: View {
    @State private var reviews: [SavedReview] = []
    @State private var isLoading = true
    @State private var selectedReview: SavedReview?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading reviews...")
            } else if reviews.isEmpty {
                ContentUnavailableView(
                    "No Reviews Yet",
                    systemImage: "brain.head.profile",
                    description: Text("Your AI coach reviews will appear here")
                )
            } else {
                List(reviews) { review in
                    Button {
                        selectedReview = review
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(review.workoutDayName ?? "Workout")
                                    .font(.headline)
                                Spacer()
                                Text(formatDate(review.workoutDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(review.reviewText.prefix(100) + "...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Review History")
        .task {
            reviews = await AIReviewService.shared.getReviewHistory()
            isLoading = false
        }
        .sheet(item: $selectedReview) { review in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(review.workoutDayName ?? "Workout")
                                .font(.headline)
                            Spacer()
                            Text(formatDate(review.workoutDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        Text(review.reviewText)
                            .font(.body)
                            .lineSpacing(4)
                        
                        if let followUps = review.followUps, !followUps.isEmpty {
                            Divider()
                            
                            ForEach(followUps, id: \.timestamp) { followUp in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Q: \(followUp.question)")
                                        .font(.subheadline)
                                        .italic()
                                    Text(followUp.answer)
                                        .font(.body)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            selectedReview = nil
                        }
                    }
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}
