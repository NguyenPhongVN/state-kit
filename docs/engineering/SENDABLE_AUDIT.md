# `@unchecked Sendable` Audit — 2026-11-11 (spec 013)

**Phạm vi:** 40 vị trí khai báo `@unchecked Sendable` trong `Sources/` tại tip `261e6a9`.
**Phương pháp:** đọc khai báo + state của từng type, xác định câu chuyện isolation
(confinement / lock / immutability), đối chiếu comment `// Sendable audit 013: …` ngay
tại khai báo. Bảng dưới là nguồn sự thật.

## Verdict tổng

- **0 site unsafe** (không phát hiện race chưa được bảo vệ; FileAtomStorage đã được fix
  lock ở spec 011, theo dõi thêm ở 013 không phát hiện pattern tương tự).
- **1 site accepted-with-fix-history:** `FileAtomStorage` (lock mở rộng 011; deadlock
  notify-in-lock được stress test bắt và sửa trong 011).
- **Nhóm chủ đạo:** provider value-structs giữ `@MainActor` closure + immutable config;
  atom graph state nằm dưới lock của `SKAtomStore`.

## Bảng audit

| # | Type | File | Isolation story | Verdict |
|---|---|---|---|---|
| 1 | `SKAtomStore` | SKAtomStore.swift:38 | Toàn bộ state guarded bởi `NSLock`; mọi public method lấy lock | Accepted (locked) |
| 2 | `SKSubscriberToken` | SKAtomStore.swift:635 | Callback bắn trên MainActor; token chỉ dùng làm identity/hủy | Accepted (MainActor) |
| 3 | `SKAtomKey` | SKAtomKey.swift:16 | Immutable composite; `AnyHashable` chỉ bị hash/so sánh | Accepted (immutable) |
| 4 | `SKAtomBox` | SKAtomBox.swift:16 | Contents chỉ bị đọc/ghi dưới lock của `SKAtomStore` | Accepted (locked) |
| 5 | `SKAtomFamilyDefinition` | SKAtomFamily.swift:30 | Immutable definition, được store giữ theo `id` | Accepted (immutable) |
| 6 | `SKSelectorFamilyDefinition` | SKAtomFamily.swift:70 | Như trên | Accepted (immutable) |
| 7 | `SKAtomRef` | SKAtomRef.swift:28 | Chỉ được thao tác qua store operations (locked graph) | Accepted (locked) |
| 8 | `SKSelectorRef` | SKSelectorRef.swift:23 | Như trên | Accepted (locked) |
| 9 | `SKAsyncAtomRef` | SKAsyncAtomRef.swift:30 | Như trên | Accepted (locked) |
| 10 | `SKThrowingAsyncAtomRef` | SKAsyncAtomRef.swift:73 | Như trên | Accepted (locked) |
| 11 | `SKFocusAtom` | SKFocusAtom.swift:28 | Immutable derived view của base atom (spec 006 thiết kế) | Accepted (immutable) |
| 12 | `CacheAsidePattern` | CachePolicy.swift:11 | Cache + lock nội bộ (`NSLock`), LRU tự bảo vệ | Accepted (locked) |
| 13 | `FileAtomStorage` | FileAtom.swift:36 | `NSLock` guards cachedValue + observers (011 mở rộng) | Accepted (locked, fix-history) |
| 14 | `PersistentAtomStorage` | UserDefaultsAtom.swift:55 | UserDefaults thread-safe; observers guarded bởi `NSLock` | Accepted (locked) |
| 15 | `SwiftDataProviderRef` | SwiftDataIntegration.swift:32 | `ModelContext` chỉ bị chạm trong MainActor call sites | Accepted (MainActor) |
| 16 | `SwiftDataNotifier` | SwiftDataIntegration.swift:110 | Kế thừa `@MainActor AsyncNotifier` | Accepted (MainActor) |
| 17 | `_StoreOverrideBox` | KeychainStateProvider.swift:33 | Immutable `@Sendable` handler captured một lần | Accepted (immutable) |
| 18 | `KeychainNotifier` | KeychainStateProvider.swift:224 | Kế thừa `@MainActor Notifier` | Accepted (MainActor) |
| 19 | `PumpPublisher` | AsyncSequence+Extensions.swift:61 | Pump task là single writer; Combine lo cross-thread delivery | Accepted (single-writer) |
| 20 | `DispatchTimeInterval` extension | DispatchTimeInterval+Extensions.swift:91 | Enum value-type immutable | Accepted (immutable) |
| 21 | `KeepAliveCloseFlag` | ProviderElement.swift:465 | One-shot flag guarded bởi `NSLock` | Accepted (locked) |
| 22 | `HookContext` | useContext.swift:34 | Slot state confined trong render pass (`StateRuntime`, MainActor) | Accepted (MainActor) |
| 23 | `ProviderOverride` | ProviderProtocol.swift:255 | Immutable value wrapper | Accepted (immutable) |
| 24 | `SelectorProvider` | ProviderProtocol.swift:295 | Immutable config + `@MainActor` closure | Accepted (immutable) |
| 25 | `ProviderID` | ProviderID.swift:25 | Immutable; identifier chỉ hash/so sánh | Accepted (immutable) |
| 26-38 | Provider value-structs (`Provider`, `StateProvider`, `StateProviderNotifier`, `FutureProvider`, `FutureFutureProvider`, `StreamProvider`, `AsyncSequenceProvider`, `NotifierProvider`, `NotifierInstanceProvider`, `AsyncNotifierProvider`, `AsyncNotifierInstanceProvider`, `AsyncNotifierFutureProvider`) | Providers/*.swift | Immutable config; build closure `@MainActor`; mọi engine access qua container (MainActor-confined) | Accepted (immutable + MainActor) |

## Ghi chú

- `AnyHashable` không Sendable — các key/wrapper dùng `@unchecked` để hash/so sánh bền
  vững; giá trị bị erase không bao giờ bị escape ra ngoài kiểu Sendable.
- Fix thật khi audit: không phát hiện site mới cần sửa hành vi. Bài học FileAtomStorage
  (011) đã được khóa lại bằng stress test.
- Mỗi site mang comment `// Sendable audit 013: <story>` tại khai báo để reviewer thấy
  ngay mà không cần mở bảng này.
