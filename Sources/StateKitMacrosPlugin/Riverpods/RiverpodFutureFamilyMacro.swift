import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodFutureFamily: Generates a FutureProvider family
/// Parameterized one-shot async provider
public struct RiverpodFutureFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.custom("@RiverpodFutureFamily function must have explicit return type")
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Family"

        let futureProvider: DeclSyntax = """
        public let \(raw: providerName) = FutureProvider.family(\(raw: functionName))
        """

        return [futureProvider]
    }
}
