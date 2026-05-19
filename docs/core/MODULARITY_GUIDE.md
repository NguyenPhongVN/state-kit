# StateKit Modularity Guide

**Version**: 2.0.0  
**Date**: May 2026  
**Status**: Phase 2 Complete

---

## Overview

This guide provides comprehensive patterns for organizing StateKit applications into maintainable, scalable modules. It covers module structure, boundaries, dependency management, and inter-module communication strategies.

**Core Principle**: Modules should be **focused**, **independent**, and **composable**.

---

## Table of Contents

1. [Module Types](#module-types)
2. [Module Anatomy](#module-anatomy)
3. [Module Boundaries](#module-boundaries)
4. [Dependency Management](#dependency-management)
5. [Inter-Module Communication](#inter-module-communication)
6. [Feature Module Pattern](#feature-module-pattern)
7. [Core vs Feature](#core-vs-feature)
8. [Testing Modular Code](#testing-modular-code)
9. [Real-World Examples](#real-world-examples)
10. [Best Practices](#best-practices)

---

## Module Types

### 1. Core Modules

Foundation modules providing essential functionality used by all features.

**Examples**:
- `CoreUI` - Shared SwiftUI components and styles
- `CoreNetwork` - API client and networking utilities
- `CoreData` - Database access and models
- `CoreLogging` - Logging infrastructure

**Characteristics**:
- ✅ Few external dependencies
- ✅ Highly reusable
- ✅ Minimal API surface
- ✅ Stable, infrequently changing

**Module Structure**:
```
CoreNetwork/
├── Models/
│   ├── APIError.swift
│   ├── APIRequest.swift
│   └── APIResponse.swift
├── Client/
│   ├── NetworkClient.swift
│   └── NetworkClientProtocol.swift
├── Interceptors/
│   ├── AuthInterceptor.swift
│   └── LoggingInterceptor.swift
└── Public.swift  # Exports public API
```

### 2. Feature Modules

Self-contained features with their own state, UI, and business logic.

**Examples**:
- `AuthFeature` - Authentication flow
- `ShoppingFeature` - Shopping cart and checkout
- `ProfileFeature` - User profile management
- `DiscoveryFeature` - Browse and search

**Characteristics**:
- ✅ Encapsulated state
- ✅ Clear entry/exit points
- ✅ Minimal dependencies on other features
- ✅ Can be tested in isolation

**Module Structure**:
```
AuthFeature/
├── Models/
│   ├── AuthState.swift
│   ├── AuthAction.swift
│   └── User.swift
├── Notifiers/
│   ├── AuthNotifier.swift
│   └── SessionNotifier.swift
├── Providers/
│   ├── authProvider.swift
│   └── sessionProvider.swift
├── Views/
│   ├── LoginView.swift
│   ├── SignupView.swift
│   └── AuthContainer.swift
├── Composition/
│   ├── AuthComposition.swift
│   └── AuthDependencies.swift
└── Public.swift  # Public exports
```

### 3. Composition Modules

High-level modules that compose multiple features into a cohesive app.

**Examples**:
- `AppComposition` - Root app state and routing
- `ShoppingComposition` - Shopping user flows
- `AdminComposition` - Admin dashboard composition

**Characteristics**:
- ✅ Composes multiple features
- ✅ Manages feature interactions
- ✅ Owns root-level routing
- ✅ Minimal feature-specific logic

**Module Structure**:
```
AppComposition/
├── RootState.swift
├── RootNotifier.swift
├── Navigation/
│   ├── AppRouter.swift
│   └── NavigationState.swift
├── Composition/
│   ├── AppComposition.swift
│   ├── FeatureIntegration.swift
│   └── DependencyContainer.swift
└── Views/
    ├── RootView.swift
    └── AppTabBar.swift
```

---

## Module Anatomy

Every module should follow this internal structure for consistency.

### Essential Files

**1. Models/** - Data types and state definitions
```swift
// AuthState.swift
struct AuthState: Sendable {
    enum Status {
        case unauthenticated
        case authenticated(User)
        case loading
        case error(AuthError)
    }

    var status: Status = .unauthenticated
    var sessionToken: String?
}

// AuthAction.swift
enum AuthAction: Sendable {
    case login(email: String, password: String)
    case logout
    case refreshSession
    case setError(AuthError)
}

// AuthError.swift
enum AuthError: Error, Sendable {
    case invalidCredentials
    case networkError(NetworkError)
    case sessionExpired
}
```

**2. Notifiers/** - State mutation logic
```swift
// AuthNotifier.swift
@Notifier
class AuthNotifier: Notifier<AuthState> {
    override func build() -> AuthState {
        AuthState()
    }

    func login(email: String, password: String) async {
        state.status = .loading

        do {
            let token = try await loginUser(email: email, password: password)
            state.sessionToken = token
            state.status = .authenticated(User(email: email))
        } catch {
            state.status = .error(.invalidCredentials)
        }
    }

    func logout() {
        state.status = .unauthenticated
        state.sessionToken = nil
    }
}
```

**3. Providers/** - Reactive value computations
```swift
// authProvider.swift
let authProvider = NotifierProvider(cacheTime: 300.0) { AuthNotifier() }

let userProvider = Provider { ref in
    let state = ref.watch(authProvider)
    return state.status.user
}

let isAuthenticatedProvider = Provider { ref in
    let state = ref.watch(authProvider)
    return state.sessionToken != nil
}
```

**4. Views/** - SwiftUI components
```swift
// LoginView.swift
struct LoginView: View {
    @State var email = ""
    @State var password = ""
    @Watch(authProvider) var authState
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            TextField("Email", text: $email)
            SecureField("Password", text: $password)

            Button("Login") {
                Task {
                    let notifier = container.read(authProvider.notifier)
                    await notifier.login(email: email, password: password)
                }
            }
        }
    }
}
```

**5. Composition/** - Feature coordination
```swift
// AuthComposition.swift
enum AuthComposition {
    static func buildAuthFlow() -> some View {
        Group {
            if let user = authState.user {
                ProfileView(user: user)
            } else {
                LoginView()
            }
        }
    }
}
```

**6. Public.swift** - Controlled exports
```swift
// Public.swift
@_exported import Foundation

// Only export what other modules need
public typealias AuthState = AuthFeature.AuthState
public typealias AuthAction = AuthFeature.AuthAction
public typealias AuthError = AuthFeature.AuthError

public let authProvider = AuthFeature.authProvider
public let userProvider = AuthFeature.userProvider

public struct AuthFeatureAPI {
    public static let notifierProvider = authProvider
    public static func userProvider() -> some ProviderProtocol {
        AuthFeature.userProvider
    }
}
```

---

## Module Boundaries

### Clear Boundaries

Define what a module owns and what it doesn't.

**Auth Module Owns**:
- ✅ `AuthState` - Authentication state
- ✅ `AuthNotifier` - Login/logout logic
- ✅ `SessionManager` - Token management
- ✅ `LoginView` - Login UI
- ✅ `AuthError` - Auth-specific errors

**Auth Module Does NOT Own**:
- ❌ `User` model (belongs to CoreData or UserFeature)
- ❌ Navigation state (belongs to AppComposition)
- ❌ UI components for other features
- ❌ Network client (belongs to CoreNetwork)

### Circular Dependency Prevention

Design module dependencies as a **directed acyclic graph (DAG)**.

**Bad - Circular**:
```
AuthFeature ← → UserFeature
   ↑                ↓
   └────────────────┘
```

**Good - Acyclic**:
```
CoreData
  ↑
  ├── AuthFeature
  │     ↑
  │     └── AppComposition
  │
  └── UserFeature
        ↑
        └── AppComposition
```

### Import Rules

**Allowed Imports**:
1. Core modules (CoreNetwork, CoreData, CoreUI)
2. Models and shared types
3. Own module files

**Forbidden Imports**:
1. Circular imports
2. Private implementation details (files not exported in Public.swift)
3. Sibling feature modules (go through composition module)
4. App-level state (except in composition modules)

**Example - Correct Import Strategy**:
```swift
// ✅ AuthFeature/Views/LoginView.swift
import SwiftUI
import CoreUI        // OK - core module
import AuthFeature   // OK - own module
// NOT allowed: import UserFeature

// ✅ AppComposition/RootNotifier.swift
import AuthFeature   // OK - composing this feature
import UserFeature   // OK - composing this feature
```

---

## Dependency Management

### 1. Dependency Injection via ProviderRef

**Pattern**: Pass dependencies through providers, not constructors.

```swift
// AuthFeature/AuthNotifier.swift
class AuthNotifier: Notifier<AuthState> {
    override func build() -> AuthState {
        // Access dependencies via ref
        let networkClient = ref.watch(networkClientProvider)
        let userPreferences = ref.watch(userPreferencesProvider)

        // Initialize with dependencies
        return AuthState()
    }

    func login(email: String, password: String) async {
        let networkClient = ref.watch(networkClientProvider)
        // Use networkClient...
    }
}
```

### 2. Dependency Container

**Pattern**: Centralized configuration of module dependencies.

```swift
// AppComposition/DependencyContainer.swift
struct DependencyContainer {
    let networkClient: NetworkClient
    let userDatabase: UserDatabase
    let logger: Logger

    static func production() -> DependencyContainer {
        DependencyContainer(
            networkClient: NetworkClient(baseURL: productionURL),
            userDatabase: UserDatabase(path: databasePath),
            logger: ConsoleLogger()
        )
    }

    static func testing() -> DependencyContainer {
        DependencyContainer(
            networkClient: MockNetworkClient(),
            userDatabase: InMemoryUserDatabase(),
            logger: TestLogger()
        )
    }
}
```

### 3. Dependency Scoping

**Pattern**: Control dependency lifetime and visibility.

```swift
// AuthFeature/Composition/AuthDependencies.swift
enum AuthDependencies {
    // Shared singleton
    static let authNotifier = NotifierProvider { AuthNotifier() }

    // Per-user instance via family
    static let userSessionProvider = NotifierProvider.family { (userId: Int) in
        UserSessionNotifier(userId: userId)
    }

    // Computed value (no caching)
    static let isAuthenticatedProvider = Provider { ref in
        let state = ref.watch(authProvider)
        return state.sessionToken != nil
    }
}
```

---

## Inter-Module Communication

### 1. Through Composition Modules

**Bad - Direct Feature Communication**:
```swift
// ❌ AuthFeature directly imports UserFeature
import UserFeature

class AuthNotifier: Notifier<AuthState> {
    func notifyUserAboutLogin() {
        // Direct cross-feature call
        let userNotifier = ref.watch(userProvider.notifier)
        userNotifier.updateLastLogin()
    }
}
```

**Good - Through Composition**:
```swift
// ✅ AppComposition coordinates features
class AppNotifier: Notifier<AppState> {
    override func build() -> AppState {
        AppState()
    }

    // Coordinate between features
    func handleUserLogin(_ user: User) {
        var authState = state.auth
        // Notify auth feature
        let authNotifier = ref.watch(authProvider.notifier)

        var userState = state.user
        // Notify user feature
        let userNotifier = ref.watch(userProvider.notifier)
        userNotifier.updateLastLogin()

        state.auth = authState
        state.user = userState
    }
}
```

### 2. Event Notification

**Pattern**: Use provider listeners for loose coupling.

```swift
// AuthFeature/Providers
let authStatusChangeProvider = StreamProvider { ref in
    // Emit events when auth status changes
    let notifier = ref.watch(authProvider.notifier)
    // ...
}

// AppComposition/RootNotifier.swift
override func build() -> AppState {
    // Listen to auth changes without tight coupling
    ref.listen(authStatusChangeProvider) { oldStatus, newStatus in
        handleAuthStatusChange(from: oldStatus, to: newStatus)
    }

    return AppState()
}
```

### 3. Shared Models with Core Modules

**Pattern**: Core modules define shared data models.

```
CoreData (Core Module)
├── User.swift
├── Product.swift
└── Order.swift

AuthFeature → uses User from CoreData
UserFeature → uses User from CoreData
ShoppingFeature → uses Product, Order from CoreData
```

---

## Feature Module Pattern

### Complete Feature Module Template

Create new feature modules following this template:

```
MyFeature/
├── Models/
│   ├── MyState.swift          # State definition
│   ├── MyAction.swift         # Actions (if needed)
│   └── MyError.swift          # Error types
├── Notifiers/
│   ├── MyNotifier.swift       # Main notifier
│   └── MyHelperNotifier.swift # Supporting notifiers
├── Providers/
│   ├── myProvider.swift       # Main provider
│   └── myComputedProvider.swift # Derived providers
├── Views/
│   ├── MyView.swift           # Primary view
│   ├── MyDetailView.swift     # Secondary views
│   └── Components/
│       └── MyComponent.swift  # Shared components
├── Composition/
│   ├── MyComposition.swift    # State composition helpers
│   └── MyDependencies.swift   # Dependency configuration
├── Tests/
│   ├── MyNotifierTests.swift
│   ├── MyViewTests.swift
│   └── MyIntegrationTests.swift
└── Public.swift               # Public API
```

### Example: Complete Shopping Feature Module

```swift
// ShoppingFeature/Models/ShoppingState.swift
struct ShoppingState: Sendable {
    var cart: [CartItem] = []
    var isLoading = false
    var lastError: ShoppingError?
}

// ShoppingFeature/Notifiers/ShoppingNotifier.swift
@Notifier
class ShoppingNotifier: Notifier<ShoppingState> {
    override func build() -> ShoppingState {
        ShoppingState()
    }

    func addToCart(_ item: Product) {
        state.cart.append(CartItem(product: item))
    }

    func checkout() async {
        state.isLoading = true
        do {
            let orderId = try await submitOrder(state.cart)
            // Handle success
            state.cart = []
            state.isLoading = false
        } catch {
            state.lastError = ShoppingError(error)
            state.isLoading = false
        }
    }
}

// ShoppingFeature/Providers/shoppingProvider.swift
let shoppingProvider = NotifierProvider { ShoppingNotifier() }

let cartTotalProvider = Provider { ref in
    let state = ref.watch(shoppingProvider)
    return state.cart.map { $0.price }.reduce(0, +)
}

// ShoppingFeature/Views/CartView.swift
struct CartView: View {
    @Watch(shoppingProvider) var state
    @Watch(cartTotalProvider) var total

    var body: some View {
        List {
            ForEach(state.cart) { item in
                HStack {
                    Text(item.product.name)
                    Spacer()
                    Text("$\(item.price)")
                }
            }

            Section {
                Text("Total: $\(total)")
                    .font(.headline)
            }
        }
    }
}

// ShoppingFeature/Public.swift
@_exported import Foundation

public let shoppingProvider = ShoppingFeature.shoppingProvider
public let cartTotalProvider = ShoppingFeature.cartTotalProvider
```

---

## Core vs Feature

### When to Create a Core Module

Create a core module when:
- ✅ Multiple features depend on it
- ✅ It's generic and feature-agnostic
- ✅ It has few external dependencies
- ✅ It changes infrequently

**Examples**: Network, Database, UI Kits, Logging

### When to Create a Feature Module

Create a feature module when:
- ✅ It's user-facing functionality
- ✅ It has its own state and UI
- ✅ It can be independently tested
- ✅ It's developed by a team/individual

**Examples**: Auth, Shopping, Profile, Notifications

### When to Create a Composition Module

Create a composition module when:
- ✅ You need to coordinate multiple features
- ✅ You own cross-feature routing
- ✅ You're integrating features into a larger app

**Examples**: AppComposition, AdminComposition

---

## Testing Modular Code

### 1. Unit Testing Notifiers

Test notifier logic in isolation.

```swift
// ShoppingFeature/Tests/ShoppingNotifierTests.swift
import XCTest
import StateKitTesting

final class ShoppingNotifierTests: XCTestCase {
    var test: StateTest!

    override func setUp() {
        super.setUp()
        test = StateTest()
    }

    func testAddToCart() {
        let notifier = ShoppingNotifier()
        test.setState { _ in ShoppingState() }

        let item = Product(id: 1, name: "Item", price: 10.0)
        notifier.addToCart(item)

        XCTAssertEqual(test.state.cart.count, 1)
        XCTAssertEqual(test.state.cart[0].product.name, "Item")
    }
}
```

### 2. Integration Testing Features

Test features with their dependencies.

```swift
// ShoppingFeature/Tests/ShoppingIntegrationTests.swift
final class ShoppingIntegrationTests: XCTestCase {
    func testCheckoutFlow() async {
        let container = ProviderContainer(
            overrides: [
                networkClientProvider.overrideWith(MockNetworkClient())
            ]
        )

        let state = container.read(shoppingProvider)
        let notifier = container.read(shoppingProvider.notifier)

        // Test checkout flow
        notifier.addToCart(testProduct)
        await notifier.checkout()

        XCTAssertTrue(state.cart.isEmpty)
    }
}
```

### 3. Module Composition Testing

Test how modules integrate.

```swift
// AppComposition/Tests/FeatureIntegrationTests.swift
final class FeatureIntegrationTests: XCTestCase {
    func testAuthAndUserFeatureIntegration() {
        let container = ProviderContainer()

        // Test auth flow affects user state
        let authNotifier = container.read(authProvider.notifier)
        let userNotifier = container.read(userProvider.notifier)

        // Verify state consistency across features
        let authState = container.read(authProvider)
        let userData = container.read(userProvider)

        XCTAssertEqual(authState.user?.id, userData.currentUserId)
    }
}
```

---

## Real-World Examples

### Example 1: E-Commerce App Architecture

```
RootApp/
├── CoreData/
│   ├── Product
│   ├── User
│   ├── Order
│   └── Cart
├── CoreNetwork/
│   ├── APIClient
│   ├── Interceptors
│   └── Models
├── CoreUI/
│   ├── Buttons
│   ├── Cards
│   └── Forms
├── AuthFeature/
│   ├── Login
│   ├── Signup
│   ├── SessionManagement
│   └── Notifier: AuthNotifier
├── ShoppingFeature/
│   ├── ProductList
│   ├── ProductDetail
│   ├── Cart
│   ├── Checkout
│   └── Notifier: ShoppingNotifier
├── UserFeature/
│   ├── Profile
│   ├── Orders
│   ├── Preferences
│   └── Notifier: UserNotifier
├── NotificationFeature/
│   ├── PushNotifications
│   ├── InAppNotifications
│   └── Notifier: NotificationNotifier
└── AppComposition/
    ├── RootNotifier (composes all features)
    ├── Router (coordinates navigation)
    └── DependencyContainer
```

### Example 2: Social Media App Architecture

```
SocialApp/
├── CoreData/
│   ├── User
│   ├── Post
│   ├── Comment
│   └── Like
├── CoreNetwork/
├── CoreUI/
├── AuthFeature/
│   └── Notifier: AuthNotifier
├── FeedFeature/
│   ├── FeedView
│   ├── PostCell
│   └── Notifier: FeedNotifier (watches authProvider)
├── UserProfileFeature/
│   ├── ProfileView
│   ├── PostGridView
│   └── Notifier: ProfileNotifier
├── SearchFeature/
│   ├── SearchView
│   ├── ResultsView
│   └── Notifier: SearchNotifier
├── MessagingFeature/
│   ├── ConversationList
│   ├── ChatView
│   └── Notifier: MessagingNotifier
└── AppComposition/
    ├── RootNotifier
    ├── TabRouter
    └── DeepLinkHandler
```

---

## Best Practices

### 1. Keep Modules Focused

**Good - Single responsibility**:
```swift
// AuthFeature owns authentication only
class AuthNotifier: Notifier<AuthState> {
    override func build() -> AuthState { AuthState() }
    func login(email: String, password: String) async { ... }
    func logout() { ... }
}
```

**Bad - Multiple responsibilities**:
```swift
// ❌ Don't mix auth and user management
class AuthUserNotifier: Notifier<(AuthState, UserState)> {
    override func build() -> (AuthState, UserState) { ... }
    func login() { ... }
    func updateProfile() { ... }  // ← belongs in UserFeature
    func changeEmail() { ... }     // ← belongs in UserFeature
}
```

### 2. Use Public.swift for Control

Export only the public API.

```swift
// ShoppingFeature/Public.swift
// ✅ Export public types and providers
public let shoppingProvider = ShoppingFeature.shoppingProvider
public typealias ShoppingState = ShoppingFeature.ShoppingState

// ❌ Don't export implementation details
// public let shoppingNotifier = ShoppingFeature.shoppingNotifier
// public class ShoppingNotifier: Notifier<ShoppingState> { ... }
```

### 3. Minimize Cross-Module Dependencies

**Good - Through composition**:
```
AppComposition knows about all features
AuthFeature knows about CoreNetwork
ShoppingFeature knows about CoreData
(No feature knows about other features)
```

**Bad - Spaghetti dependencies**:
```
AuthFeature → ShoppingFeature → UserFeature → AuthFeature ← circular!
```

### 4. Document Module Boundaries

Add README to each module:

```markdown
# ShoppingFeature Module

## What This Module Owns
- Shopping cart state management
- Checkout flow
- Order submission

## Dependencies
- CoreData (Product, Order models)
- CoreNetwork (API calls)
- CoreUI (UI components)

## Public API
- `shoppingProvider` - Main provider for shopping state
- `cartTotalProvider` - Computed cart total
- `ShoppingState` - State type

## Example Usage
```swift
@Watch(shoppingProvider) var state
```
```

### 5. Design for Testing

```swift
// Make dependencies injectable via ref
class ShoppingNotifier: Notifier<ShoppingState> {
    override func build() -> ShoppingState {
        // Get dependencies from ref for easy mocking in tests
        let networkClient = ref.watch(networkClientProvider)
        let userPreferences = ref.watch(userPreferencesProvider)
        return ShoppingState()
    }
}

// Test by overriding providers
let container = ProviderContainer(
    overrides: [
        networkClientProvider.overrideWith(MockNetworkClient())
    ]
)
```

---

## Migration Path

Transitioning an existing app to modular architecture:

### Phase 1: Extract Core
```
1. Identify reusable utilities (network, database, UI)
2. Create CoreNetwork, CoreData, CoreUI modules
3. Move code with minimal changes
4. Update imports
```

### Phase 2: Create Feature Modules
```
1. Group related features (Auth, Shopping, Profile)
2. Extract state, notifiers, views
3. Create Public.swift for each feature
4. Add composition module
```

### Phase 3: Optimize Dependencies
```
1. Remove circular imports
2. Consolidate cross-feature communication through composition
3. Add integration tests
```

---

## Architecture Decision Tree

Use this tree to decide module organization:

```
Is this code used by multiple features?
├─ YES → Create Core Module
│         └─ Add to CoreNetwork, CoreData, or CoreUI
│
└─ NO → Is this user-facing functionality?
        ├─ YES → Create Feature Module
        │         └─ Own all state, views, and logic
        │
        └─ NO → Is this coordinating multiple features?
                ├─ YES → Add to Composition Module
                │         └─ RootNotifier or AppComposition
                │
                └─ NO → Keep in existing module
                        └─ Might be a utility or helper
```

---

## References

- [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - Core architecture patterns
- [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) - Feature roadmap
- [API_STABILITY.md](API_STABILITY.md) - API stability levels
- [GUIDE.md](GUIDE.md) - Getting started guide

---

**Last Updated**: May 17, 2026  
**Version**: 2.0.0  
**Next Review**: June 2026 (Phase 3 planning)
