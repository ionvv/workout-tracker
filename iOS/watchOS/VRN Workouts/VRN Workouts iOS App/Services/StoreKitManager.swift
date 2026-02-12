import Foundation
import StoreKit
import Combine

/// Manages StoreKit 2 subscriptions for PRO features
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // Product IDs - must match App Store Connect
    static let proMonthlyProductId = "com.vrnworkouts.pro.monthly"
    static let proYearlyProductId = "com.vrnworkouts.pro.yearly" // Optional: add later
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPro = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        // Load products and check status on init
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIds = [
                Self.proMonthlyProductId,
                // Self.proYearlyProductId // Uncomment when ready
            ]
            
            products = try await Product.products(for: productIds)
            print("StoreKit: Loaded \(products.count) products")
            
            for product in products {
                print("  - \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            print("StoreKit: Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update local state
            await updatePurchasedProducts()
            
            // Sync with backend
            await syncProStatusWithBackend(isPro: true)
            
            // Finish the transaction
            await transaction.finish()
            
            return transaction
            
        case .userCancelled:
            print("StoreKit: User cancelled")
            return nil
            
        case .pending:
            print("StoreKit: Purchase pending (Ask to Buy, etc.)")
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("StoreKit: Failed to restore purchases: \(error)")
        }
    }
    
    // MARK: - Check Subscription Status
    
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if subscription is still valid
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("StoreKit: Failed to verify transaction: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        self.isPro = purchasedIDs.contains(Self.proMonthlyProductId) ||
                     purchasedIDs.contains(Self.proYearlyProductId)
        
        print("StoreKit: PRO status = \(isPro)")
        
        // Sync with backend
        await syncProStatusWithBackend(isPro: isPro)
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        Task {
                            await self.updatePurchasedProducts()
                        }
                    }
                    
                    await transaction.finish()
                } catch {
                    print("StoreKit: Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
    
    // MARK: - Backend Sync
    
    private func syncProStatusWithBackend(isPro: Bool) async {
        guard let token = await AuthService.shared.getAccessToken(),
              let userId = await AuthService.shared.getCurrentUserId() else {
            print("StoreKit: Cannot sync - not authenticated")
            return
        }
        
        // Update profiles table
        var request = URLRequest(url: URL(string: "\(Config.supabaseURL)/rest/v1/profiles?id=eq.\(userId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "is_pro": isPro,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("StoreKit: Backend sync response: \(httpResponse.statusCode)")
            }
        } catch {
            print("StoreKit: Backend sync failed: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    var proMonthlyProduct: Product? {
        products.first { $0.id == Self.proMonthlyProductId }
    }
    
    var proYearlyProduct: Product? {
        products.first { $0.id == Self.proYearlyProductId }
    }
}

// MARK: - Subscription Info

extension StoreKitManager {
    
    struct SubscriptionInfo {
        let isActive: Bool
        let expirationDate: Date?
        let willRenew: Bool
        let productId: String?
    }
    
    func getSubscriptionInfo() async -> SubscriptionInfo {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.proMonthlyProductId ||
                   transaction.productID == Self.proYearlyProductId {
                    return SubscriptionInfo(
                        isActive: transaction.revocationDate == nil,
                        expirationDate: transaction.expirationDate,
                        willRenew: transaction.revocationDate == nil,
                        productId: transaction.productID
                    )
                }
            }
        }
        
        return SubscriptionInfo(isActive: false, expirationDate: nil, willRenew: false, productId: nil)
    }
}
