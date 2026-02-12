import Foundation

/// Service for generating and storing workout summaries (weekly/monthly)
/// Used to compress historical data for AI review context
actor SummaryService {
    static let shared = SummaryService()
    
    private init() {}
    
    // MARK: - Generate Summary After Workout
    
    /// Call this after saving a workout session
    func generateSummaries(for session: Session, allSessions: [Session]) async {
        let date = parseDate(session.completedAt ?? session.startedAt ?? "") ?? Date()
        
        // Generate weekly summary
        await generateWeeklySummary(for: date, sessions: allSessions)
        
        // Generate monthly summary if end of month
        if isEndOfMonth(date) || isFirstOfMonth(date) {
            await generateMonthlySummary(for: date, sessions: allSessions)
        }
    }
    
    // MARK: - Weekly Summary
    
    func generateWeeklySummary(for date: Date, sessions: [Session]) async {
        let weekStart = startOfWeek(date)
        let weekEnd = endOfWeek(date)
        let weekNumber = weekNumber(for: date)
        let periodKey = "W\(weekNumber)-\(year(for: date))"
        
        // Filter sessions for this week
        let weekSessions = sessions.filter { session in
            guard let sessionDate = parseDate(session.completedAt ?? session.startedAt ?? "") else { return false }
            return sessionDate >= weekStart && sessionDate <= weekEnd
        }
        
        // Calculate metrics
        let workoutsCompleted = weekSessions.count
        let totalVolume = weekSessions.reduce(0) { total, session in
            total + calculateVolume(for: session)
        }
        let averageRPE = calculateAverageRPE(sessions: weekSessions)
        let keyLifts = extractKeyLifts(from: weekSessions)
        let prs = extractPRs(from: weekSessions, allSessions: sessions)
        
        let summary = WeeklySummary(
            weekNumber: weekNumber,
            periodKey: periodKey,
            startDate: ISO8601DateFormatter().string(from: weekStart),
            endDate: ISO8601DateFormatter().string(from: weekEnd),
            workoutsCompleted: workoutsCompleted,
            workoutsPlanned: 3,
            consistency: workoutsCompleted * 100 / 3,
            totalVolume: totalVolume,
            averageVolume: workoutsCompleted > 0 ? totalVolume / workoutsCompleted : 0,
            averageRPE: averageRPE,
            keyLifts: keyLifts,
            personalRecords: prs
        )
        
        // Save to Supabase
        await saveSummary(summary, type: "weekly", periodKey: periodKey)
    }
    
    // MARK: - Monthly Summary
    
    func generateMonthlySummary(for date: Date, sessions: [Session]) async {
        let monthStart = startOfMonth(date)
        let monthEnd = endOfMonth(date)
        let periodKey = "\(year(for: date))-\(String(format: "%02d", month(for: date)))"
        
        // Filter sessions for this month
        let monthSessions = sessions.filter { session in
            guard let sessionDate = parseDate(session.completedAt ?? session.startedAt ?? "") else { return false }
            return sessionDate >= monthStart && sessionDate <= monthEnd
        }
        
        let workoutsCompleted = monthSessions.count
        let totalVolume = monthSessions.reduce(0) { $0 + calculateVolume(for: $1) }
        let strengthGains = calculateStrengthGains(monthSessions: monthSessions, allSessions: sessions)
        
        let summary = MonthlySummary(
            month: month(for: date),
            year: year(for: date),
            periodKey: periodKey,
            startDate: ISO8601DateFormatter().string(from: monthStart),
            endDate: ISO8601DateFormatter().string(from: monthEnd),
            workoutsCompleted: workoutsCompleted,
            workoutsPlanned: 12,
            consistency: workoutsCompleted * 100 / 12,
            totalVolume: totalVolume,
            strengthGains: strengthGains
        )
        
        await saveSummary(summary, type: "monthly", periodKey: periodKey)
    }
    
    // MARK: - Fetch Summaries
    
    func getWeeklySummaries(weeks: Int) async -> [WeeklySummary] {
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.getCurrentUserId() else { return [] }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/workout_summaries?user_id=eq.\(userId)&summary_type=eq.weekly&order=period_start.desc&limit=\(weeks)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([SummaryRow].self, from: data)
            return rows.compactMap { row in
                try? JSONDecoder().decode(WeeklySummary.self, from: row.data)
            }
        } catch {
            print("Error fetching weekly summaries: \(error)")
            return []
        }
    }
    
    func getMonthlySummary(for date: Date) async -> MonthlySummary? {
        let periodKey = "\(year(for: date))-\(String(format: "%02d", month(for: date)))"
        
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.getCurrentUserId() else { return nil }
        
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/workout_summaries?user_id=eq.\(userId)&summary_type=eq.monthly&period_key=eq.\(periodKey)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([SummaryRow].self, from: data)
            guard let row = rows.first else { return nil }
            return try JSONDecoder().decode(MonthlySummary.self, from: row.data)
        } catch {
            print("Error fetching monthly summary: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveSummary<T: Encodable>(_ summary: T, type: String, periodKey: String) async {
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.getCurrentUserId() else { return }
        
        let summaryData = try? JSONEncoder().encode(summary)
        guard let summaryData else { return }
        
        // Upsert summary
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/workout_summaries")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "user_id": userId,
            "summary_type": type,
            "period_key": periodKey,
            "period_start": (summary as? WeeklySummary)?.startDate ?? (summary as? MonthlySummary)?.startDate ?? "",
            "period_end": (summary as? WeeklySummary)?.endDate ?? (summary as? MonthlySummary)?.endDate ?? "",
            "data": String(data: summaryData, encoding: .utf8) ?? "{}"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                print("Error saving summary: HTTP \(httpResponse.statusCode)")
            }
        } catch {
            print("Error saving summary: \(error)")
        }
    }
    
    private func calculateVolume(for session: Session) -> Int {
        session.exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + Int((set.weight ?? 0) * Double(set.reps ?? 0))
            }
        }
    }
    
    private func calculateAverageRPE(sessions: [Session]) -> Double {
        var totalRPE = 0.0
        var count = 0
        for session in sessions {
            for exercise in session.exercises {
                for set in exercise.sets {
                    if let rpe = set.rpe {
                        totalRPE += Double(rpe)
                        count += 1
                    }
                }
            }
        }
        return count > 0 ? totalRPE / Double(count) : 0
    }
    
    private func extractKeyLifts(from sessions: [Session]) -> [String: KeyLiftSummary] {
        var lifts: [String: KeyLiftSummary] = [:]
        let keyLiftNames = ["bench press", "squat", "deadlift", "overhead press", "barbell row"]
        
        for session in sessions {
            for exercise in session.exercises {
                let nameLower = exercise.exerciseName.lowercased()
                for keyLift in keyLiftNames {
                    if nameLower.contains(keyLift) {
                        let maxWeight = exercise.sets.compactMap { $0.weight }.max() ?? 0
                        let maxReps = exercise.sets.compactMap { $0.reps }.max() ?? 0
                        let volume = exercise.sets.reduce(0) { $0 + Int(($1.weight ?? 0) * Double($1.reps ?? 0)) }
                        
                        let key = keyLift.replacingOccurrences(of: " ", with: "_")
                        if lifts[key] == nil || maxWeight > (lifts[key]?.weight ?? 0) {
                            lifts[key] = KeyLiftSummary(weight: maxWeight, reps: maxReps, volume: volume)
                        }
                    }
                }
            }
        }
        return lifts
    }
    
    private func extractPRs(from weekSessions: [Session], allSessions: [Session]) -> [String] {
        var prs: [String] = []
        // Simplified PR detection - compare to all previous sessions
        // In production, would track PRs in separate table
        return prs
    }
    
    private func calculateStrengthGains(monthSessions: [Session], allSessions: [Session]) -> [String: Double] {
        // Compare first week to last week of month
        return [:]
    }
    
    // MARK: - Date Helpers
    
    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func startOfWeek(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
    
    private func endOfWeek(_ date: Date) -> Date {
        let start = startOfWeek(date)
        return Calendar.current.date(byAdding: .day, value: 6, to: start) ?? date
    }
    
    private func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }
    
    private func endOfMonth(_ date: Date) -> Date {
        let start = startOfMonth(date)
        return Calendar.current.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }
    
    private func weekNumber(for date: Date) -> Int {
        Calendar.current.component(.weekOfYear, from: date)
    }
    
    private func month(for date: Date) -> Int {
        Calendar.current.component(.month, from: date)
    }
    
    private func year(for date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }
    
    private func isEndOfMonth(_ date: Date) -> Bool {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        return month(for: date) != month(for: nextDay)
    }
    
    private func isFirstOfMonth(_ date: Date) -> Bool {
        Calendar.current.component(.day, from: date) == 1
    }
}

