import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading history...")
                } else if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Complete a workout to see it here")
                    )
                } else {
                    List {
                        ForEach(viewModel.groupedSessions.keys.sorted().reversed(), id: \.self) { date in
                            Section(header: Text(formatSectionDate(date))) {
                                ForEach(viewModel.groupedSessions[date] ?? []) { session in
                                    NavigationLink(destination: SessionDetailView(session: session)) {
                                        SessionRow(session: session)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .task {
                await viewModel.loadSessions()
            }
            .refreshable {
                await viewModel.loadSessions()
            }
        }
    }
    
    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.dayName)
                .font(.headline)
            
            HStack(spacing: 16) {
                Label("\(session.totalSets ?? 0) sets", systemImage: "number")
                Label("\(session.totalVolume ?? 0) kg", systemImage: "scalemass")
                Label("\(session.duration ?? 0) min", systemImage: "timer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Text(formatTime(session.startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
}
