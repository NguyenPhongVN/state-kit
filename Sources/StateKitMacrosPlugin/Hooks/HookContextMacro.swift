import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookContextMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let lowerCaseClassName = className.prefix(1).lowercased() + className.dropFirst()
        let hookName = "use" + className
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        let contextInstanceDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)let \(raw: lowerCaseClassName)HookContext = StateKit.HookContext<\(raw: className)>(\(raw: className)())
        """

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: hookName)() -> \(raw: className) {
            useContext(\(raw: lowerCaseClassName)HookContext)
        }
        """

        return [contextInstanceDecl, hookDecl]
    }
}
