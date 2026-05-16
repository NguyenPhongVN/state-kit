import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodAsync: Generates a simple async Provider
/// Cleaner syntax for one-shot async operations
public struct RiverpodAsyncMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.custom("@RiverpodAsync function must have explicit return type")
        }

        guard let body = funcDecl.body else {
            throw MacroError.custom("@RiverpodAsync function must have implementation")
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Provider"

        let asyncProvider: DeclSyntax = """
        public let \(raw: providerName) = FutureProvider { ref in
            try await \(raw: functionName)()
        }
        """

        return [asyncProvider]
    }
}
