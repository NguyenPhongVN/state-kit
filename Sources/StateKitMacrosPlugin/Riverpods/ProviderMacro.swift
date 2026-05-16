import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let funcName = funcDecl.name.text
        guard !funcName.isEmpty else {
            throw MacroError.invalidHookName(funcName)
        }

        // Extract return type
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        // Find parameters (expect 'ref: ProviderRef')
        var params: [String] = []
        for param in funcDecl.signature.parameterClause.parameters {
            params.append(param.description.trimmingCharacters(in: .whitespaces))
        }

        let paramList = params.isEmpty ? "ref" : params.joined(separator: ", ")

        let providerDecl: DeclSyntax = """
        public let \(raw: funcName) = Provider { (\(raw: paramList)) -> \(returnType) in
            await \(raw: funcName)(\(raw: paramList))
        }
        """

        return [providerDecl]
    }
}
