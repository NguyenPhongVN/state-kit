# 🪝 Danh Sách Tất Cả Hook Macros

## 1. @Hook - Validate & Document Custom Hooks

**Mục đích:** Validate hook functions, auto-generate documentation

```swift
// Ví dụ sử dụng
@Hook(requiresStateScope: true, stableOrder: true, onlyFirst: true)
public func useClickCounter() -> (Int, () -> Void) {
    let (count, setCount) = useState(0)
    return (count, { setCount(count + 1) })
}

// Macro sinh ra:
// ✅ Runtime validation: must call inside StateScope
// ✅ Static validation: hook order must be stable (no conditionals/loops)
// ✅ Only call once per component check
// ✅ Auto-generated docstring with warnings
```

---

## 2. @HookState - Auto useState Setup

**Mục đích:** Tự động sinh hook function từ struct properties

```swift
// Ví dụ sử dụng
@HookState
struct FormState {
    var username: String = ""
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
}

// Macro auto sinh:
// public func useFormState() -> FormState
// public struct FormStateHooks {
//     var username: (String, (String) -> Void)
//     var email: (String, (String) -> Void)
//     var password: (String, (String) -> Void)
//     var isLoading: (Bool, (Bool) -> Void)
// }

// Sử dụng trong View:
struct LoginView: StateView {
    var stateBody: some View {
        let form = useFormState()
        
        VStack {
            TextField("Username", text: Binding(form.username.0, form.username.1))
            TextField("Email", text: Binding(form.email.0, form.email.1))
            SecureField("Password", text: Binding(form.password.0, form.password.1))
        }
    }
}
```

---

## 3. @HookEffect - Simplify useEffect & Auto Dependencies

**Mục đích:** Tự detect dependencies, giảm lỗi missed dependencies

```swift
// Ví dụ sử dụng
@HookEffect
func useUserData(userId: String) -> User? {
    let (user, setUser) = useState(nil as User?)
    
    let _ = useEffect {  // Macro auto detect: dependencies = [userId]
        Task {
            let fetchedUser = try await fetchUser(userId)
            setUser(fetchedUser)
        }
        return nil
    }
    
    return user
}

// Macro sinh ra:
// - Tự detect: userId parameter là dependency
// - Cảnh báo: nếu quên capture variable nào
// - Generate: useEffect(..., dependencies: [userId])
// - Validate: cleanup function type
```

---

## 4. @HookForm - Form State + Validation + Binding

**Mục đích:** Tạo complete form system tự động

```swift
// Ví dụ sử dụng
@HookForm
struct LoginForm {
    @Field(validate: "required", message: "Username required")
    var username: String = ""
    
    @Field(validate: "minLength:8", message: "Min 8 characters")
    var password: String = ""
    
    @Field(validate: "email", message: "Invalid email")
    var email: String = ""
    
    @Field(validate: "optional")  // Optional field
    var rememberMe: Bool = false
}

// Macro auto sinh:
struct LoginFormHooks {
    var username: (value: String, setter: (String) -> Void, error: String?)
    var password: (value: String, setter: (String) -> Void, error: String?)
    var email: (value: String, setter: (String) -> Void, error: String?)
    var rememberMe: (value: Bool, setter: (Bool) -> Void)
    
    var isValid: Bool
    var isSubmitting: Bool
    var errors: [String: String]
    
    func validate() -> Bool
    func submit() async throws -> Void
    func reset() -> Void
    func setError(_ field: String, _ message: String) -> Void
    
    func usernameBinding() -> Binding<String>
    func passwordBinding() -> Binding<String>
    func emailBinding() -> Binding<String>
    func rememberMeBinding() -> Binding<Bool>
}

// Sử dụng trong View:
struct LoginView: StateView {
    var stateBody: some View {
        let form = useLoginForm()
        
        return VStack(spacing: 12) {
            // Auto TextField with error display
            VStack(alignment: .leading) {
                TextField("Username", text: form.usernameBinding())
                if let error = form.username.error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading) {
                SecureField("Password", text: form.passwordBinding())
                if let error = form.password.error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading) {
                TextField("Email", text: form.emailBinding())
                if let error = form.email.error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            
            Toggle("Remember Me", isOn: form.rememberMeBinding())
            
            Button("Login") {
                form.validate()
                if form.isValid {
                    Task {
                        try await form.submit()
                    }
                }
            }
            .disabled(!form.isValid || form.isSubmitting)
        }
    }
}
```

---

## 5. @HookMemo - Simplify useMemo & Auto Dependencies

**Mục đích:** Tự detect dependencies cho memoized values

```swift
// Ví dụ sử dụng
@HookMemo
func useExpensiveComputation(userId: String, filters: [String]) -> [User] {
    let result = useMemo {  // Macro auto detect: [userId, filters]
        let allUsers = fetchAllUsers()
        return allUsers.filter { user in
            filters.contains(user.category)
        }
    }
    return result
}

// Macro sinh ra:
// - Auto detect dependencies: [userId, filters]
// - useMemo(..., dependencies: [userId, filters])
// - Cảnh báo nếu quên capture
```

---

## 6. @HookCallback - Simplify useCallback & Auto Dependencies

**Mục đích:** Tự detect dependencies cho memoized callbacks

```swift
// Ví dụ sử dụng
@HookCallback
func useUserActions(userId: String, onUpdate: (User) -> Void) -> UserActions {
    let actions = useCallback {
        UserActions(
            delete: { [userId, onUpdate] in
                try await APIClient.deleteUser(userId)
                onUpdate(User())
            },
            update: { [userId, onUpdate] newUser in
                try await APIClient.updateUser(userId, newUser)
                onUpdate(newUser)
            }
        )
    }
    return actions
}

// Macro sinh ra:
// - Auto detect dependencies: [userId, onUpdate]
// - useCallback(..., dependencies: [userId, onUpdate])
```

