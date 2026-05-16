import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Throttle: Limits function execution frequency to once per interval
/// Useful for scroll events, resize, etc.
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
        let throttleMs = "100"  // Default, can be overridden via attribute

        let throttledFunction: DeclSyntax = """
        @MainActor
        private var _\(raw: functionName)LastExecution: Date = Date(timeIntervalSince1970: 0)

        public func \(raw: functionName)_throttled() {
            let now = Date()
            let interval = TimeInterval(\(raw: throttleMs)) / 1000.0

            if now.timeIntervalSince(_\(raw: functionName)LastExecution) >= interval {
                _\(raw: functionName)LastExecution = now
                Task { await \(raw: functionName)() }
            }
        }
        """

        return [throttledFunction]
    }
}
