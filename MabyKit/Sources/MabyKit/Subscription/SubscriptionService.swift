import Foundation
import StoreKit

/// The identifiers configured in App Store Connect (and mirrored in
/// `BabyPlus.storekit` for local testing).
public enum SubscriptionProduct: String, CaseIterable, Sendable {
    case monthly = "com.elbeheiry.babyplus.pro.monthly"
    case yearly = "com.elbeheiry.babyplus.pro.yearly"

    public static let groupID = "babyplus_pro"

    /// All identifiers we ever ask the App Store about.
    public static var allIdentifiers: [String] { allCases.map(\.rawValue) }
}

/// Owns everything to do with BabyPlus+: what is for sale, whether the person in
/// front of us has paid, and the two actions (buy, restore) they can take.
///
/// StoreKit 2 is the single source of truth — we never persist "is pro" anywhere
/// we could get wrong. `Transaction.currentEntitlements` is re-read on launch and
/// `Transaction.updates` keeps us honest while the app is running, which is what
/// makes refunds, family sharing and expiry work without any extra code.
@MainActor
public final class SubscriptionService: ObservableObject {

    // MARK: Published state

    /// Products fetched from the App Store, cheapest cadence first.
    @Published public private(set) var products: [Product] = []

    /// Whether the current Apple Account has an active BabyPlus+ entitlement.
    @Published public private(set) var isSubscribed = false

    /// The product backing the active entitlement, if any.
    @Published public private(set) var activeProductID: String?

    /// When the active subscription next renews or lapses.
    @Published public private(set) var renewalDate: Date?

    /// True while the subscription is in a billing retry / grace period so the UI
    /// can prompt for a payment update instead of silently locking things.
    @Published public private(set) var isInBillingRetry = false

    /// True when this Apple Account has never used the introductory offer.
    @Published public private(set) var isEligibleForIntroOffer = false

    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var isRestoring = false
    /// Identifier of the product currently being purchased, for per-button spinners.
    @Published public private(set) var purchasingProductID: String?
    @Published public var lastErrorMessage: String?

    // MARK: Internals

    private var updatesTask: Task<Void, Never>?

    #if DEBUG
    /// Lets previews and the simulator exercise the Pro UI without a sandbox account.
    /// Set with `-BabyPlusForcePro YES` in the scheme's launch arguments.
    private let forcePro = UserDefaults.standard.bool(forKey: "BabyPlusForcePro")
    #endif

    public init() {
        #if DEBUG
        if forcePro { isSubscribed = true }
        #endif
        listenForTransactions()
    }

    // MARK: - Entitlement

    /// Whether a given feature is available right now.
    public func isUnlocked(_ feature: PremiumFeature) -> Bool {
        isSubscribed
    }

    /// Re-reads entitlements from StoreKit. Safe (and cheap) to call on every
    /// foreground.
    public func refreshEntitlements() async {
        var active: Transaction?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            guard SubscriptionProduct.allIdentifiers.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date.now { continue }

            // Keep whichever entitlement runs longest — matters when someone
            // upgrades from monthly to yearly mid-cycle.
            if let current = active,
               let currentExpiry = current.expirationDate,
               let candidateExpiry = transaction.expirationDate,
               candidateExpiry <= currentExpiry {
                continue
            }
            active = transaction
        }

