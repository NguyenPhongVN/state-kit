# Public API Contracts — DX Essentials

Feature: specs/006-dx-essentials · Date: 2026-09-25

```swift
// StateKitAtoms
public struct SKFocusAtom<Base: SKStateAtom, Field>: SKValueAtom where Base.Value: Sendable
public extension SKStateAtom where Value: Sendable {
    func focus<Field>(_ keyPath: WritableKeyPath<Value, Field>) -> SKFocusAtom<Self, Field>
}

// StateKitPersistence
public protocol FileAtomSerializable: Codable, Sendable {
    static var fileName: String { get }
    static var defaultValue: Self { get }
}
public final class FileAtomStorage<T: FileAtomSerializable>: @unchecked Sendable {
    public init(directory: URL, fileName: String? = nil)
    public func load() -> T          // default on missing/corrupt
    public func save(_ value: T)
    public func delete()
    public func addObserver(_ observer: @escaping (T) -> Void)
}
public func fileAtom<T: FileAtomSerializable>(_ type: T.Type, directory: URL) -> (() -> T)

// StateKitUI
public struct ErrorBoundary<Content: View, Fallback: View>: View {
    public init(onError: ((Error) -> Void)? = nil,
                @ViewBuilder content: @escaping () throws -> Content,
                @ViewBuilder fallback: @escaping (Error) -> Fallback)
}
```

Contracts: focus writes land in the base (single field changed) and notify base dependents;
focus has no stored value. File storage round-trips Codable values and falls back to the
documented default on missing/corrupt files. ErrorBoundary catches synchronous throws from
its own content closure per render pass; fallback errors propagate.
