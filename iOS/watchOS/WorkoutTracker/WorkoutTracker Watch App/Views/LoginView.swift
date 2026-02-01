import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Text("🏋️")
                        .font(.system(size: 40))
                    
                    Text("Workout Tracker")
                        .font(.headline)
                    
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        Task {
                            await viewModel.signIn()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Login")
        }
    }
}

#Preview {
    LoginView()
}
