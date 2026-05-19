# Danh Sách Tất Cả Macros Có Thể Tạo Cho StateKit

## 🎯 CORE STATE MACROS

### 1. @Atom Variants (mở rộng @Atom)
```swift
// Selector Atom - auto derive values từ other atoms
@SelectorAtom
struct IsAdultSelector {
    func select(context: SKAtomTransactionContext) -> Bool {
        let user = try context.watch(UserAtom())
        return user.age >= 18
    }
}

// Filtered Atom - auto filter list atoms
@FilteredAtom(source: UserListAtom.self)
struct ActiveUsersAtom {
    func predicate(_ user: User) -> Bool {
        user.isActive
    }
}

// Mapped Atom - auto transform atom values
@MappedAtom(source: UserAtom.self)
struct UserNameAtom {
    func transform(_ user: User) -> String {
        user.name.uppercased()
    }
}

// Family Atom - auto create atom families
@FamilyAtom
struct UserAtom: SKValueAtom {
    let userId: String  // Family key
    
    func value(context: SKAtomTransactionContext) -> User {
        fetchUser(userId)
    }
}
```

---

### 2. @AsyncTask - Auto async/task atom
```swift
// Trước: phải viết full async task atom code
// Sau: just mark it!
@AsyncTask
struct FetchUserTask {
    let userId: String
    
    func run() async throws -> User {
        try await APIClient.fetchUser(userId)
    }
    // Macro auto sinh: TaskAtom, loading/error states, refresh logic
}
```

---

### 3. @Reducer - Auto sinh reducer logic
```swift
@Reducer
struct CounterReducer {
    enum Action {
        case increment
        case decrement(by: Int)
        case reset
    }
    
    func reduce(_ state: inout Int, action: Action) {
        switch action {
        case .increment: state += 1
        case .decrement(let by): state -= by
        case .reset: state = 0
        }
    }
    // Macro auto sinh: reducer atom, dispatch function, hook
}
```

---

## 🎨 VIEW & UI MACROS

### 4. @StateView Shortcuts
```swift
// Auto StateView boilerplate
@StateViewShortcut
struct CounterView {
    let count = useAtomState(CounterAtom())
    
    func body() -> some View {
        Button("Count: \(count.0)") {
            count.1(count.0 + 1)
        }
    }
    // Macro: auto wrap in StateView, implement body, setup StateScope
}

// Even shorter: @QuickView (StateView + StateScope auto)
@QuickView
struct Dashboard {
    let (count, setCount) = useState(0)
    
    var body: some View {
        Text("Count: \(count)")
    }
}
```

---

### 5. @Preview - Auto generate previews
```swift
@StateAtom
struct CounterAtom {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

@Preview  // Auto generate preview with atoms!
struct CounterView_Previews {
    @StateAtom var counter = 42  // Override for preview
}
// Macro sinh: full preview code
```

---

## 🔄 OBSERVABLE & BINDING MACROS

### 6. @ObservableState - Auto Observable
```swift
@ObservableState
struct UserState {
    var name: String = ""
    var email: String = ""
    var age: Int = 0
}
// Macro: auto @Observable, @ObservationIgnored for transients
```

---

### 7. @BindableState - Auto Binding properties
```swift
@BindableState
struct FormState {
    @Bindable var username: String = ""
    @Bindable var password: String = ""
    @Bindable var rememberMe: Bool = false
    
    var nonBindable: String = ""  // Skipped
}
// Macro: auto create useFormBinding() hook
```

---

## 🏗️ BUILDER & INITIALIZER MACROS

### 8. @Builder - Auto builder pattern
```swift
@Builder
struct APIRequest {
    var method: String = "GET"
    var path: String
    var headers: [String: String] = [:]
    var body: Data?
}

// Usage:
let request = APIRequest()
    .method("POST")
    .path("/users")
    .headers(["Authorization": "Bearer token"])
    .body(data)
```

---

### 9. @Init - Auto custom initializers
```swift
@Init
struct User {
    var id: String
    var name: String
    var email: String
    var age: Int = 0  // Optional param
    var verified: Bool = false
}

// Macro generates: init(id:name:email:age:verified:), builder init
```

---

## 📦 SERIALIZATION MACROS

### 10. @MyCodable - Better Codable
```swift
@MyCodable(keyMapping: .snakeCase)  // auto snake_case conversion
struct APIResponse {
    var userId: String     // Maps to: user_id
    var userData: User     // Maps to: user_data
    var createdAt: Date
}
```

---

### 11. @AutoEquatable / @AutoHashable
```swift
@AutoEquatable
struct User {
    var id: String
    var name: String
    var createdAt: Date
}
// Macro: auto Equatable conformance (no manual ==)

@AutoHashable
struct UserId: Identifiable {
    let id: UUID
}
```

---

## 🎮 RIVERPOD MACROS

### 12. @RiverpodFamily - Auto riverpod families
```swift
@RiverpodFamily
class UserNotifier extends Notifier<User?> {
    final userId = ref.watch(userIdProvider);
    
    @override
    build(String userId) async {
        return await fetchUser(userId);
    }
}
// Macro: auto create family provider, hooks
```

---

