import SwiftUI
import StoreKit

/// Paywall view for upgrading to PRO
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Features
                    featuresSection
                    
                    // Pricing
                    pricingSection
                    
                    // Purchase button
                    purchaseSection
                    
                    // Terms
                    termsSection
                }
                .padding()
            }
            .navigationTitle("PRO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            
            Text("Unlock AI Coach")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Get personalized feedback and recommendations after every workout")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PRO Features")
                .font(.headline)
            
            FeatureRow(
                icon: "sparkles",
                color: .yellow,
                title: "AI Workout Reviews",
                description: "Get expert analysis after every session"
            )
            
            FeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                title: "Progressive Overload Tracking",
                description: "AI suggests when to increase weight"
            )
            
            FeatureRow(
                icon: "message.fill",
                color: .blue,
                title: "Ask Follow-up Questions",
                description: "Chat with your AI coach about your training"
            )
            
            FeatureRow(
                icon: "clock.arrow.circlepath",
                color: .purple,
                title: "Review History",
                description: "Access all past reviews and insights"
            )
            
            FeatureRow(
                icon: "bell.fill",
                color: .orange,
                title: "Plateau Detection",
                description: "Get alerts when progress stalls"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Pricing
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if storeKit.isLoading {
                ProgressView()
            } else if let product = storeKit.proMonthlyProduct {
                VStack(spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 44, weight: .bold))
                    
                    Text("per month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Value proposition
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("~175 AI reviews per month")
                        .font(.subheadline)
                }
                .padding(.top, 8)
                
            } else {
                Text("Unable to load pricing")
                    .foregroundStyle(.secondary)
                
                Button("Retry") {
                    Task {
                        await storeKit.loadProducts()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue, lineWidth: 2)
        )
    }
    
    // MARK: - Purchase
    
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if storeKit.isPro {
                // Already PRO
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("You're a PRO member!")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            } else if let product = storeKit.proMonthlyProduct {
                Button {
                    Task {
                        await purchase(product)
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Subscribe for \(product.displayPrice)/month")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPurchasing)
            }
            
            // Restore purchases
            Button {
                Task {
                    await storeKit.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
            }
        }
    }
    
    // MARK: - Terms
    
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage your subscription in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://workout-tracker-963.pages.dev/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://workout-tracker-963.pages.dev/privacy")!)
            }
            .font(.caption)
        }
        .padding(.top)
    }
    
    // MARK: - Actions
    
    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let transaction = try await storeKit.purchase(product)
            if transaction != nil {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Compact PRO Badge

struct ProBadge: View {
    @StateObject private var storeKit = StoreKitManager.shared
    
    var body: some View {
        if storeKit.isPro {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.2))
            .clipShape(Capsule())
        }
    }
}

// MARK: - PRO Gate View

/// Wraps content that requires PRO, showing upgrade prompt if not PRO
struct ProGatedView<Content: View>: View {
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var showingUpgrade = false
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        if storeKit.isPro {
            content()
        } else {
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("PRO Feature")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Upgrade to PRO to unlock this feature")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showingUpgrade = true
                } label: {
                    Text("Upgrade to PRO")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showingUpgrade) {
                ProUpgradeView()
            }
        }
    }
}

#Preview {
    ProUpgradeView()
}
