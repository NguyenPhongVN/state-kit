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
///   - line: The source line number; populated automatically by the
///     compiler via `#line`. Do not pass this argument manually.
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
