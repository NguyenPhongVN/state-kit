import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Debounce: Wraps an `async` function with a debounced peer that delays execution.
///
/// Attached to an `async` function. Generates a `debounced()` peer function and a private
/// `_debounceTask` variable. Each call to `debounced()` cancels any pending execution and
/// reschedules it after the specified delay in milliseconds.
///
/// ── Example ──────────────────────────────────────────────────────────
///   @Debounce(300)
///   func search(query: String) async {
///       // network call
///   }
///
/// Expands to:
///   func search(query: String) async { ... }
///
///   @MainActor
///   private var _searchDebounceTask: Task<Void, Never>?
///
///   @MainActor
///   func searchDebounced() {
///       _searchDebounceTask?.cancel()
///       _searchDebounceTask = Task {
///           try? await Task.sleep(nanoseconds: UInt64(300) * 1_000_000)
///           if !Task.isCancelled {
///               await search()
///           }
///       }
///   }
///
/// Usage:
///   searchDebounced()  // cancels previous, re-schedules after 300ms
///
/// ## Generated Members
/// - `private var _debounceTask: Task<Void, Never>?` — tracks the pending execution.
/// - `func debounced()` — cancels pending work and re-schedules after the delay.
///
/// ## User Requirements
/// - The function must be marked `async`.
/// - Pass the delay in milliseconds as the first argument: `@Debounce(300)`.
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated members.
/// - Both generated members are marked `@MainActor`.
public struct DebounceMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        
        let (_, staticKeyword) = AttributeHelper.modifierPrefixes(from: funcDecl)

        // Extract the delay expression (any expression, not just integer literals)
        let delayExpr: String
        if let args = node.arguments?.as(LabeledExprListSyntax.self),
           let firstArg = args.first {
            delayExpr = firstArg.expression.trimmedDescription
        } else {
            throw MacroError.custom("@Debounce requires a milliseconds argument, e.g. @Debounce(300)")
        }

        let taskDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)private var _\(raw: functionName)DebounceTask: Task<Void, Never>?
        """

        let debouncedFunc: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: functionName)Debounced() {
            _\(raw: functionName)DebounceTask?.cancel()
            _\(raw: functionName)DebounceTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(\(raw: delayExpr)) * 1_000_000)
                if !Task.isCancelled {
                    await \(raw: functionName)()
                }
            }
        }
        """

        return [taskDecl, debouncedFunc]
    }
}
