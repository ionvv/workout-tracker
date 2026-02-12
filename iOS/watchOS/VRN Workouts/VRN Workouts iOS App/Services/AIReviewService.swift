import Foundation

/// Service for AI Workout Reviews
/// Handles PRO status checks, usage tracking, and API calls
actor AIReviewService {
    static let shared = AIReviewService()
    
    private let edgeFunctionURL = "\(Config.supabaseURL)/functions/v1/ai-workout-review"
    
    private init() {}
    
    // MARK: - Check Status
    
    struct ReviewStatus {
        let isPro: Bool
        let reviewsUsed: Int
        let reviewsLimit: Int
        let reviewsRemaining: Int
        let resetsAt: String?
        let error: ReviewError?
    }
    
    enum ReviewError: Error {
        case proRequired
        case limitReached(resetsAt: String)
        case networkError(String)
        case unauthorized
        case serverError(String)
    }
    
    /// Check if user can request a review
    func checkStatus() async -> ReviewStatus {
        guard let token = await AuthService.shared.getAccessToken() else {
            return ReviewStatus(isPro: false, reviewsUsed: 0, reviewsLimit: 0, reviewsRemaining: 0, resetsAt: nil, error: .unauthorized)
        }
        
        var request = URLRequest(url: URL(string: edgeFunctionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["action": "check_status"])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    return ReviewStatus(isPro: false, reviewsUsed: 0, reviewsLimit: 0, reviewsRemaining: 0, resetsAt: nil, error: .proRequired)
                }
                if httpResponse.statusCode == 429 {
                    let json = try? JSONDecoder().decode(LimitReachedResponse.self, from: data)
                    return ReviewStatus(
                        isPro: true,
                        reviewsUsed: json?.usage.used ?? 0,
                        reviewsLimit: json?.usage.limit ?? 175,
                        reviewsRemaining: 0,
                        resetsAt: json?.usage.resetsAt,
                        error: .limitReached(resetsAt: json?.usage.resetsAt ?? "")
                    )
                }
            }
            
            let result = try JSONDecoder().decode(StatusResponse.self, from: data)
            return ReviewStatus(
                isPro: result.isPro,
                reviewsUsed: result.usage.used,
                reviewsLimit: result.usage.limit,
                reviewsRemaining: result.usage.remaining,
                resetsAt: result.usage.resetsAt,
                error: nil
            )
        } catch {
            return ReviewStatus(isPro: false, reviewsUsed: 0, reviewsLimit: 0, reviewsRemaining: 0, resetsAt: nil, error: .networkError(error.localizedDescription))
        }
    }
    
    // MARK: - Get Review
    
    struct ReviewResult {
        let review: String
        let reviewId: String?
        let reviewsRemaining: Int
        let error: ReviewError?
    }
    
    /// Request an AI review for a workout session
    func getReview(for session: WorkoutSession, program: Program?, allSessions: [WorkoutSession]) async -> ReviewResult {
        guard let token = await AuthService.shared.getAccessToken() else {
            return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .unauthorized)
        }
        
        // Build context
        let context = await buildContext(for: session, program: program, allSessions: allSessions)
        let workoutData = buildWorkoutData(for: session)
        
        let requestBody: [String: Any] = [
            "action": "get_review",
            "context": context,
            "workoutData": workoutData
        ]
        
        var request = URLRequest(url: URL(string: edgeFunctionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60 // AI responses can take time
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .proRequired)
                }
                if httpResponse.statusCode == 429 {
                    let json = try? JSONDecoder().decode(LimitReachedResponse.self, from: data)
                    return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .limitReached(resetsAt: json?.usage.resetsAt ?? ""))
                }
                if httpResponse.statusCode >= 400 {
                    let errorJson = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                    return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .serverError(errorJson?.error ?? "Unknown error"))
                }
            }
            
            let result = try JSONDecoder().decode(ReviewResponse.self, from: data)
            return ReviewResult(
                review: result.review,
                reviewId: result.reviewId,
                reviewsRemaining: result.usage.remaining,
                error: nil
            )
        } catch {
            return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .networkError(error.localizedDescription))
        }
    }
    
    // MARK: - Follow-Up Question
    
    /// Ask a follow-up question about a review
    func askFollowUp(question: String, reviewId: String, session: WorkoutSession, program: Program?, allSessions: [WorkoutSession]) async -> ReviewResult {
        guard let token = await AuthService.shared.getAccessToken() else {
            return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .unauthorized)
        }
        
        let context = await buildContext(for: session, program: program, allSessions: allSessions)
        let workoutData = buildWorkoutData(for: session)
        
        let requestBody: [String: Any] = [
            "action": "follow_up",
            "reviewId": reviewId,
            "question": question,
            "context": context,
            "workoutData": workoutData
        ]
        
        var request = URLRequest(url: URL(string: edgeFunctionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                let errorJson = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .serverError(errorJson?.error ?? "Unknown error"))
            }
            
            let result = try JSONDecoder().decode(FollowUpResponse.self, from: data)
            return ReviewResult(
                review: result.answer,
                reviewId: reviewId,
                reviewsRemaining: result.usage.remaining,
                error: nil
            )
        } catch {
            return ReviewResult(review: "", reviewId: nil, reviewsRemaining: 0, error: .networkError(error.localizedDescription))
        }
    }
    
    // MARK: - Get Review History
    
    func getReviewHistory(limit: Int = 20) async -> [SavedReview] {
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.getCurrentUserId() else { return [] }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/ai_reviews?user_id=eq.\(userId)&order=created_at.desc&limit=\(limit)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([SavedReview].self, from: data)
        } catch {
            print("Error fetching review history: \(error)")
            return []
        }
    }
    
    // MARK: - Context Building
    
    private func buildContext(for session: WorkoutSession, program: Program?, allSessions: [WorkoutSession]) async -> [String: Any] {
        var context: [String: Any] = [:]
        
        // User profile
        let profile = ProfileService.shared.getProfile()
        context["user"] = [
            "name": profile.name ?? "User",
            "bodyweight": profile.weight ?? 0,
            "goal": "fat-loss-muscle-gain",
            "units": profile.units.rawValue
        ]
        
        // Program info
        if let program = program {
            context["program"] = [
                "programId": program.programId,
                "programName": program.programName,
                "currentWeek": calculateCurrentWeek(sessions: allSessions),
                "totalWeeks": 12,
                "currentPhase": [
                    "name": "Build",
                    "notes": "Progressive overload focus"
                ]
            ]
        }
        
        // Previous same workout
        if let previousSame = findPreviousSameWorkout(session: session, allSessions: allSessions) {
            context["previousWorkout"] = buildWorkoutData(for: previousSame)
        }
        
        // Weekly summaries (compressed)
        let weeklySummaries = await SummaryService.shared.getWeeklySummaries(weeks: 3)
        if !weeklySummaries.isEmpty {
            context["weeklyTrend"] = weeklySummaries.map { summary in
                [
                    "weekNumber": summary.weekNumber,
                    "workoutsCompleted": summary.workoutsCompleted,
                    "totalVolume": summary.totalVolume,
                    "consistency": summary.consistency
                ]
            }
        }
        
        // Monthly summary
        if let monthlySummary = await SummaryService.shared.getMonthlySummary(for: Date()) {
            context["monthlyProgress"] = [
                "workoutsCompleted": monthlySummary.workoutsCompleted,
                "totalVolume": monthlySummary.totalVolume,
                "consistency": monthlySummary.consistency
            ]
        }
        
        // Personal records (simplified)
        context["personalRecords"] = extractRecentPRs(session: session, allSessions: allSessions)
        
        return context
    }
    
    private func buildWorkoutData(for session: WorkoutSession) -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        var data: [String: Any] = [
            "sessionId": session.sessionId,
            "date": dateFormatter.string(from: session.endTime ?? session.startTime),
            "dayId": session.dayId ?? "",
            "dayName": session.dayName
        ]
        
        // Calculate duration
        if let end = session.endTime {
            data["duration"] = Int(end.timeIntervalSince(session.startTime) / 60)
        } else if let dur = session.duration {
            data["duration"] = dur
        }
        
        // Calculate total volume
        var totalVolume = 0
        var exercises: [[String: Any]] = []
        
        for exercise in session.exercises {
            var exerciseData: [String: Any] = [
                "name": exercise.exerciseName,
                "exerciseId": exercise.exerciseId
            ]
            
            var sets: [[String: Any]] = []
            var exerciseVolume = 0
            
            for set in exercise.sets {
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                exerciseVolume += Int(weight * Double(reps))
                
                sets.append([
                    "setNumber": set.setNumber,
                    "weight": weight,
                    "reps": reps,
                    "rpe": set.rpe ?? 0
                ])
            }
            
            exerciseData["actual"] = [
                "sets": sets,
                "volume": exerciseVolume
            ]
            exerciseData["notes"] = exercise.notes ?? ""
            
            totalVolume += exerciseVolume
            exercises.append(exerciseData)
        }
        
        data["exercises"] = exercises
        data["totalVolume"] = totalVolume
        data["notes"] = session.notes ?? ""
        
        return data
    }
    
    private func findPreviousSameWorkout(session: WorkoutSession, allSessions: [WorkoutSession]) -> WorkoutSession? {
        let currentDayId = session.dayId
        let currentDate = session.endTime ?? session.startTime
        
        return allSessions
            .filter { $0.dayId == currentDayId && $0.sessionId != session.sessionId }
            .filter { ($0.endTime ?? $0.startTime) < currentDate }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
            .first
    }
    
    private func calculateCurrentWeek(sessions: [WorkoutSession]) -> Int {
        // Simplified - count weeks since first session
        guard let firstSession = sessions.sorted(by: { $0.startTime < $1.startTime }).first else { return 1 }
        
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: firstSession.startTime, to: Date()).weekOfYear ?? 0
        return max(1, weeks + 1)
    }
    
    private func extractRecentPRs(session: WorkoutSession, allSessions: [WorkoutSession]) -> [[String: Any]] {
        let dateFormatter = ISO8601DateFormatter()
        var prs: [[String: Any]] = []
        
        for exercise in session.exercises {
            let maxWeight = exercise.sets.compactMap { $0.weight }.max() ?? 0
            let maxReps = exercise.sets.compactMap { $0.reps }.max() ?? 0
            
            // Check if this is a PR compared to previous sessions
            let previousMax = allSessions
                .filter { $0.sessionId != session.sessionId }
                .flatMap { $0.exercises }
                .filter { $0.exerciseId == exercise.exerciseId }
                .flatMap { $0.sets }
                .compactMap { $0.weight }
                .max() ?? 0
            
            if maxWeight > previousMax && maxWeight > 0 {
                prs.append([
                    "name": exercise.exerciseName,
                    "weight": maxWeight,
                    "reps": maxReps,
                    "date": dateFormatter.string(from: session.endTime ?? session.startTime)
                ])
            }
        }
        
        return prs
    }
}

