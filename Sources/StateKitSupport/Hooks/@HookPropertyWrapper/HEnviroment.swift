import SwiftUI

/// A property-wrapper form of `useEnvironment(_:)`.
///
/// `HEnvironment` reads a value from SwiftUI's `EnvironmentValues` inside a
/// hook-driven render scope and exposes it as a plain stored property.
///
/// This is convenience sugar for:
/// ```swift
/// let colorScheme = useEnvironment(\.colorScheme)
/// ```
///
/// written as:
/// ```swift
/// @HEnvironment(\.colorScheme) var colorScheme
/// ```
///
/// Like other hook property wrappers in this package, `HEnvironment` must be
/// used inside `StateScope` or `StateView.stateBody`.
///
/// ### Example
/// ```swift
/// struct ThemeView: StateView {
///     @HEnvironment(\.colorScheme) var colorScheme
///
///     var stateBody: some View {
///         Text(colorScheme == .dark ? "Dark" : "Light")
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct HEnvironment<Value> {

    /// Reads the environment value at `keyPath` for the current render.
    ///
    /// - Parameter keyPath: The SwiftUI environment key path to read.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.wrappedValue = useEnvironment(keyPath)
    }

    /// The environment value resolved for the current render.
    public var wrappedValue: Value

    /// Returns the wrapper itself as the projected value.
    public var projectedValue: Self {
        self
    }

    /// A named alias for `wrappedValue`.
    public var value: Value {
        wrappedValue
    }
}
