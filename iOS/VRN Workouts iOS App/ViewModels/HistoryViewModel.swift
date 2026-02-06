import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var sessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var error: String?
    
    var groupedSessions: [String: [WorkoutSession]] {
        Dictionary(grouping: sessions) { session in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: session.startTime)
        }
    }
    
    func loadSessions() async {
        isLoading = true
        error = nil
        
        do {
            sessions = try await SessionService.shared.fetchSessions()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
