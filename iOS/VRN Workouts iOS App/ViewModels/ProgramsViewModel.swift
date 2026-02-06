import Foundation

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
}
