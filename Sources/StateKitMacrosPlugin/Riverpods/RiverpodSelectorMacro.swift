import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RiverpodSelectorMacro: PeerMacro {
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

        let providerDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)let \(raw: providerName) = Provider(\(raw: functionName))
        """

        return [providerDecl]
    }
}