// MARK: - Response Models

private struct StatusResponse: Codable {
    let isPro: Bool
    let usage: UsageInfo
}

private struct ReviewResponse: Codable {
    let review: String
    let reviewId: String?
    let usage: UsageInfo
}

private struct FollowUpResponse: Codable {
    let answer: String
    let usage: UsageInfo
}

private struct LimitReachedResponse: Codable {
    let error: String
    let message: String
    let usage: UsageInfo
}

private struct UsageInfo: Codable {
    let used: Int
    let limit: Int
    let remaining: Int
    let resetsAt: String?
}

private struct ErrorResponse: Codable {
    let error: String
    let message: String?
}

struct SavedReview: Codable, Identifiable {
    let id: String
    let userId: String
    let sessionId: String?
    let workoutDate: String
    let workoutDayId: String?
    let workoutDayName: String?
    let reviewText: String
    let highlights: [String]?
    let recommendations: [String]?
    let concerns: [String]?
    let inputTokens: Int?
    let outputTokens: Int?
    let costUsd: Double?
    let followUps: [FollowUp]?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case workoutDate = "workout_date"
        case workoutDayId = "workout_day_id"
        case workoutDayName = "workout_day_name"
        case reviewText = "review_text"
        case highlights
        case recommendations
        case concerns
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costUsd = "cost_usd"
        case followUps = "follow_ups"
        case createdAt = "created_at"
    }
}

struct FollowUp: Codable {
    let question: String
    let answer: String
    let timestamp: String
}