        applyEntitlement(active)
        await refreshRenewalState()
        await refreshIntroEligibility()
    }

    private func applyEntitlement(_ transaction: Transaction?) {
        let unlocked: Bool
        #if DEBUG
        unlocked = transaction != nil || forcePro
        #else
        unlocked = transaction != nil
        #endif

        isSubscribed = unlocked
        activeProductID = transaction?.productID
        renewalDate = transaction?.expirationDate
    }

    private func refreshRenewalState() async {
        guard
            let productID = activeProductID,
            let product = products.first(where: { $0.id == productID }),
            let statuses = try? await product.subscription?.status
        else {
            isInBillingRetry = false
            return
        }

        isInBillingRetry = statuses.contains { status in
            status.state == .inBillingRetryPeriod || status.state == .inGracePeriod
        }
    }

    private func refreshIntroEligibility() async {
        guard !isSubscribed, let anyProduct = products.first else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await anyProduct.subscription?.isEligibleForIntroOffer ?? false
    }

    // MARK: - Catalogue

    public func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: SubscriptionProduct.allIdentifiers)
            products = fetched.sorted { lhs, rhs in
                lhs.subscriptionPeriodInDays < rhs.subscriptionPeriodInDays
            }
            lastErrorMessage = nil
            await refreshIntroEligibility()
        } catch {
            lastErrorMessage = "We couldn't reach the App Store. Check your connection and try again."
        }
    }

    public func product(for plan: SubscriptionProduct) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    // MARK: - Purchasing

    public enum PurchaseOutcome: Equatable {
        case success
        case pending
        case cancelled
        case failed(String)
    }

    @discardableResult
    public func purchase(_ product: Product) async -> PurchaseOutcome {
        guard purchasingProductID == nil else { return .cancelled }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return .success

            case .pending:
                // Ask-to-buy or SCA: the purchase may complete later, and
                // `Transaction.updates` will pick it up when it does.
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed("That purchase finished in a way we don't understand yet.")
            }
        } catch {
            let message = (error as? StoreKitError)?.friendlyDescription
                ?? "The purchase couldn't be completed. Nothing has been charged."
            lastErrorMessage = message
            return .failed(message)
        }
    }

    /// Restores purchases made with the signed-in Apple Account.
    @discardableResult
    public func restore() async -> Bool {
        guard !isRestoring else { return isSubscribed }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
        } catch {
            // A failed sync is not fatal — the entitlement check below is still
            // worth running, since the receipt may already be on device.
            lastErrorMessage = "We couldn't refresh from the App Store, but we checked this device."
        }

        await refreshEntitlements()
        return isSubscribed
    }

    // MARK: - Transaction stream

    private func listenForTransactions() {
        updatesTask = Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? await self.checkVerified(update) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
}

// MARK: - Product conveniences

extension Product {
    /// Rough length of one billing period, used only for ordering the plans.
    var subscriptionPeriodInDays: Int {
        guard let period = subscription?.subscriptionPeriod else { return .max }
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return .max
        }
    }

    /// "month" / "year" — for the "$X / month" line under the price.
    public var periodLabel: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return period.value == 1 ? unit : "\(period.value) \(unit)s"
    }

    /// The price of this plan expressed per month, formatted in the store's
    /// currency. Lets a yearly plan advertise an honest monthly equivalent.
    public var monthlyEquivalentPrice: String? {
        guard let period = subscription?.subscriptionPeriod else { return nil }
        let months: Decimal
        switch period.unit {
        case .year: months = Decimal(period.value * 12)
        case .month: months = Decimal(period.value)
        case .week: months = Decimal(period.value) / 4
        case .day: months = Decimal(period.value) / 30
        @unknown default: return nil
        }
        guard months > 0 else { return nil }
        return (price / months).formatted(priceFormatStyle)
    }

    /// Human description of a free trial or discounted first period, if there is one.
    public var introductoryOfferLabel: String? {
        guard let offer = subscription?.introductoryOffer else { return nil }
        let period = offer.period
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }

        switch offer.paymentMode {
        case .freeTrial:
            return "\(period.value) \(unit) free"
        case .payAsYouGo:
            return "\(offer.displayPrice) per \(unit) for \(period.value) \(unit)"
        case .payUpFront:
            return "\(offer.displayPrice) for the first \(period.value) \(unit)"
        default:
            return nil
        }
    }
}

// MARK: - Small helpers

private extension StoreKitError {
    var friendlyDescription: String {
        switch self {
        case .networkError:
            return "The App Store couldn't be reached. Nothing has been charged."
        case .userCancelled:
            return "Purchase cancelled."
        case .notEntitled:
            return "This Apple Account isn't entitled to make that purchase."
        case .notAvailableInStorefront:
            return "BabyPlus+ isn't available in your region yet."
        default:
            return "The purchase couldn't be completed. Nothing has been charged."
        }
    }
}
