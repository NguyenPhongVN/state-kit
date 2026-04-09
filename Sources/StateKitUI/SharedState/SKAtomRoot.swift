import SwiftUI
import StateKitAtoms

/// The root view that provides an `SKAtomStore` to its descendants.
///
/// Wrap your app's root view (or a subtree) in `SKAtomRoot` to ensure all
/// atom property wrappers (`@SKValue`, `@SKState`, `@SKTask`, `@SKAtomContext`)
/// resolve against the same store instance.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             SKAtomRoot {
///                 ContentView()
///             }
///         }
///     }
/// }
/// ```
///
/// ## Scoped stores
///
/// For tests, Xcode Previews, or UI isolation, use `SKAtomScopeView` to
/// inject a fresh store into a subtree without affecting the rest of the app.
///
/// ## Multiple roots
///
/// You can nest `SKAtomRoot` views. Each provides its own store; inner atoms
/// resolve against the innermost root.
public struct SKAtomRoot<Content: View>: View {

    // MARK: - State

    /// The store owned by this root. Created once and retained for the
    /// lifetime of this view.
    @State private var store = SKAtomStore()

    // MARK: - Content

    private let content: Content

    // MARK: - Init

    /// Creates a root view that owns a new `SKAtomStore`.
    ///
    /// - Parameter content: The view hierarchy to wrap.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        content
            .environment(\.skAtomStore, store)
    }
}

// MARK: - View modifier convenience

extension View {
    /// Wraps this view with an `SKAtomRoot`, providing a new `SKAtomStore`
    /// to all descendants.
    ///
    /// ```swift
    /// ContentView()
    ///     .atomRoot()
    /// ```
    public func atomRoot() -> some View {
        SKAtomRoot { self }
    }
}
