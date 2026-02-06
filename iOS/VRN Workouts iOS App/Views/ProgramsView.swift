import SwiftUI

struct ProgramsView: View {
    @StateObject private var viewModel = ProgramsViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading programs...")
                } else if viewModel.programs.isEmpty {
                    ContentUnavailableView(
                        "No Programs",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Import a workout program to get started")
                    )
                } else {
                    List(viewModel.programs) { program in
                        NavigationLink(destination: ProgramDetailView(program: program)) {
                            ProgramRow(program: program)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadPrograms() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadPrograms()
            }
            .refreshable {
                await viewModel.loadPrograms()
            }
        }
    }
}

struct ProgramRow: View {
    let program: Program
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(program.programName)
                .font(.headline)
            
            HStack {
                Label("\(program.days.count) workouts", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProgramsView()
}
