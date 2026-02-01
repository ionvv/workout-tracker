import Foundation
import SwiftUI
import Combine

@MainActor
class ProgramsViewModel: ObservableObject {
    @Published var programs: [Program] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let programService = ProgramService.shared
    
    func loadPrograms() async {
        isLoading = true
        await programService.fetchPrograms()
        programs = programService.programs
        errorMessage = programService.error
        isLoading = false
    }
}
