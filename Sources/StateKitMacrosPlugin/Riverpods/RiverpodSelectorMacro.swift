import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodSelector: Generates a selector provider from a function
/// that derives value from other providers
public struct RiverpodSelectorMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.custom("@RiverpodSelector function must have explicit return type")
        }

        guard let body = funcDecl.body else {
            throw MacroError.custom("@RiverpodSelector function must have implementation")
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Provider"

        let selectorProvider: DeclSyntax = """
        public let \(raw: providerName) = Provider(\(raw: functionName))
        """

        return [selectorProvider]
    }
}
