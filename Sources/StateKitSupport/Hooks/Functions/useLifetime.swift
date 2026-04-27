/// Runs `action` exactly once during the lifetime of the enclosing
/// `StateScope`, the first time that scope appears.
///
/// This is similar to a "first appear" callback, not SwiftUI's plain
/// `onAppear`. If the same `StateScope` instance re-renders, the action is
/// not run again. A new `StateScope` instance gets its own first-appearance
/// callback.
///
/// - Parameter action: The closure to run the first time this scope appears.
@MainActor
public func useOnFirstAppear(
    _ action: (() -> Void)? = nil
) {
    useEffect(updateStrategy: .once) {
        action?()
        return nil
    }
}

/// Registers `action` to run when the enclosing `StateScope` is finally
/// removed from the view hierarchy.
///
/// This is similar to a "last disappear" callback, not SwiftUI's plain
/// `onDisappear`. The action runs from the cleanup of a `.once` effect, so it
/// fires when this scope's lifetime ends.
///
/// - Parameter action: The closure to run when this scope finally disappears.
@MainActor
public func useOnLastDisappear(
    _ action: (() -> Void)? = nil
) {
    useEffect(updateStrategy: .once) {
        return {
            action?()
        }
    }
}
