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
        var debounceMs = "300"
        
        if let attribute = node.as(AttributeSyntax.self),
           let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
           let msArg = arguments.first(where: { $0.label?.text == "milliseconds" }) {
            debounceMs = msArg.expression.description
        }

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
