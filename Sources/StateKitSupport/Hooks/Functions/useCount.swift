import StateKit
/// A hook that returns the number of times the current scope has been evaluated.
/// The count is incremented on each evaluation and is stable for the given `updateStrategy`.
///
///     let count = useCount(.once)
///     // count increases each time the hook is re-evaluated according to updateStrategy
///
/// - Parameter updateStrategy: A strategy that determines when to re-run the counter (default: `.once`).
/// - Returns: The current evaluation count for this hook in the scope.
@MainActor public func useCount(
    updateStrategy: UpdateStrategy = .once
) -> Int {
    @HRef var count = 0
    useMemo(updateStrategy: updateStrategy) {
        count += 1
    }
    return count
}
