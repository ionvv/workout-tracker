import SwiftUI

struct ProgramsView: View {
    @StateObject private var viewModel = ProgramsViewModel()
    @State private var showingCreateProgram = false
    @State private var editingProgram: Program?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading programs...")
                } else if viewModel.programs.isEmpty {
                    VStack(spacing: 20) {
                        ContentUnavailableView(
                            "No Programs",
                            systemImage: "list.bullet.clipboard",
                            description: Text("Create a workout program to get started")
                        )
                        
                        Button {
                            showingCreateProgram = true
                        } label: {
                            Label("Create Program", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(viewModel.programs) { program in
                            NavigationLink(destination: ProgramDetailView(program: program)) {
                                ProgramRow(program: program)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteProgram(program) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingProgram = program
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.loadPrograms() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateProgram = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadPrograms()
            }
            .refreshable {
                await viewModel.loadPrograms()
            }
            .sheet(isPresented: $showingCreateProgram) {
                ProgramEditorView { newProgram in
                    Task {
                        await viewModel.saveProgram(newProgram)
                    }
                }
            }
            .sheet(item: $editingProgram) { program in
                ProgramEditorView(program: program) { updatedProgram in
                    Task {
                        await viewModel.saveProgram(updatedProgram)
                    }
                }
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
