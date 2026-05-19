# Hook Macros Examples

This file contains concise examples for the most-used hook macros.

## `@Hook`

```swift
@Hook
func useClickCounter() -> (Int, () -> Void) {
    let (count, setCount) = useState(0)
    return (count, { setCount(count + 1) })
}
```

## `@HookState`

```swift
@HookState
struct LoginState {
    var email: String = ""
    var password: String = ""
}

struct LoginView: StateView {
    var stateBody: some View {
        let state = useLoginState()
        return VStack {
            TextField("Email", text: Binding(state.email.0, state.email.1))
            SecureField("Password", text: Binding(state.password.0, state.password.1))
        }
    }
}
```

## `@HookEffect`

```swift
@HookEffect
func useUserData(userId: String) -> User? {
    let (user, setUser) = useState(nil as User?)

    let _ = useEffect {
        Task { setUser(try await fetchUser(userId)) }
        return nil
    }

    return user
}
```

## `@HookForm`

```swift
@HookForm
struct LoginForm {
    var email: String = ""
    var password: String = ""
}

struct LoginView: StateView {
    var stateBody: some View {
        let form = useLoginForm()
        return VStack {
            TextField("Email", text: form.emailBinding())
            SecureField("Password", text: form.passwordBinding())
            Button("Login") {
                if form.validate() {
                    Task { try await form.submit() }
                }
            }
        }
    }
}
```

## `@HookMemo` and `@HookCallback`

```swift
@HookMemo
struct FullNameMemo {
    var first: String = "Ada"
    var last: String = "Lovelace"
    func build() -> String { "\(first) \(last)" }
}

@HookCallback
struct SaveCallback {
    func callback() {}
}
```
