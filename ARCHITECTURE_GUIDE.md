# StateKit Architecture Guide

**Version**: 2.0+  
**Purpose**: Professional patterns for building scalable, testable apps with StateKit  
**Target Audience**: iOS/macOS developers building production apps

---

## 📖 Table of Contents

1. [Core Architecture Principles](#core-architecture-principles)
2. [Three State Management Patterns](#three-state-management-patterns)
3. [Dependency Injection](#dependency-injection)
4. [Modularity & Feature Architecture](#modularity--feature-architecture)
5. [Composition Patterns](#composition-patterns)
6. [Testing Strategies](#testing-strategies)
7. [Error Handling](#error-handling)
8. [Performance Optimization](#performance-optimization)
9. [Real-World Examples](#real-world-examples)
10. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## Core Architecture Principles

### Principle 1: Separation of Concerns

StateKit provides three distinct layers for managing different types of state:

```
┌─────────────────────────────────────────────────┐
│              VIEW LAYER (SwiftUI)               │
├─────────────────────────────────────────────────┤
│  LOCAL STATE (Hooks)   │   GLOBAL STATE        │
│  • useState            │   • Atoms              │
│  • useReducer          │   • Riverpods          │
│  • useEffect           │   • Observers          │
├─────────────────────────────────────────────────┤
│              BUSINESS LOGIC LAYER               │
│  • Notifiers (stateful logic)                   │
│  • Providers (computed values)                  │
│  • Async operations (futures, streams)          │
├─────────────────────────────────────────────────┤
│              DATA ACCESS LAYER                  │
│  • API clients                                  │
│  • Database access                              │
│  • Cache management                             │
└─────────────────────────────────────────────────┘
```

**Rule**: Data flows from bottom to top; Commands flow from top to bottom.

### Principle 2: Single Responsibility

Each piece of state should have ONE job:

```swift
// ❌ BAD: User notifier doing too much
class UserNotifier: AsyncNotifier<User> {
    override func build() async throws -> User {
        // Fetches user
        // Validates user
        // Caches user
        // Handles auth
        // Tracks analytics
        // Syncs to cloud
        // ...too many responsibilities!
    }
}

// ✅ GOOD: Each notifier has one responsibility
class UserNotifier: AsyncNotifier<User> {
    override func build() async throws -> User {
        let userId = ref.watch(userIdProvider)
        return try await ref.watch(userAPIProvider).fetchUser(userId)
    }
}

class UserCacheProvider: Provider<User> {
    // Separate: responsible for caching logic
}

class UserValidationProvider: Provider<ValidationResult> {
    // Separate: responsible for validation
}
```

### Principle 3: Testability

Every piece of state should be testable in isolation:

```swift
// ✅ Testable: Dependencies injected via ref.watch
class OrderNotifier: AsyncNotifier<Order> {
    override func build() async throws -> Order {
        let items = ref.watch(cartItemsProvider)
        let shipping = ref.watch(shippingProvider)
        let payment = ref.watch(paymentProvider)
        
        return Order(items: items, shipping: shipping, payment: payment)
    }
    
    func placeOrder() async throws {
        let api = ref.watch(apiClientProvider)
        let result = try await api.createOrder(state)
        state = result
    }
}

// Test setup:
let testContainer = ProviderContainer(overrides: [
    cartItemsProvider.overrideWith(testItems),
    shippingProvider.overrideWith(testShipping),
    paymentProvider.overrideWith(testPayment),
    apiClientProvider.overrideWithProvider(mockAPIProvider)
])

let order = testContainer.read(orderProvider)
```

---

## Three State Management Patterns

### Pattern 1: Local State (Hooks) - Component Scope

**When**: Form inputs, UI toggles, temporary state, animation states

```swift
struct FormView: View {
    @State var email = ""
    @State var password = ""
    @State var isValidating = false
    @State var showPassword = false
    
    var body: some View {
        Form {
            TextField("Email", text: $email)
            
            if showPassword {
                TextField("Password", text: $password)
            } else {
                SecureField("Password", text: $password)
            }
            
            Button(action: { showPassword.toggle() }) {
                Text("Show Password")
            }
        }
    }
}
```

**Characteristics**:
- ✅ Simplest for component-scoped state
- ✅ No external dependencies
- ✅ Best for UI-only state
- ❌ Can't share between views
- ❌ Lost when component unmounts

### Pattern 2: Global State (Atoms) - Application Scope

**When**: App-wide settings, user preferences, theme, feature flags

```swift
// Define atoms for app-wide concerns
struct AppSettingsAtom: SKStateAtom {
    typealias Value = AppSettings
    
    func defaultValue(context: SKAtomTransactionContext) -> AppSettings {
        AppSettings(
            isDarkMode: false,
            language: .english,
            notifications: true
        )
    }
}

struct ThemeAtom: SKValueAtom {
    typealias Value = Theme
    
    func defaultValue(context: SKAtomTransactionContext) -> Theme {
        // Derived from settings
        let settings = context.read(AppSettingsAtom())
        return settings.isDarkMode ? .dark : .light
    }
}

// Use in any view
struct SettingsView: View {
    @UseAtom(AppSettingsAtom.self) var (settings, updateSettings)
    
    var body: some View {
        Toggle("Dark Mode", isOn: Binding(
            get: { settings.isDarkMode },
            set: { updateSettings(settings.withDarkMode($0)) }
        ))
    }
}
```

**Characteristics**:
- ✅ Shareable across entire app
- ✅ Persists across navigation
- ✅ Great for global settings
- ✅ Smaller scope than Riverpods
- ⚠️ All subscribers re-render on change

### Pattern 3: Business Logic (Riverpods) - Feature Scope

**When**: API data, complex business logic, async operations, features

```swift
// 1. Define providers
class UserNotifier: AsyncNotifier<User?> {
    override func build() async throws -> User? {
        let userId = ref.watch(selectedUserIdProvider)
        if userId == nil { return nil }
        
        let api = ref.watch(apiClientProvider)
        return try await api.fetchUser(userId!)
    }
}

let userProvider = AsyncNotifierProvider { UserNotifier() }

// 2. Composed provider for app root
struct AppState {
    let user: User?
    let settings: AppSettings
    let notifications: [Notification]
}

let appStateProvider = Provider { ref in
    AppState(
        user: ref.watch(userProvider),
        settings: ref.watch(settingsProvider),
        notifications: ref.watch(notificationsProvider)
    )
}

// 3. Use in SwiftUI
struct RootView: View {
    @Watch(appStateProvider) var appState
    
    var body: some View {
        if let user = appState.user {
            MainTabView(user: user)
        } else {
            AuthView()
        }
    }
}
```

**Characteristics**:
- ✅ Best for business logic
- ✅ Supports async operations
- ✅ Advanced features (families, overrides)
- ✅ Time-travel debugging (coming)
- ⚠️ Steeper learning curve

---

## Dependency Injection

### Strategy 1: Via ProviderRef (Recommended)

```swift
class OrderNotifier: AsyncNotifier<Order> {
    override func build() async throws -> Order {
        // Inject dependencies via ref.watch
        let api = ref.watch(apiClientProvider)
        let auth = ref.watch(authProvider)
        let cache = ref.watch(cacheProvider)
        
        // Use dependencies
        let userId = auth.userId!
        if let cached = try cache.get(userId) {
            return cached
        }
        
        let order = try await api.fetchOrder(userId)
        try cache.set(userId, order)
        return order
    }
}

// Testing
let testContainer = ProviderContainer(overrides: [
    apiClientProvider.overrideWithProvider(mockAPIProvider),
    authProvider.overrideWith(testAuth),
    cacheProvider.overrideWithProvider(mockCacheProvider)
])

let order = testContainer.read(orderProvider)
```

**Pros**:
- ✅ Automatic dependency tracking
- ✅ Reactive: re-runs when deps change
- ✅ Easy to override in tests
- ✅ Natural with provider pattern

### Strategy 2: Via Constructor (For Models)

```swift
// Use for pure data models, not state
struct OrderService {
    let apiClient: APIClient
    let database: Database
    let cache: Cache
    
    func createOrder(_ order: Order) async throws -> OrderResult {
        // Use injected dependencies
        let result = try await apiClient.createOrder(order)
        try database.save(result)
        cache.set(result)
        return result
    }
}

// Create service in provider
let orderServiceProvider = Provider { ref in
    OrderService(
        apiClient: ref.watch(apiClientProvider),
        database: ref.watch(databaseProvider),
        cache: ref.watch(cacheProvider)
    )
}

// Use service in notifier
class CheckoutNotifier: AsyncNotifier<CheckoutState> {
    override func build() async throws -> CheckoutState {
        let service = ref.watch(orderServiceProvider)
        // Use service...
    }
}
```

**Pros**:
- ✅ Explicit dependencies
- ✅ Easy to unit test pure code
- ✅ Good for business logic classes

### Strategy 3: Via Environment (For Cross-Cutting Concerns)

```swift
struct AppEnvironment {
    let apiClient: APIClient
    let analytics: Analytics
    let logger: Logger
    let userDefaults: UserDefaults
}

let environmentProvider = Provider { _ in
    AppEnvironment(
        apiClient: APIClient(),
        analytics: Analytics(),
        logger: Logger(),
        userDefaults: .standard
    )
}

// Access in notifiers
class AuthNotifier: AsyncNotifier<AuthState> {
    override func build() async throws -> AuthState {
        let env = ref.read(environmentProvider)
        env.analytics.trackScreenView("Login")
        // Use env.apiClient, env.logger, etc.
    }
}
```

**Pros**:
- ✅ Good for infrastructure dependencies
- ✅ Single environment for whole app
- ✅ Easy to swap (dev vs prod configs)

---

## Modularity & Feature Architecture

### Feature Module Structure

```
Features/
├── Auth/
│   ├── Models/
│   │   ├── User.swift
│   │   ├── AuthState.swift
│   ├── Providers/
│   │   ├── authProvider.swift
│   │   ├── loginProvider.swift
│   │   ├── registerProvider.swift
│   ├── Views/
│   │   ├── LoginView.swift
│   │   ├── RegisterView.swift
│   │   ├── AuthView.swift
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── TokenManager.swift
│   └── AuthFeature.swift (public interface)
│
├── Shop/
│   ├── Models/
│   │   ├── Product.swift
│   │   ├── Cart.swift
│   ├── Providers/
│   │   ├── productsProvider.swift
│   │   ├── cartProvider.swift
│   ├── Views/
│   │   ├── ProductListView.swift
│   │   ├── CartView.swift
│   └── ShopFeature.swift
│
└── Core/
    ├── Models/
    │   ├── AppState.swift
    ├── Providers/
    │   ├── appRootProvider.swift
    ├── Services/
    │   ├── APIClient.swift
    │   ├── Database.swift
    └── CoreServices.swift
```

### Module Boundaries

Each feature module should:

```swift
// AuthFeature.swift - Public interface

// 1. Export only what's needed
public let authProvider: AsyncNotifierProvider<AuthNotifier, AuthState>
public let isAuthenticatedProvider: Provider<Bool>

// 2. Hide implementation details
// ❌ Don't export these:
// public class AuthNotifier { ... }
// public struct AuthState { ... }
// public let loginService: LoginService

// 3. Provide feature-specific overrides
public extension ProviderContainer {
    func authOverridesForTesting() -> [ProviderOverride] {
        [
            authProvider.overrideWith(.testUser),
            apiClientProvider.overrideWithProvider(mockAPIProvider)
        ]
    }
}
```

### Cross-Feature Communication

```swift
// ❌ BAD: Direct imports between features
import Auth
import Shop

class CheckoutNotifier: AsyncNotifier<CheckoutState> {
    override func build() async throws -> CheckoutState {
        // Bad: Shop directly depends on Auth internals
        let auth = ref.watch(Auth.authProvider)
    }
}

// ✅ GOOD: Communication via root provider
struct AppState {
    let user: User?
    let cart: Cart
}

let appRootProvider = Provider { ref in
    let user = ref.watch(userProvider)  // Core module
    let cart = ref.watch(cartProvider)  // Shop module
    return AppState(user: user, cart: cart)
}

// Each feature only knows about shared AppState
class CheckoutNotifier: AsyncNotifier<CheckoutState> {
    override func build() async throws -> CheckoutState {
        let appState = ref.watch(appRootProvider)
        // Use appState.user, appState.cart
    }
}
```

---

## Composition Patterns

### Pattern 1: Provider Composition (Simple Values)

```swift
// Compose simple providers
let userIdProvider = StateProvider { _ in UUID() }

let userProvider = AsyncNotifierProvider {
    class UserNotifier: AsyncNotifier<User> {
        override func build() async throws -> User {
            let id = ref.watch(userIdProvider)
            let api = ref.watch(apiClientProvider)
            return try await api.fetchUser(id)
        }
    }
    return UserNotifier()
}

let userNameProvider = Provider { ref in
    let user = ref.watch(userProvider)
    return user.name
}

let userEmailProvider = Provider { ref in
    let user = ref.watch(userProvider)
    return user.email
}
```

### Pattern 2: Notifier Composition (Complex State)

```swift
// Compose notifiers for complex business logic
class CartNotifier: Notifier<Cart> {
    override func build() -> Cart {
        Cart(items: [])
    }
    
    func addItem(_ product: Product) {
        let newItem = CartItem(product: product, quantity: 1)
        if let index = state.items.firstIndex(where: { $0.id == product.id }) {
            state.items[index].quantity += 1
        } else {
            state.items.append(newItem)
        }
    }
    
    func removeItem(_ id: String) {
        state.items.removeAll { $0.id == id }
    }
}

class CheckoutNotifier: AsyncNotifier<CheckoutState> {
    override func build() async throws -> CheckoutState {
        let cart = ref.watch(cartProvider).notifier.state
        let shipping = ref.watch(shippingProvider)
        let payment = ref.watch(paymentProvider)
        
        return CheckoutState(
            cart: cart,
            shipping: shipping,
            payment: payment,
            total: calculateTotal(cart, shipping)
        )
    }
    
    func submitOrder() async throws {
        let api = ref.watch(apiClientProvider)
        let cart = ref.watch(cartProvider).notifier.state
        
        let order = try await api.createOrder(
            items: cart.items,
            shipping: state.shipping,
            payment: state.payment
        )
        
        state = state.withOrderResult(order)
    }
    
    private func calculateTotal(_ cart: Cart, _ shipping: Shipping) -> Double {
        cart.total + shipping.cost
    }
}
```

### Pattern 3: Root State Composition

```swift
// Compose all feature states at root
struct AppState {
    var auth: AuthState
    var shop: ShopState
    var notifications: NotificationState
    var settings: SettingsState
}

let appRootProvider = Provider { ref in
    AppState(
        auth: ref.watch(authStateProvider),
        shop: ref.watch(shopStateProvider),
        notifications: ref.watch(notificationsStateProvider),
        settings: ref.watch(settingsStateProvider)
    )
}

// Use in root view
struct RootView: View {
    @Watch(appRootProvider) var appState
    
    var body: some View {
        if appState.auth.isAuthenticated {
            TabView {
                ShopTabView(shop: appState.shop)
                NotificationsTabView(notifications: appState.notifications)
                SettingsTabView(settings: appState.settings)
            }
        } else {
            AuthView()
        }
    }
}
```

---

## Testing Strategies

### Strategy 1: Provider Isolation Testing

```swift
import StateKitTesting

@Test
func userProvider_fetchesUserFromAPI() async throws {
    let testUser = User(id: "123", name: "Test User")
    
    let container = ProviderContainer(overrides: [
        apiClientProvider.overrideWith(
            MockAPIClient(mockUser: testUser)
        )
    ])
    
    let user = container.read(userProvider) as? User
    #expect(user?.name == "Test User")
}
```

### Strategy 2: Notifier Testing

```swift
@Test
func cartNotifier_addItem_updatesCart() {
    let container = ProviderContainer()
    let product = Product(id: "1", name: "Widget", price: 9.99)
    
    let cart = container.read(cartProvider).notifier.state
    container.read(cartProvider).notifier.addItem(product)
    
    let updatedCart = container.read(cartProvider).notifier.state
    #expect(updatedCart.items.count == 1)
    #expect(updatedCart.items.first?.product.id == "1")
}
```

### Strategy 3: Async Testing

```swift
@Test
func authNotifier_login_succeeds() async throws {
    let container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithProvider(mockAPIProvider)
    ])
    
    let notifier = container.read(authProvider).notifier
    try await notifier.login(email: "test@example.com", password: "password")
    
    let state = notifier.state
    #expect(state.isAuthenticated == true)
}
```

### Strategy 4: Integration Testing

```swift
@Test
func checkout_flow_succeeds() async throws {
    let container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithProvider(mockAPIProvider),
        databaseProvider.overrideWithProvider(mockDatabaseProvider)
    ])
    
    // Setup initial state
    let shopState = container.read(shopStateProvider).notifier
    shopState.addProduct(testProduct)
    
    // Run checkout
    let checkout = container.read(checkoutProvider).notifier
    try await checkout.submitOrder()
    
    // Verify result
    #expect(checkout.state.isCompleted == true)
}
```

---

## Error Handling

### Strategy 1: Result Patterns

```swift
enum DataResult<T> {
    case loading
    case success(T)
    case failure(Error)
}

let userProvider = Provider { ref in
    switch ref.watch(userAsyncProvider) {
    case .success(let user):
        return .success(user)
    case .failure(let error):
        return .failure(error)
    case .loading:
        return .loading
    }
}
```

### Strategy 2: Error Recovery

```swift
class DataNotifier: AsyncNotifier<Data?> {
    override func build() async throws -> Data? {
        let api = ref.watch(apiClientProvider)
        let cache = ref.watch(cacheProvider)
        
        do {
            return try await api.fetchData()
        } catch {
            // Fallback to cache
            if let cached = try cache.getCached() {
                return cached
            }
            throw error
        }
    }
}
```

### Strategy 3: Error State Tracking

```swift
struct DataState {
    var data: [Data]?
    var error: Error?
    var isLoading: Bool
    
    var isError: Bool { error != nil }
}

class DataNotifier: AsyncNotifier<DataState> {
    override func build() async throws -> DataState {
        DataState(data: nil, error: nil, isLoading: true)
    }
    
    func refresh() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let api = ref.watch(apiClientProvider)
            state.data = try await api.fetchData()
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
}
```

---

## Performance Optimization

### Optimization 1: Selector Providers (Prevent Rebuilds)

```swift
// ❌ SLOW: Entire user object causes rebuild
@Watch(userProvider) var user
// Rebuilds every time ANY part of user changes

// ✅ FAST: Only name causes rebuild
@Watch(userProvider.select(\.name)) var userName
// Rebuilds only when name changes
```

### Optimization 2: Memoization (Prevent Recomputation)

```swift
// ❌ INEFFICIENT: Recalculates every render
let computedValue = ref.watch(someProvider).expensiveCalculation()

// ✅ EFFICIENT: Caches result, only recalculates if input changes
let computedProvider = Provider { ref in
    ref.watch(someProvider).expensiveCalculation()
}

@Watch(computedProvider) var result
```

### Optimization 3: Family Caching (Prevent Redundant Fetches)

```swift
// ❌ INEFFICIENT: Fetches same user multiple times
let user1 = container.read(userProvider)
let user1Again = container.read(userProvider)  // Fetches again!

// ✅ EFFICIENT: Cached per argument
let userByIdProvider = Provider.family { (ref: ProviderRef, id: String) -> User in
    let api = ref.watch(apiClientProvider)
    return try await api.fetchUser(id)
}

let user1 = container.read(userByIdProvider("user-123"))  // Fetches
let user1Again = container.read(userByIdProvider("user-123"))  // Cached!
let user2 = container.read(userByIdProvider("user-456"))  // Different cache entry
```

### Optimization 4: Keep-Alive Links (Prevent Unnecessary Disposal)

```swift
class CriticalDataNotifier: AsyncNotifier<CriticalData> {
    override func build() async throws -> CriticalData {
        // Keep this provider alive even when no listeners
        let link = ref.keepAlive()
        
        ref.onDispose {
            link.close()  // Allow disposal on cleanup
        }
        
        return try await fetchCriticalData()
    }
}
```

---

## Real-World Examples

### Example 1: Authentication Flow

```swift
// 1. Core providers
let userIdProvider = StateProvider { _ in UUID?.none }

let authProvider = AsyncNotifierProvider {
    class AuthNotifier: AsyncNotifier<AuthState> {
        override func build() async throws -> AuthState {
            let userId = ref.watch(userIdProvider)
            if userId == nil {
                return .unauthenticated
            }
            
            let api = ref.watch(apiClientProvider)
            let user = try await api.validateSession()
            return .authenticated(user)
        }
        
        func login(email: String, password: String) async throws {
            let api = ref.watch(apiClientProvider)
            let token = try await api.login(email: email, password: password)
            
            ref.watch(userIdProvider).state = token.userId
            state = .authenticated(token.user)
        }
        
        func logout() {
            ref.watch(userIdProvider).state = nil
            state = .unauthenticated
        }
    }
    return AuthNotifier()
}

// 2. Composition
struct RootState {
    let auth: AuthState
}

let rootProvider = Provider { ref in
    RootState(auth: ref.watch(authProvider))
}

// 3. View
struct RootView: View {
    @Watch(rootProvider) var root
    
    var body: some View {
        switch root.auth {
        case .authenticated(let user):
            MainView(user: user)
        case .unauthenticated:
            LoginView()
        }
    }
}
```

### Example 2: Shopping Cart

```swift
// 1. Models
struct CartItem {
    let product: Product
    var quantity: Int
}

// 2. Providers
let cartProvider = NotifierProvider {
    class CartNotifier: Notifier<[CartItem]> {
        override func build() -> [CartItem] { [] }
        
        func addItem(_ product: Product) {
            if let index = state.firstIndex(where: { $0.product.id == product.id }) {
                state[index].quantity += 1
            } else {
                state.append(CartItem(product: product, quantity: 1))
            }
        }
        
        func updateQuantity(_ productId: String, to quantity: Int) {
            if let index = state.firstIndex(where: { $0.product.id == productId }) {
                state[index].quantity = quantity
            }
        }
        
        func removeItem(_ productId: String) {
            state.removeAll { $0.product.id == productId }
        }
    }
    return CartNotifier()
}

// 3. Derived providers
let cartTotalProvider = Provider { ref in
    let items = ref.watch(cartProvider)
    return items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
}

let cartItemCountProvider = Provider { ref in
    ref.watch(cartProvider).count
}

// 4. Composition at checkout
class CheckoutNotifier: AsyncNotifier<CheckoutState> {
    override func build() async throws -> CheckoutState {
        let items = ref.watch(cartProvider)
        let total = ref.watch(cartTotalProvider)
        let shipping = ref.watch(shippingProvider)
        
        return CheckoutState(
            items: items,
            total: total,
            shipping: shipping
        )
    }
    
    func placeOrder() async throws {
        let api = ref.watch(apiClientProvider)
        let items = ref.watch(cartProvider)
        
        let order = try await api.createOrder(items: items)
        state.orderId = order.id
        
        // Clear cart after successful order
        ref.watch(cartProvider).notifier.state = []
    }
}

// 5. Views
struct CartView: View {
    @Watch(cartProvider) var items
    @Watch(cartTotalProvider) var total
    
    var body: some View {
        VStack {
            List(items) { item in
                CartItemRow(item: item)
            }
            
            HStack {
                Text("Total:")
                Spacer()
                Text("$\(String(format: "%.2f", total))")
            }
            .font(.headline)
        }
    }
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: God Notifier

```swift
// ❌ BAD: One notifier doing everything
class AppNotifier: AsyncNotifier<AppState> {
    override func build() async throws -> AppState {
        // Manages auth, shop, notifications, settings, analytics, cache...
    }
}

// ✅ GOOD: Separate concerns into feature notifiers
class AuthNotifier: AsyncNotifier<AuthState> { ... }
class ShopNotifier: AsyncNotifier<ShopState> { ... }
class NotificationsNotifier: AsyncNotifier<NotificationState> { ... }

let appRootProvider = Provider { ref in
    AppState(
        auth: ref.watch(authProvider),
        shop: ref.watch(shopProvider),
        notifications: ref.watch(notificationsProvider)
    )
}
```

### Anti-Pattern 2: Circular Dependencies

```swift
// ❌ BAD: Circular dependency
let userProvider = Provider { ref in
    let posts = ref.watch(postsProvider)  // Posts needs User!
    return User(posts: posts)
}

let postsProvider = Provider { ref in
    let user = ref.watch(userProvider)  // Infinite loop!
    return try await api.fetchPosts(userId: user.id)
}

// ✅ GOOD: Break cycle by having shared parent
let userIdProvider = StateProvider { _ in "user-123" }

let userProvider = Provider { ref in
    let userId = ref.watch(userIdProvider)
    return try await api.fetchUser(userId)
}

let postsProvider = Provider { ref in
    let userId = ref.watch(userIdProvider)
    return try await api.fetchPosts(userId: userId)
}

let userWithPostsProvider = Provider { ref in
    UserWithPosts(
        user: ref.watch(userProvider),
        posts: ref.watch(postsProvider)
    )
}
```

### Anti-Pattern 3: Over-Watching

```swift
// ❌ BAD: Creating unnecessary dependencies
let userNameProvider = Provider { ref in
    let user = ref.watch(userProvider)  // Watches entire user
    let profile = ref.watch(profileProvider)  // Watches all profile
    let settings = ref.watch(settingsProvider)  // Watches all settings
    return "\(user.firstName) \(user.lastName)"
}

// ✅ GOOD: Use selectors
let userNameProvider = Provider { ref in
    let firstName = ref.watch(userProvider.select(\.firstName))
    let lastName = ref.watch(userProvider.select(\.lastName))
    return "\(firstName) \(lastName)"
}
```

### Anti-Pattern 4: Mutable Shared State Without Clear Ownership

```swift
// ❌ BAD: Global StateProvider that anyone can mutate
let globalCounterProvider = StateProvider { _ in 0 }

// Now multiple places can randomly mutate this

// ✅ GOOD: Clearly owned, updated through specific notifier
class CounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
    
    func increment() { state += 1 }
    func decrement() { state -= 1 }
    func reset() { state = 0 }
}

let counterProvider = NotifierProvider { CounterNotifier() }
```

---

## Summary: Architecture Decision Matrix

Use this matrix to decide which pattern to use:

| Use Case | Pattern | Example |
|----------|---------|---------|
| UI toggle | Local @State | showMenu, isExpanded |
| Form input | Local @State | emailTextField, nameTextField |
| App settings | Atoms | isDarkMode, language |
| Feature flags | Atoms | isNewUIEnabled |
| API data | Riverpods (Provider) | users, posts |
| Complex async | Riverpods (AsyncNotifier) | authentication, checkout |
| Mutable collection | Riverpods (Notifier) | shopping cart |
| Continuous stream | StreamProvider | WebSocket updates |
| One-shot async | FutureProvider | Load image once |
| Composed state | Root Provider | AppState |

---

**Next**: Phase 3 will add **Time-Travel Debugging** and **Performance Profiling**.

See [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) for complete timeline.
