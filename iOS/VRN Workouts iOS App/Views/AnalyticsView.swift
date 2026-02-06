import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Weekly summary
                    WeeklySummaryCard(viewModel: viewModel)
                    
                    // Volume chart
                    VolumeChartCard(data: viewModel.weeklyVolume)
                    
                    // Personal records
                    PersonalRecordsCard(records: viewModel.personalRecords)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .task {
                await viewModel.loadAnalytics()
            }
            .refreshable {
                await viewModel.loadAnalytics()
            }
        }
    }
}

struct WeeklySummaryCard: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)
            
            HStack(spacing: 16) {
                SummaryItem(
                    title: "Workouts",
                    value: "\(viewModel.weeklyWorkouts)",
                    icon: "figure.strengthtraining.traditional",
                    color: .blue
                )
                
                SummaryItem(
                    title: "Volume",
                    value: formatVolume(viewModel.weeklyTotalVolume),
                    icon: "scalemass",
                    color: .green
                )
                
                SummaryItem(
                    title: "Sets",
                    value: "\(viewModel.weeklySets)",
                    icon: "number",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", Double(volume) / 1000)
        }
        return "\(volume)"
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VolumeChartCard: View {
    let data: [DailyVolume]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Volume")
                .font(.headline)
            
            if data.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct PersonalRecordsCard: View {
    let records: [PersonalRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)
            
            if records.isEmpty {
                Text("Complete workouts to set PRs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records.prefix(5)) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.exerciseName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(record.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(record.weight)) kg × \(record.reps)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// Data models for analytics
struct DailyVolume: Identifiable {
    let id = UUID()
    let day: String
    let volume: Int
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

#Preview {
    AnalyticsView()
}
