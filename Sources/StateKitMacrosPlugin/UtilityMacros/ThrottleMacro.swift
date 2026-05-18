import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Throttle: Wraps an `async` function with a throttled peer that limits execution rate.
///
/// Attached to an `async` function. Generates a `throttled()` peer function and a private
/// `_throttleLastExecution` variable. Calls to `throttled()` are ignored if the last execution
/// occurred within the specified interval in milliseconds.
///
/// ── Example ──────────────────────────────────────────────────────────
///   @Throttle(1000)
///   func syncData() async {
///       // network call
///   }
///
/// Expands to:
///   func syncData() async { ... }
///
///   @MainActor
///   private var _syncDataThrottleLastExec: Date = Date(timeIntervalSince1970: 0)
///
///   @MainActor
///   func syncDataThrottled() {
///       let now = Date()
///       let interval = TimeInterval(1000) / 1000.0
///       if now.timeIntervalSince(_syncDataThrottleLastExec) >= interval {
///           _syncDataThrottleLastExec = now
///           Task { await syncData() }
///       }
///   }
///
/// Usage:
///   syncDataThrottled()  // ignored if called more than once per second
///
/// ## Generated Members
/// - `private var _throttleLastExecution: Date` — tracks the last execution timestamp.
/// - `func throttled()` — executes the wrapped function only if enough time has elapsed.
///
/// ## User Requirements
/// - The function must be marked `async`.
/// - Pass the minimum interval in milliseconds as the first argument: `@Throttle(1000)`.
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated members.
/// - Both generated members are marked `@MainActor`.
public struct ThrottleMacro: PeerMacro {
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

        // Extract the interval expression (any expression, not just integer literals)
        let intervalExpr: String
        if let args = node.arguments?.as(LabeledExprListSyntax.self),
           let firstArg = args.first {
            intervalExpr = firstArg.expression.trimmedDescription
        } else {
            throw MacroError.custom("@Throttle requires a milliseconds argument, e.g. @Throttle(1000)")
        }

        let lastExecDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)private var _\(raw: functionName)ThrottleLastExec: Date = Date(timeIntervalSince1970: 0)
        """

        let throttledFunc: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: functionName)Throttled() {
            let now = Date()
            let interval = TimeInterval(\(raw: intervalExpr)) / 1000.0
            
            if now.timeIntervalSince(_\(raw: functionName)ThrottleLastExec) >= interval {
                _\(raw: functionName)ThrottleLastExec = now
                Task { await \(raw: functionName)() }
            }
        }
        """

        return [lastExecDecl, throttledFunc]
    }
}
