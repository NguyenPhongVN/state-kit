import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookCallbackMacro: PeerMacro {
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

        // Find call or handle method
        var methodName = "call"
        var paramList = ""
        var argList = ""

        if let fn = PropertyExtractor.function(in: structDecl, named: "handle") {
            methodName = "handle"
            let params = fn.signature.parameterClause.parameters.map { $0.description.trimmingCharacters(in: .whitespaces) }
            paramList = params.joined(separator: ", ")
            argList = fn.signature.parameterClause.parameters.map { $0.firstName.text }.joined(separator: ", ")
        } else if let fn = PropertyExtractor.function(in: structDecl, named: "call") {
            methodName = "call"
            let params = fn.signature.parameterClause.parameters.map { $0.description.trimmingCharacters(in: .whitespaces) }
            paramList = params.joined(separator: ", ")
            argList = fn.signature.parameterClause.parameters.map { $0.firstName.text }.joined(separator: ", ")
        }

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: hookName)() -> (\(raw: paramList)) -> Void {
            useCallback(updateStrategy: .once) { (\(raw: paramList)) in
                \(raw: className)().\(raw: methodName)(\(raw: argList))
            }
        }
        """

        return [hookDecl]
    }
}
