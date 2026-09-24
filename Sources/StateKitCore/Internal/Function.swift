/// Unwraps `condition` and returns it if non-nil; otherwise calls `else` and
/// returns its result.
///
/// A typed alternative to the `??` operator for cases where the fallback is
/// produced by a closure rather than a pre-evaluated expression.
///
/// - Parameters:
///   - condition: An optional value to unwrap.
///   - else: A closure called only when `condition` is `nil`.
/// - Returns: The unwrapped value of `condition`, or the result of `else()`.
internal func guardFunction<Content>(_ condition: Content?, else: () -> Content) -> Content {
    if let condition {
        return condition
    }
    return `else`()
}
