# Hook Macros - Ví dụ Sử Dụng

## 1. @Hook - Validate & Document Custom Hooks

### Trước (không có macro):
```swift
/// Đếm người dùng click
/// - Important: Must be called inside StateScope
/// - Note: Can only be called in stable order (no loops/conditionals)
public func useClickCounter() -> (Int, () -> Void) {
    let (count, setCount) = useState(0)
    return (count, { setCount(count + 1) })
}
```

### Sau (với @Hook macro):
```swift
@Hook(requiresStateScope: true, stableOrder: true)
public func useClickCounter() -> (Int, () -> Void) {
    let (count, setCount) = useState(0)
    return (count, { setCount(count + 1) })
}
```

**Macro sinh ra:**
- ✅ Validate gọi hook trong StateScope
- ✅ Validate hook order không thay đổi
- ✅ Auto sinh documentation warnings

---

## 2. @HookState - Auto useState Setup

### Trước (boilerplate nhiều):
```swift
struct FormState {
    @HookState var username: String = ""
    @HookState var email: String = ""
    @HookState var password: String = ""
    @HookState var isLoading: Bool = false
}

// Phải viết thêm:
func useFormState() -> (String, (String) -> Void, String, (String) -> Void, ...) {
    let (username, setUsername) = useState("")
    let (email, setEmail) = useState("")
    let (password, setPassword) = useState("")
    let (isLoading, setIsLoading) = useState(false)
    
    return (username, setUsername, email, setEmail, password, setPassword, isLoading, setIsLoading)
}
```

### Sau (với @HookState macro):
```swift
@HookState 
struct FormState {
    var username: String = ""
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
}

// Macro tự sinh hook function:
struct CounterView: StateView {
    var stateBody: some View {
        let form = useFormState()  // Tự sinh từ macro!
        
        VStack {
            TextField("Username", text: Binding(form.username, form.setUsername))
            TextField("Email", text: Binding(form.email, form.setEmail))
            SecureField("Password", text: Binding(form.password, form.setPassword))
        }
    }
}
```

**Macro sinh ra:**
- ✅ Hook function `useFormState()` tự động
- ✅ Getter/setter cho từng property
- ✅ Binding support tự động

---

## 3. @HookEffect - Simplify useEffect & Dependencies

### Trước (dễ quên dependencies):
```swift
@MainActor
func useUserData(userId: String) -> User? {
    let (user, setUser) = useState(nil as User?)
    
    useEffect(dependencies: [userId]) {  // Phải tự liệt kê!
        Task {
            let fetchedUser = try await fetchUser(userId)
            setUser(fetchedUser)
        }
        return nil
    }
    
    return user
}
```

### Sau (với @HookEffect macro):
```swift
@HookEffect
func useUserData(userId: String) -> User? {
    let (user, setUser) = useState(nil as User?)
    
    // Macro tự detect dependencies: [userId]
    let _ = useEffect {
        Task {
            let fetchedUser = try await fetchUser(userId)
            setUser(fetchedUser)
        }
        return nil
    }
    
    return user
}
```

**Macro sinh ra:**
- ✅ Tự detect dependencies từ function parameters
- ✅ Cảnh báo nếu quên capture variable
- ✅ Generate dependencies array tự động

---

## 4. @HookForm - Form State + Validation

### Trước (nhiều boilerplate):
```swift
struct LoginView: StateView {
    var stateBody: some View {
        let (username, setUsername) = useState("")
        let (password, setPassword) = useState("")
        let (errors, setErrors) = useState(["username": "", "password": ""])
        let (isSubmitting, setIsSubmitting) = useState(false)
        
        let validateUsername: () -> Bool = {
            let valid = !username.isEmpty && username.count >= 3
            if !valid {
                setErrors(["username": "Username phải ≥ 3 ký tự"])
            }
            return valid
        }
        
        let handleSubmit = {
            setIsSubmitting(true)
            if validateUsername() && !password.isEmpty {
                // Submit...
            }
            setIsSubmitting(false)
        }
        
        return VStack {
            TextField("Username", text: Binding(username, setUsername))
            if let error = errors["username"], !error.isEmpty {
                Text(error).foregroundColor(.red)
            }
            // ... password field
            Button("Login", action: handleSubmit)
                .disabled(isSubmitting)
        }
    }
}
```

### Sau (với @HookForm macro):
```swift
@HookForm
struct LoginForm {
    @Field(validate: "minLength:3")
    var username: String = ""
    
    @Field(validate: "required")
    var password: String = ""
}

struct LoginView: StateView {
    var stateBody: some View {
        let form = useLoginForm()  // Macro sinh tất cả!
        
        return VStack {
            form.usernameField()     // Auto TextField + error display
            form.passwordField()      // Auto SecureField + error display
            
            Button("Login") {
                form.validate()  // Tự chạy tất cả validators
                if form.isValid {
                    form.submit()
                }
            }
            .disabled(form.isSubmitting)
        }
    }
}
```

**Macro sinh ra:**
- ✅ Hook function `useLoginForm()`
- ✅ Validation tự động từ @Field attributes
- ✅ Error message display helpers
- ✅ Submit handling boilerplate
- ✅ isValid, isSubmitting, isLoading states

---

## So Sánh Tính Năng

| Feature | @Hook | @HookState | @HookEffect | @HookForm |
|---------|-------|-----------|------------|-----------|
| Validate hook rules | ✅ | - | - | - |
| Auto sinh hook function | - | ✅ | - | ✅ |
| Dependencies tracking | - | - | ✅ | - |
| Form validation | - | - | - | ✅ |
| Binding support | - | ✅ | - | ✅ |
| Error handling | - | - | - | ✅ |
| Giảm boilerplate | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |

---

## Đề Xuất Ưu Tiên (từ tốt nhất):

1. **@HookForm** - Giảm boilerplate form nhất, dùng thường xuyên
2. **@HookState** - Dùng cho tất cả state setups, tiết kiệm code
3. **@HookEffect** - Giảm lỗi missed dependencies, safety improvement
4. **@Hook** - Validation tốt nhưng ít critical
