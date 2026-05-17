import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ProviderFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Provider"
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        // Surgical parameter extraction
        var paramDecls: [String] = []
        var callArgs: [String] = []

        for param in funcDecl.signature.parameterClause.parameters {
            let typeStr = param.type.trimmedDescription
            let label = param.firstName.text
            let internalName = param.secondName?.text ?? label
            
            paramDecls.append("\(label): \(typeStr)")

            if label == "_" {
                callArgs.append(internalName)
            } else {
                callArgs.append("\(label): \(internalName)")
            }
        }

        let paramList = paramDecls.joined(separator: ", ")
        let argList = callArgs.joined(separator: ", ")

        let providerDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)let \(raw: providerName) = Provider.family { (\(raw: paramList)) -> \(raw: returnType.trimmedDescription) in
            \(raw: functionName)(\(raw: argList))
        }
        """

        return [providerDecl]
    }
}
