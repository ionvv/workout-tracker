import SwiftUI

struct DevicePairingView: View {
    @StateObject private var viewModel = DevicePairingViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Generating code...")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if let code = viewModel.pairingCode {
                // Instructions
                VStack(spacing: 4) {
                    Text("Pair Your Watch")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("1. Open website and login")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("2. Go to Profile → Pair Watch")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("3. Enter this code:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
                
                // Display pairing code (bigger, no tracking to prevent cutoff)
                Text(code)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    
                    // Countdown timer
                    if let timeRemaining = viewModel.timeRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text(timeRemaining)
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    // Status
                    if viewModel.isPolling {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Waiting for authorization...")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    }
                }
                .padding()
                
                // Refresh button
                Button {
                    Task {
                        await viewModel.requestNewCode()
                    }
                } label: {
                    Label("New Code", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                
            } else if let error = viewModel.errorMessage {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await viewModel.requestNewCode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle("Pair Device")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.startPairingFlow()
            }
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

#Preview {
    NavigationView {
        DevicePairingView()
    }
}
