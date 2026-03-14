// state-kit

/*
 Thư viện tiện ích quản lý state theo phong cách "hooks" cho Swift/SwiftUI. Mục tiêu là mang lại trải nghiệm đơn giản, rõ ràng và an toàn luồng (MainActor) khi làm việc với trạng thái trong View và các tầng logic.

 Tính năng chính
 - API quen thuộc theo phong cách hooks: `useState`, `useBinding`, (và có thể mở rộng thêm như `useEffect`, `useMemo`, ... nếu bạn thêm vào thư viện).
 - Tương thích SwiftUI: dễ dàng tạo `Binding` để kết nối với control như `TextField`, `Toggle`, `Slider`,...
 - An toàn luồng UI: các API được chú thích `@MainActor` (nếu áp dụng) để đảm bảo cập nhật UI đúng luồng.
 - Dễ tích hợp: không phụ thuộc nặng nề, có thể dùng trong dự án sẵn có.
 */

import SwiftUI
import Combine

@MainActor
public final class StateHolder<T>: ObservableObject {
    @Published public var value: T

    public init(_ initial: T) {
        self.value = initial
    }
}

@MainActor
public func useState<T>(_ initial: T) -> StateHolder<T> {
    StateHolder(initial)
}

@MainActor
public func useBinding<T>(_ initial: T) -> Binding<T> {
    let value = useState(initial)
    return Binding {
        value.value
    } set: { newValue in
        value.value = newValue
    }
}


// MARK: - DemoView for quickstart example

struct DemoView: View {
    @State private var forceRerender = false

    var body: some View {
        let counter = useState(0)
        let textBinding = useBinding("")

        VStack(spacing: 16) {
            Text("Giá trị: \(counter.value)")
                .font(.title2)

            TextField("Nhập tên", text: textBinding)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("-1") { counter.value -= 1 }
                Button("+1") { counter.value += 1 }
            }

            Button("Làm mới UI") {
                forceRerender.toggle()
            }
        }
        .padding()
    }
}

// MARK: - ProfileView example

struct ProfileView: View {
    var body: some View {
        let username = useBinding("")
        let age = useState(18)

        Form {
            Section("Thông tin") {
                TextField("Tên người dùng", text: username)
                Stepper("Tuổi: \(age.value)", value: Binding(
                    get: { age.value },
                    set: { age.value = $0 }
                ), in: 0...120)
            }

            Section("Xem trước") {
                Text("@\(username.wrappedValue), \(age.value) tuổi")
            }
        }
    }
}
