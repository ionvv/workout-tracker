import Foundation
import Combine

@MainActor
class ProgramsViewModel: ObservableObject {
    @Published var programs: [Program] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func loadPrograms() async {
        isLoading = true
        error = nil
        
        do {
            programs = try await ProgramService.shared.fetchPrograms()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func saveProgram(_ program: Program) async {
        do {
            try await ProgramService.shared.saveProgram(program)
            await loadPrograms()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteProgram(_ program: Program) async {
        do {
            try await ProgramService.shared.deleteProgram(program)
            await loadPrograms()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
