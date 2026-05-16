import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Debounce: Delays execution of a function until interval elapses with no new calls
/// Useful for search, auto-save, etc.
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
        let debounceMs = "300"  // Default, can be overridden via attribute

        let debouncedFunction: DeclSyntax = """
        @MainActor
        private var _\(raw: functionName)Task: Task<Void, Never>?

        public func \(raw: functionName)_debounced() {
            _\(raw: functionName)Task?.cancel()
            _\(raw: functionName)Task = Task {
                try? await Task.sleep(nanoseconds: UInt64(\(raw: debounceMs)) * 1_000_000)
                if !Task.isCancelled {
                    await \(raw: functionName)()
                }
            }
        }
        """

        return [debouncedFunction]
    }
}
