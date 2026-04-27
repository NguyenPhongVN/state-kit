# StateKit Manual

Tài liệu này tổng hợp toàn bộ API của `StateKit` (Hooks, Atoms và Concurrency) đang được demo trong ứng dụng `CaseStudies`.

---

## 1. Scoped Hook API (Local State)

| Nhóm | API |
|------|-----|
| State | `useState`, `useBinding`, `useReducer`, `useRef`, `useMemo`, `useCallback` |
| Data Flow | `useContext`, `useEnvironment`, `useOnChange` |
| Effects | `useEffect`, `useLayoutEffect` |
| Async | `useAsync`, `useAsyncSequence`, `usePublisher` |
| Runtime | `StateScope`, `StateView`, `UpdateStrategy` |

### Runtime quan trọng
- **`StateScope`**: Bắt buộc phải bọc quanh code có sử dụng hook.
- **`UpdateStrategy`**: Kiểm soát việc chạy lại hook (`.once`, `.preserved(by:)`).

---

## 2. Atom API (Global State)

Atom là đơn vị trạng thái độc lập, có thể truy cập từ bất cứ đâu trong ứng dụng.

| Loại Atom | Protocol | Mô tả |
|-----------|----------|-------|
| State Atom | `SKStateAtom` | Lưu trữ dữ liệu có thể đọc/ghi trực tiếp. |
| Value Atom | `SKValueAtom` | Dữ liệu phái sinh (derived), tự cập nhật khi atom nguồn đổi. |
| Task Atom | `SKTaskAtom` | Thực hiện async task không ném lỗi. |
| Throwing Task | `SKThrowingTaskAtom` | Thực hiện async task có ném lỗi (`throws`). |
| Publisher | `SKPublisherAtom` | Kết nối với Combine Publisher. |

### Cách sử dụng (Property Wrappers)
- **`@SKState(MyAtom())`**: Đọc/ghi state atom.
- **`@SKValue(MyDerivedAtom())`**: Đọc giá trị phái sinh (read-only).
- **`@SKTask(MyAsyncAtom())`**: Theo dõi trạng thái của async task (`AsyncPhase`).
- **`@SKContext`**: Truy cập store một cách imperative (cho action handler).

---

## 3. Concurrency Utilities (SCTask)

Bộ công cụ mở rộng cho Swift Concurrency và `AsyncSequence`.

### Task Extensions
- **`Task.retrying`**: Tự động thử lại khi gặp lỗi (hỗ trợ exponential backoff).
- **`Task.throwingTimeout`**: Giới hạn thời gian thực thi của một task.
- **`Task.gather`**: Chạy song song nhiều task và thu thập kết quả (có giới hạn số luồng).
- **`Task.race`**: Chạy đua nhiều task, lấy kết quả nhanh nhất.

### AsyncSequence Operators
- **`.timeout(_:)`**: Ngắt stream nếu không có dữ liệu mới trong khoảng thời gian quy định.
- **`.debounce(for:)`**: Trì hoãn phát dữ liệu cho đến khi stream ổn định.

---

## 4. Chi tiết các Hook phổ biến

### `useState` / `useBinding`
Quản lý trạng thái cục bộ. `useBinding` trả về `Binding<T>` của SwiftUI.

```swift
let (count, setCount) = useState(0)
let name = useBinding("")
```

### `useMemo` / `useCallback`
Tối ưu hiệu năng bằng cách cache giá trị hoặc closure.

```swift
let sorted = useMemo(updateStrategy: .preserved(by: items)) { items.sorted() }
let onClick = useCallback(updateStrategy: .preserved(by: id)) { print(id) }
```

### `useEffect` / `useLayoutEffect`
Chạy side effect sau render. Hỗ trợ hàm cleanup để dọn dẹp tài nguyên.

```swift
useEffect(updateStrategy: .preserved(by: socketURL)) {
    let socket = connect(socketURL)
    return { socket.disconnect() } // Cleanup
}
```

### `useAsync` / `useAsyncSequence`
Làm việc với code bất đồng bộ một cách reactive.

```swift
let phase = useAsync(updateStrategy: .preserved(by: query)) {
    try await search(query)
}
```

---

## 5. Property Wrappers (Tiện ích)

Dùng để rút gọn code khi khai báo bên trong `StateView` hoặc `StateScope`.

- **`@HState`**: Shortcut cho `useBinding`.
- **`@HMemo`**: Shortcut cho `useMemo`.
- **`@HRef`**: Shortcut cho `useRef`.
- **`@HEnvironment`**: Shortcut cho `useEnvironment`.

---

## 6. Gợi ý chọn nhanh

| Nếu bạn cần... | Hãy dùng... |
|----------------|-------------|
| State đơn giản | `useState` |
| Binding cho control | `useBinding` hoặc `@HState` |
| Logic update phức tạp | `useReducer` |
| Giá trị không re-render | `useRef` hoăc `@HRef` |
| Tối ưu tính toán | `useMemo` hoặc `@HMemo` |
| Side effect sau render | `useEffect` |
| Gọi API một lần | `useAsync` |
| Luồng dữ liệu | `useAsyncSequence` hoặc `SKPublisherAtom` |
