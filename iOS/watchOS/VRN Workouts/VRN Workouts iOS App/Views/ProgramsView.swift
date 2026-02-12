import SwiftUI

struct ProgramsView: View {
    @StateObject private var viewModel = ProgramsViewModel()
    @State private var showingCreateProgram = false
    @State private var showingImportSheet = false
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
                    Menu {
                        Button {
                            showingCreateProgram = true
                        } label: {
                            Label("Create Program", systemImage: "plus")
                        }
                        
                        Button {
                            showingImportSheet = true
                        } label: {
                            Label("Import from JSON", systemImage: "square.and.arrow.down")
                        }
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
            .sheet(isPresented: $showingImportSheet) {
                ImportProgramView { importedProgram in
                    Task {
                        await viewModel.saveProgram(importedProgram)
                    }
                }
            }
        }
    }
}

// MARK: - Import Program View

struct ImportProgramView: View {
    let onImport: (Program) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText = ""
    @State private var errorMessage: String?
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste your program JSON below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                HStack {
                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            jsonText = clipboard
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        importProgram()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Import")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(jsonText.isEmpty || isImporting)
                }
            }
            .padding()
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func importProgram() {
        isImporting = true
        errorMessage = nil
        
        do {
            let data = jsonText.data(using: .utf8)!
            
            // First try to decode as-is
            var jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Auto-generate program_id if missing
            if jsonObj["program_id"] == nil || (jsonObj["program_id"] as? String)?.isEmpty == true {
                jsonObj["program_id"] = UUID().uuidString
            }
            
            // Auto-generate dayId for each day if missing
            if var days = jsonObj["workout_days"] as? [[String: Any]] {
                for i in days.indices {
                    if days[i]["dayId"] == nil || (days[i]["dayId"] as? String)?.isEmpty == true {
                        days[i]["dayId"] = "day-\(i + 1)-\(UUID().uuidString.prefix(8))"
                    }
                    
                    // Auto-generate exerciseId for each exercise if missing
                    if var exercises = days[i]["exercises"] as? [[String: Any]] {
                        for j in exercises.indices {
                            if exercises[j]["exerciseId"] == nil || (exercises[j]["exerciseId"] as? String)?.isEmpty == true {
                                exercises[j]["exerciseId"] = "ex-\(j + 1)-\(UUID().uuidString.prefix(8))"
                            }
                        }
                        days[i]["exercises"] = exercises
                    }
                }
                jsonObj["workout_days"] = days
            }
            
            // Re-encode and decode as Program
            let modifiedData = try JSONSerialization.data(withJSONObject: jsonObj)
            let decoder = JSONDecoder()
            let program = try decoder.decode(Program.self, from: modifiedData)
            
            onImport(program)
            dismiss()
        } catch {
            errorMessage = "Invalid JSON: \(error.localizedDescription)"
            isImporting = false
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
