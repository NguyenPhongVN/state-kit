import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StreamProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let funcName = funcDecl.name.text

        // Extract return type (should be AnyPublisher or similar)
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        let providerDecl: DeclSyntax = """
        public let \(raw: funcName) = StreamProvider { _ in
            \(raw: funcName)()
        }
        """

        return [providerDecl]
    }
}
