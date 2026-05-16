import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodStreamFamily: Generates a StreamProvider family
/// Parameterized continuous stream provider
public struct RiverpodStreamFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.custom("@RiverpodStreamFamily function must have explicit return type")
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Family"

        let streamProvider: DeclSyntax = """
        public final \(raw: providerName) = StreamProvider.family(\(raw: functionName))
        """

        return [streamProvider]
    }
}