### 13. @RiverpodSelector - Auto selector provider
```swift
@RiverpodSelector
final class isAdminProvider extends Notifier<bool> {
    @override
    build() async {
        final user = await ref.watch(userProvider);
        return user.role == 'admin';
    }
}
```

---

## 🔐 VALIDATION & ERROR MACROS

### 14. @Validated - Auto validation
```swift
@Validated
struct Password {
    @Rules(["minLength:8", "hasNumber", "hasSpecial"])
    var value: String
}

// Usage:
let pwd = Password(value: "Secure@123")
if pwd.isValid {
    // Use password
}
```

---

### 15. @Result - Auto result enum
```swift
@Result
struct APIResponse<T: Codable> {
    var data: T?
    var error: APIError?
}
// Macro: auto Result<T, APIError> enum conformance
```

---

## 📡 NETWORKING MACROS

### 16. @APIEndpoint - Auto API client
```swift
@APIEndpoint(baseURL: "https://api.example.com")
struct UserAPI {
    @GET("/users/{id}")
    func getUser(id: String) async throws -> User
    
    @POST("/users")
    func createUser(user: User) async throws -> User
    
    @DELETE("/users/{id}")
    func deleteUser(id: String) async throws -> Void
}

// Macro generates: URL building, request/response handling, error mapping
```

---

### 17. @WebSocket - Auto websocket handler
```swift
@WebSocket(url: "wss://api.example.com/stream")
struct LiveData {
    @Subscribe("updates")
    var updates: AsyncStream<Update>
    
    @Subscribe("notifications")
    var notifications: AsyncStream<Notification>
}
```

---

## 🎯 DEPENDENCY INJECTION MACROS

### 18. @DIContainer - Auto DI container
```swift
@DIContainer
struct AppDependencies {
    @Singleton
    var apiClient: APIClient { APIClient() }
    
    @Transient
    var viewModel: UserViewModel { UserViewModel(api: apiClient) }
    
    @Lazy
    var expensiveResource: HeavyService { HeavyService() }
}

// Macro: auto register, resolve, inject
```

---

## ✨ MODIFIER & STYLE MACROS

### 19. @ViewModifier - Auto compound modifiers
```swift
@ViewModifier
struct RoundedCard {
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 4
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(radius: shadowRadius)
    }
}

// Auto create: .roundedCard(), .roundedCard(backgroundColor:), etc
```

---

### 20. @Theme - Auto theme system
```swift
@Theme
struct AppTheme {
    var colors: ColorPalette {
        ColorPalette(
            primary: .blue,
            secondary: .gray,
            error: .red
        )
    }
    
    var spacing: SpacingScale { SpacingScale() }
}

// Macro: auto EnvironmentValues, theme provider, hook
```

---

## 📊 DATA MACROS

### 21. @Differentiable - Auto diff algorithm
```swift
@Differentiable
struct User {
    var id: String  // diffKey
    var name: String
    var email: String
    var avatar: URL?
}
// Macro: auto compute changes, animate transitions
```

---

### 22. @Persistable - Auto persistence
```swift
@Persistable(storage: .userDefaults, key: "user")
struct UserState {
    var username: String = ""
    var email: String = ""
}
// Macro: auto save/load, sync with UserDefaults/Keychain
```

---

## 🧪 TESTING MACROS

### 23. @Mock - Auto mock objects
```swift
@Mock
protocol APIClientProtocol {
    func fetchUser(id: String) async throws -> User
}

// Macro generates: full mock implementation, spy tracking, stub support
```

---

### 24. @Snapshot - Auto snapshot testing
```swift
@Snapshot
struct UserProfile: View {
    let user: User
    
    var body: some View { /* ... */ }
}
// Macro: auto generate snapshots, comparison, regression detection
```

---

## 📋 SUMMARY - PRIORITIZED LIST

### 🔥 Tier 1 - Most Useful (Implement First!)
1. **@HookForm** - Form handling (given examples)
2. **@HookState** - State setup (given examples)
3. **@AsyncTask** - Auto async atoms
4. **@APIEndpoint** - API client generation
5. **@StateViewShortcut** - View boilerplate
6. **@Reducer** - Reducer logic

### ⭐ Tier 2 - Very Useful
7. **@SelectorAtom** - Derived atoms
8. **@FamilyAtom** - Atom families
9. **@DIContainer** - Dependency injection
10. **@Persistable** - Data persistence
11. **@ObservableState** - Observable wrapper
12. **@Builder** - Builder pattern

### 💎 Tier 3 - Nice to Have
13. @MyCodable, @RiverpodFamily, @Theme, @Differentiable
14. @Mock, @Snapshot, @Validated, @WebSocket
15. @Preview, @AutoEquatable, @BindableState

---

## 💡 Đề Xuất Implementation Order

**Phase 1 (High ROI):**
1. @HookForm
2. @HookState
3. @AsyncTask
4. @StateViewShortcut

**Phase 2 (More Advanced):**
5. @SelectorAtom
6. @FamilyAtom
7. @APIEndpoint
8. @Reducer

**Phase 3 (Polish):**
9. @Persistable
10. @DIContainer
11. @Theme
12. @Mock

---

Bạn muốn tôi implement cái nào? Hay bạn muốn tôi chọn top 5 macros có ROI cao nhất?
