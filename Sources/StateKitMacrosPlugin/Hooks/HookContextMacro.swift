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

        let structName = structDecl.name.text
        let contextVarName = lowercaseFirstChar(structName) + "HookContext"
        let hookName = "use" + structName + "Context"

        let contextVar: DeclSyntax = """
        public let \(raw: contextVarName) = HookContext<\(raw: structName)>(\(raw: structName)())
        """

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)() -> \(raw: structName) {
            useContext(\(raw: contextVarName))
        }
        """

        return [contextVar, hookFunction]
    }

    private static func lowercaseFirstChar(_ str: String) -> String {
        guard !str.isEmpty else { return str }
        return String(str.first!).lowercased() + String(str.dropFirst())
    }
}
