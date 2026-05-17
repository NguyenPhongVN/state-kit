import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookReducerMacro: PeerMacro {
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

        // Extract State and Action typealiases (Trimming trivia to avoid comment leakage)
        var stateType: String = "Any"
        var actionType: String = "Any"

        for member in structDecl.memberBlock.members {
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self) {
                if typealiasDecl.name.text == "State" {
                    stateType = typealiasDecl.initializer.value.trimmedDescription
                } else if typealiasDecl.name.text == "Action" {
                    actionType = typealiasDecl.initializer.value.trimmedDescription
                }
            }
        }

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: hookName)(initial: \(raw: stateType) = \(raw: stateType)()) -> (\(raw: stateType), (\(raw: actionType)) -> Void) {
            let reducer = \(raw: className)()
            return useReducer(initial) { state, action in
                reducer.reduce(&state, action: action)
            }
        }
        """

        return [hookDecl]
    }
}
