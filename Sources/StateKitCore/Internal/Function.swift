/// Returns a modified closure that emits the latest non-nil value
/// if the original closure would return nil.
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

/// Creates a closure (T?) -> T? that returns last non-`nil` T passed to it.
///
/// - SeeAlso: https://github.com/Thomvis/Construct/blob/main/Construct/Foundation/Memoize.swift
internal func replayNonNil<T>() -> (T?) -> T? {
    replayNonNil { $0 }
}

internal func ignore<T>(_ t: T) -> Void { }
internal func identity<T>(_ t: T) -> T { t }
internal func absurd<T>(_ never: Never) -> T { }

internal func guardFunction<Content>(_ condition: Content?, else: () -> Content) -> Content {
    if let condition {
        return condition
    }
    return `else`()
}

/// Utilty for applying a transform to a value.
/// - Parameters:
///   - condition: An optional value to be evaluated.
///   - else: A closure that is executed and its result is returned if `condition` is nil.
/// - Returns: The value of `condition` if it is not nil; otherwise, the result of the `else` closure.
internal func apply<T>(_ input: T,_ transform: (inout T) -> Void) -> T {
    var input = input
    transform(&input)
    return input
}

/// Utilty for applying a transform to a value.
/// - Parameters:
///   - transform: The transform to apply.
///   - input: The value to be transformed.
/// - Returns: The transformed value.
internal func transform<T>(_ input: T,_ transform: (inout T) -> Void) -> T {
    var input = input
    transform(&input)
    return input
}

/// return description sourceId
/// - Parameters:
///   - id: id description
///   - fileID: fileID description
///   - line: line description
/// - Returns: description
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
