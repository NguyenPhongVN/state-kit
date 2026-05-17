import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @HookMemo: Generates a hook function from a struct with compute() method using useMemo
public struct HookMemoMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let hookName = "use" + className
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        // Find compute method and its return type
        var returnType = "Any"
        for member in structDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.name.text == "compute" {
                if let type = funcDecl.signature.returnClause?.type {
                    returnType = type.trimmedDescription
                }
            }
        }

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: hookName)() -> \(raw: returnType) {
            useMemo(updateStrategy: .once) {
                \(raw: className)().compute()
            }
        }
        """

        return [hookDecl]
    }
}
