import Foundation
import StoreKit

@MainActor
final class PremiumStore: ObservableObject {
    static let premiumProductId = "com.yourcompany.72hfastingcontest.premium"

    @Published var product: Product?
    @Published var isLoading = false
    @Published var lastMessage: String?

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.premiumProductId]).first
        } catch {
            lastMessage = "Premium unlock is ready for StoreKit configuration."
        }
    }

    func purchase() async -> Bool {
        guard let product else {
            lastMessage = "Add the StoreKit product to enable purchase testing."
            return false
        }

        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified = verification {
                lastMessage = "Premium unlocked."
                return true
            }
        } catch {
            lastMessage = "Purchase could not be completed."
        }
        return false
    }

    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            lastMessage = "Purchases restored."
            return true
        } catch {
            lastMessage = "Restore could not be completed."
            return false
        }
    }
}