---

## 7. @HookRef - Simplify useRef Setup

**Mục đích:** Auto create refs từ properties

```swift
// Ví dụ sử dụng
@HookRef
struct TimerRefs {
    var timerHandle: Timer?
    var startTime: Date?
    var elapsedSeconds: Int = 0
}

// Macro sinh ra:
// func useTimerRefs() -> TimerRefs {
//     let timerHandle = useRef(nil as Timer?)
//     let startTime = useRef(nil as Date?)
//     let elapsedSeconds = useRef(0)
//     return TimerRefs(timerHandle, startTime, elapsedSeconds)
// }

struct TimerView: StateView {
    var stateBody: some View {
        let refs = useTimerRefs()
        
        Button("Start") {
            refs.startTime.current = Date()
            refs.timerHandle.current = Timer.scheduledTimer(withTimeInterval: 1) { _ in
                refs.elapsedSeconds.current += 1
            }
        }
    }
}
```

---

## 8. @HookContext - Context Provider/Consumer Helpers

**Mục đích:** Auto sinh context provider và consumer hooks

```swift
// Ví dụ sử dụng
@HookContext
struct UserContext {
    var user: User?
    var setUser: (User) -> Void
    var logout: () -> Void
}

// Macro sinh ra:
// - Context creation
// - Provider component
// - useUserContext() hook
// - Context initialization

// Sử dụng:
struct App: View {
    let (user, setUser) = useState(User?.none)
    
    var body: some View {
        UserContextProvider(user: user, setUser: setUser, logout: { setUser(nil) }) {
            MainView()
        }
    }
}

struct MainView: View {
    let context = useUserContext()
    
    var body: some View {
        Text("User: \(context.user?.name ?? "Anonymous")")
    }
}
```

---

## 9. @HookReducer - useReducer Helper

**Mục đích:** Auto sinh reducer setup

```swift
// Ví dụ sử dụng
@HookReducer
struct CounterReducer {
    typealias State = Int
    
    enum Action {
        case increment
        case decrement
        case reset
    }
    
    func reduce(_ state: inout Int, action: Action) {
        switch action {
        case .increment: state += 1
        case .decrement: state -= 1
        case .reset: state = 0
        }
    }
}

// Macro sinh ra:
// func useCounterReducer(initialState: Int = 0) -> (Int, (CounterReducer.Action) -> Void)

struct CounterView: StateView {
    var stateBody: some View {
        let (count, dispatch) = useCounterReducer()
        
        VStack {
            Text("Count: \(count)")
            Button("+") { dispatch(.increment) }
            Button("-") { dispatch(.decrement) }
            Button("Reset") { dispatch(.reset) }
        }
    }
}
```

---

## 10. @CustomHook - Validate & Document Custom Hooks

**Mục đích:** Validate hook rules, generate documentation

```swift
// Ví dụ sử dụng
@CustomHook(
    stableOrder: true,
    requiresStateScope: true,
    dependencies: ["id", "query"]
)
public func useSearchResults(id: String, query: String) -> [SearchResult] {
    let (results, setResults) = useState([SearchResult]())
    
    let _ = useEffect {
        Task {
            let found = try await search(query)
            setResults(found)
        }
        return nil
    }
    
    return results
}

// Macro sinh ra:
// - Runtime validation: must be inside StateScope
// - Static validation: stable call order
// - Parameter validation: id, query captured correctly
// - Auto documentation
```

---

## 📊 Comparison Table

| Macro | Purpose | Auto-Generate | Dependencies | Validation |
|-------|---------|---------------|----|-----------|
| @Hook | Validate custom hooks | Docs | ✅ | ✅✅✅ |
| @HookState | useState boilerplate | Hook function | ✅ | ✅ |
| @HookEffect | useEffect dependencies | dependencies array | ✅ | ✅✅ |
| @HookForm | Form + validation | Full form system | ✅ | ✅✅✅ |
| @HookMemo | useMemo dependencies | dependencies array | ✅ | ✅✅ |
| @HookCallback | useCallback dependencies | dependencies array | ✅ | ✅✅ |
| @HookRef | useRef boilerplate | Hook function | - | ✅ |
| @HookContext | Context provider/consumer | Provider + hook | - | ✅ |
| @HookReducer | useReducer setup | Hook function | - | ✅ |
| @CustomHook | Validate custom hooks | Docs | ✅ | ✅✅✅ |

---

## 🎯 Đề Xuất Implementation Order

### Priority 1 (Most ROI - Implement First!)
1. **@HookForm** ⭐⭐⭐⭐⭐ - Form handling là use case #1
2. **@HookState** ⭐⭐⭐⭐⭐ - useState boilerplate everywhere
3. **@HookEffect** ⭐⭐⭐⭐ - Reduce dependency bugs
4. **@HookReducer** ⭐⭐⭐ - Common pattern

### Priority 2 (Very Useful)
5. **@HookMemo** ⭐⭐⭐ - Performance optimization
6. **@HookCallback** ⭐⭐⭐ - Performance optimization
7. **@HookRef** ⭐⭐ - Common pattern
8. **@HookContext** ⭐⭐ - Context management

### Priority 3 (Validation & Polish)
9. **@Hook** ⭐⭐ - Validation & safety
10. **@CustomHook** ⭐ - Documentation only

---

0Bạn muốn tôi implement cái nào trước? Tôi đề xuất **top 4 priorities** là tốt nhất!
