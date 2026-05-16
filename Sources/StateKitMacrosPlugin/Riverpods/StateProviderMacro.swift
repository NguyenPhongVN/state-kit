import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StateProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        guard let initialProp = properties.first(where: { $0.name == "initial" }) else {
            throw MacroError.methodNotFound("struct must have 'initial' property")
        }

        let structName = structDecl.name.text
        let providerName = lowercaseFirstChar(structName) + "Provider"

        let providerDecl: DeclSyntax = """
        public let \(raw: providerName) = StateProvider { _ in \(raw: initialProp.defaultValue ?? initialProp.typeName)() }
        """

        return [providerDecl]
    }

    private static func lowercaseFirstChar(_ str: String) -> String {
        guard !str.isEmpty else { return str }
        return String(str.first!).lowercased() + String(str.dropFirst())
    }
}