// MARK: - Models

struct WeeklySummary: Codable {
    let weekNumber: Int
    let periodKey: String
    let startDate: String
    let endDate: String
    let workoutsCompleted: Int
    let workoutsPlanned: Int
    let consistency: Int
    let totalVolume: Int
    let averageVolume: Int
    let averageRPE: Double
    let keyLifts: [String: KeyLiftSummary]
    let personalRecords: [String]
}

struct MonthlySummary: Codable {
    let month: Int
    let year: Int
    let periodKey: String
    let startDate: String
    let endDate: String
    let workoutsCompleted: Int
    let workoutsPlanned: Int
    let consistency: Int
    let totalVolume: Int
    let strengthGains: [String: Double]
}

struct KeyLiftSummary: Codable {
    let weight: Double
    let reps: Int
    let volume: Int
}

struct SummaryRow: Codable {
    let id: String
    let userId: String
    let summaryType: String
    let periodKey: String
    let data: Data
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case summaryType = "summary_type"
        case periodKey = "period_key"
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        summaryType = try container.decode(String.self, forKey: .summaryType)
        periodKey = try container.decode(String.self, forKey: .periodKey)
        
        // Data comes as JSON object, need to re-encode
        let dataDict = try container.decode([String: AnyCodable].self, forKey: .data)
        data = try JSONEncoder().encode(dataDict)
    }
}

// Helper for decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}
