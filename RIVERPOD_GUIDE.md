# StateKit Riverpod Guide

Chào mừng bạn đến với hệ thống quản lý trạng thái Riverpod trong StateKit. Đây là bản triển khai Riverpod được tối ưu hóa cho Swift hiện đại (Swift 5.9+), tận dụng framework **Observation** và **Async/Await**.

## 1. Các loại Provider cơ bản

### Provider
Dùng cho các giá trị read-only hoặc các giá trị tính toán (Computed values).
```swift
let appVersionProvider = Provider { ref in "1.0.0" }

let greetingProvider = Provider { ref in
    let name = ref.watch(nameProvider)
    return "Hello, \(name)!"
}
```

### StateProvider
Dùng cho các trạng thái đơn giản có thể thay đổi trực tiếp.
```swift
let counterProvider = StateProvider { ref in 0 }

// Trong View
@Watch(counterProvider) var count
// Để thay đổi
ref.read(counterProvider.notifier).state += 1
```

### NotifierProvider
Dùng cho logic quản lý state phức tạp.
```swift
class Counter: Notifier<Int> {
    override func build() -> Int { 0 }
    func increment() { state += 1 }
}
let counterProvider = NotifierProvider { Counter() }
```

### AsyncNotifierProvider
Loại mạnh mẽ nhất để quản lý state bất đồng bộ.
```swift
class UserProfile: AsyncNotifier<User> {
    override func build() async throws -> User {
        try await api.fetchUser()
    }
    
    func updateName(_ newName: String) async {
        state = .loading(previousData: state.value)
        state = await AsyncValue.guard {
            try await api.updateName(newName)
        }
    }
}
let userProvider = AsyncNotifierProvider { UserProfile() }
```

---

## 2. Các tính năng nâng cao

### Lifecycle Hooks
Bạn có thể can thiệp vào vòng đời của một Provider để quản lý tài nguyên.
```swift
let socketProvider = Provider { ref in
    let socket = Socket()
    
    ref.onDispose { socket.disconnect() }
    ref.onCancel { print("No more listeners") }
    ref.onResume { print("Listener re-attached") }
    
    return socket
}
```

### Cache & Dispose Delay
Giữ cho state không bị hủy ngay lập tức khi user chuyển màn hình.
```swift
let searchProvider = FutureProvider(cacheTime: 30.0) { ref in
    try await api.search(...)
}
```

### Keep Alive
Giữ cho provider sống mãi mãi (hoặc cho đến khi đóng link).
```swift
let syncProvider = Provider { ref in
    let link = ref.keepAlive()
    // ... thực hiện sync dữ liệu ngầm ...
    // link.close() khi muốn cho phép hủy
}
```

---

## 3. Xử lý AsyncValue (Smooth UX)

Sử dụng hàm `when` để hiển thị UI mượt mà, hỗ trợ cả dữ liệu cũ khi đang load.

```swift
let state = ref.watch(userProvider)

state.when(
    data: { user in ProfileView(user) },
    error: { err, prevData in
        VStack {
            if let user = prevData { ProfileView(user).opacity(0.5) }
            Text("Error: \(err.localizedDescription)")
        }
    },
    loading: { prevData in
        ZStack {
            if let user = prevData { ProfileView(user).opacity(0.5) }
            ProgressView()
        }
    }
)
```

---

## 4. Hệ sinh thái StateKit (Atom Bridge)

Bạn có thể kết hợp cả Atoms và Riverpods trong cùng một logic.

### Watch Atom từ Riverpod
```swift
let myProvider = Provider { ref in
    let atomValue = ref.watch(myAtom) // Riverpod lắng nghe Atom
    return "From Atom: \(atomValue)"
}
```

### Watch Riverpod từ Atom
```swift
let myRiverpodAtom = userProvider.asAtom() // Chuyển Provider thành Atom

struct MyView: View {
    @SKValue(myRiverpodAtom) var userValue // Dùng như một Atom bình thường
}
```

---

## 5. Debugging & Logging

Sử dụng `ProviderObserver` để theo dõi toàn bộ ứng dụng.

```swift
class Logger: ProviderObserver {
    func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {
        print("[\(provider.name ?? "Unknown")] Updated")
    }
}

// Khởi tạo
let container = ProviderContainer(observers: [Logger()])
```

---

## 6. Testing & Overrides

Mocking dữ liệu cho Unit Test hoặc SwiftUI Preview.

```swift
let container = ProviderContainer(overrides: [
    userProvider.overrideWith(.data(User.mock)),
    // Hoặc override cả logic
    apiProvider.overrideWithProvider(MockApiProvider())
])
```
