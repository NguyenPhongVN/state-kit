/// Logs lifecycle events (mounted, updated, unmounted) and optional items when the hook runs. Useful for debugging and monitoring when a scope is evaluated.
///
/// - Parameters:
///   - fileID: Source file ID (default: caller’s `#fileID`).
///   - line: Source line (default: caller’s `#line`).
///   - updateStrategy: When to re-run and log (default: `.once`).
///   - name: Optional name or identifier for the log line.
///   - items: Zero or more items to print.
///   - separator: String between each item (default: `" "`).
///   - terminator: String after all items (default: `"\n"`).
@MainActor public func usePrint(
    updateStrategy: UpdateStrategy? = .once,
    _ items: Any...,
    fileID: String = #fileID,
    line: UInt = #line,
    name: String = "",
    separator: String = " ",
    terminator: String = "\n"
) {

    useMemo(updateStrategy: updateStrategy) {
#if DEBUG
        print("🚀", sourceId(fileID: fileID, line: line), name)
        for item in items {
            print(item, separator: separator, terminator: terminator)
        }
#endif
    }
}
