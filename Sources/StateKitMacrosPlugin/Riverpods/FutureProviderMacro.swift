import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FutureProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let funcName = funcDecl.name.text

        // Extract return type from async function
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        let providerDecl: DeclSyntax = """
        public let \(raw: funcName) = FutureProvider { _ in
            await \(raw: funcName)()
        }
        """

        return [providerDecl]
    }
}
