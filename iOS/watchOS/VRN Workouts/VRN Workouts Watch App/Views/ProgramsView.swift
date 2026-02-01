import SwiftUI

struct ProgramsView: View {
    @StateObject private var viewModel = ProgramsViewModel()
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.programs.isEmpty {
                    Text("No programs found")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.programs) { program in
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.programName)
                                    .font(.headline)
                                    .lineLimit(2)
                                
                                Text("\(program.workoutDays.count) days")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            try? await authService.signOut()
                        }
                    } label: {
                        Image(systemName: "arrow.right.square")
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

struct ProgramDetailView: View {
    let program: Program
    
    var body: some View {
        List(program.workoutDays) { day in
            NavigationLink {
                WorkoutView(program: program, day: day)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.dayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("\(day.exercises.count) exercises")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle(program.programName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProgramsView()
}
