import Foundation
import Riverpods
import Combine

// MARK: - 1. Basic Providers

/// Một StateProvider đơn giản để quản lý số đếm.
let counterProvider = StateProvider { _ in 0 }

/// Một Provider phái sinh (derived), tự động cập nhật khi counter thay đổi.
let doubleCounterProvider = Provider { ref in
    let count = ref.watch(counterProvider)
    return count * 2
}

// MARK: - 2. Notifier Providers

/// Notifier quản lý danh sách công việc.
class TodoNotifier: Notifier<[String]> {
    override func build() -> [String] {
        ["Learn Swift", "Build Riverpod"]
    }
    
    func add(_ todo: String) {
        state.append(todo)
    }
    
    func remove(at index: Int) {
        state.remove(at: index)
    }
}

let todoListProvider = NotifierProvider { TodoNotifier() }

/// AsyncNotifier thực hiện logic bất đồng bộ phức tạp.
class UserProfileNotifier: AsyncNotifier<String> {
    override func build() async throws -> String {
        // Giả lập gọi API
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Mike Packard"
    }
    
    func updateName(_ newName: String) async {
        state = .loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        state = .data(newName)
    }
}

let userProfileProvider = AsyncNotifierProvider { UserProfileNotifier() }

// MARK: - 3. Async Providers

/// FutureProvider cho tác vụ một lần.
let weatherProvider = FutureProvider { _ in
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return "Sunny ☀️"
}

/// StreamProvider cho luồng dữ liệu liên tục.
let clockProvider = StreamProvider { _ in
    Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .map { "\($0.formatted(date: .omitted, time: .standard))" }
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

// MARK: - 4. Advanced Providers (Family & Select)

/// Family cho phép tạo provider dựa trên ID.
let userDetailProvider = Provider.family { (ref, id: Int) in
    "User Details for ID: \(id)"
}

/// Struct cho Select demo.
struct SettingsState: Hashable {
    var theme: String = "Dark"
    var notificationsEnabled: Bool = true
}

let settingsProvider = StateProvider { _ in SettingsState() }

/// Chỉ chọn thuộc tính theme để theo dõi.
let themeOnlyProvider = settingsProvider.select(\.theme)
