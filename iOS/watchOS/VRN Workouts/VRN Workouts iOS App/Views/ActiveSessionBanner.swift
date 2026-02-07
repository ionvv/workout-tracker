import SwiftUI

struct ActiveSessionBanner: View {
    @ObservedObject var stateManager = WorkoutStateManager.shared
    let onTap: () -> Void
    
    var body: some View {
        if stateManager.hasActiveSession, let summary = stateManager.activeSessionSummary {
            Button(action: onTap) {
                HStack {
                    // Pulsing indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout in Progress")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(summary.dayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(summary.completedSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.15))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ActiveSessionBanner(onTap: {})
    }
}
