/// Returns a wrapper around `f` that caches the last non-nil result and
/// replays it when `f` would return `nil`.
///
/// On each call the wrapper invokes `f($0)`. If the result is non-nil it is
/// stored in an internal memo and returned. If the result is `nil` the last
/// cached non-nil value is returned instead (or `nil` if `f` has never
/// returned a non-nil value).
///
/// - SeeAlso: https://github.com/Thomvis/Construct/blob/main/Construct/Foundation/Memoize.swift
internal func replayNonNil<A, B>(_ f: @escaping (A) -> B?) -> (A) -> B? {
    var memo: B?
    return {
        if let res = f($0) {
            memo = res
            return res
        }
        return memo
    }
}

/// Returns a closure `(T?) -> T?` that caches and replays the last non-nil
/// value passed to it.
///
/// Convenience overload of `replayNonNil(_:)` using the identity function,
/// equivalent to `replayNonNil { $0 }`.
///
/// - SeeAlso: https://github.com/Thomvis/Construct/blob/main/Construct/Foundation/Memoize.swift
internal func replayNonNil<T>() -> (T?) -> T? {
    replayNonNil { $0 }
}

/// Discards `t` and returns `Void`. Useful as a closure adapter where a
/// `(T) -> Void` signature is required but the value is not needed.
internal func ignore<T>(_ t: T) -> Void { }

/// Returns `t` unchanged. Standard identity function; useful as a default
/// transform or in higher-order function pipelines.
internal func identity<T>(_ t: T) -> T { t }

/// Proves ex falso quodlibet: converts an uninhabited `Never` value into any
/// type `T`. Because `Never` has no cases this function can never actually be
/// called; it exists to satisfy the type system in exhaustive switches over
/// `Never`-typed expressions.
internal func absurd<T>(_ never: Never) -> T { }

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

/// Returns a copy of `input` with `transform` applied to it.
///
/// Copies `input` into a local `var`, passes it to `transform` as `inout`,
/// then returns the modified copy. The original value is never mutated.
///
/// - Parameters:
///   - input: The value to transform.
///   - transform: A closure that mutates `input` in place.
/// - Returns: The transformed copy of `input`.
internal func apply<T>(_ input: T,_ transform: (inout T) -> Void) -> T {
    var input = input
    transform(&input)
    return input
}

/// Returns a copy of `input` with `transform` applied to it.
///
/// Copies `input` into a local `var`, passes it to `transform` as `inout`,
/// then returns the modified copy. The original value is never mutated.
///
/// - Parameters:
///   - input: The value to transform.
///   - transform: A closure that mutates `input` in place.
/// - Returns: The transformed copy of `input`.
internal func transform<T>(_ input: T,_ transform: (inout T) -> Void) -> T {
    var input = input
    transform(&input)
    return input
}

/// Builds a string identifier from the call-site's file and line number,
/// with an optional custom prefix.
///
/// Used internally to produce stable, human-readable identifiers for
/// hook slots or debug labels without requiring the caller to supply one
/// explicitly.
///
/// - Parameters:
///   - id: An optional custom identifier. When non-empty it is appended to
///     the string. Defaults to `""`.
///   - fileID: The source file identifier; populated automatically by the
///     compiler via `#fileID`. Do not pass this argument manually.
///   - line: The source line number; populated automatically by the compiler
///     via `#line`. Do not pass this argument manually.
/// - Returns: `"fileID: <fileID> line: <line>"` when `id` is empty, or
///   `"fileID: <fileID> line: <line> id: <id>"` when `id` is non-empty.
internal func sourceId(
    id: String = "",
    fileID: String = #fileID,
    line: UInt = #line
) -> String {
    if id.isEmpty {
        return "fileID: \(fileID) line: \(line)"
    } else {
        return "fileID: \(fileID) line: \(line) id: \(id)"
    }
}
