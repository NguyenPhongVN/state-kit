import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RiverpodStreamFamilyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        let familyName = functionName + "Family"
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        // Extract ID parameter type (assume first non-ref parameter)
        var argType = "String"
        var argName = "id"
        for param in funcDecl.signature.parameterClause.parameters {
            let typeStr = param.type.trimmedDescription
            if typeStr != "ProviderRef" {
                argType = typeStr
                argName = param.firstName.text
                break
            }
        }

        let familyDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)let \(raw: familyName) = StreamProvider.family { (ref: ProviderRef, arg: \(raw: argType)) in
            \(raw: functionName)(\(raw: argName): arg)
        }
        """

        return [familyDecl]
    }
}
