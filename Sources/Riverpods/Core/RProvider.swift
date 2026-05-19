/// Namespace for Riverpod macro-generated provider constants.
///
/// Swift 6 requires peer macros at file scope to only introduce extensions,
/// not standalone `let` declarations.  All function-attached Riverpod macros
/// (`@Provider`, `@FutureProvider`, etc.) therefore emit their generated provider
/// as a `static let` inside an `extension` on this type.
public enum RProvider {}
