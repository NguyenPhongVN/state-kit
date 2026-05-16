import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct NotifierProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return []
        }

        let className = classDecl.name.text

        // Find the generic state type from Notifier<State>
        // This is a bit simplified, ideally we'd walk the inheritance clause more robustly
        guard let inheritance = classDecl.inheritanceClause?.inheritedTypes.first,
              let typeName = inheritance.type.as(IdentifierTypeSyntax.self),
              typeName.name.text == "Notifier",
              let genericArgs = typeName.genericArgumentClause?.arguments,
              genericArgs.first != nil else {
            return []
        }

        let modifiers = classDecl.modifiers.description.trimmingCharacters(in: .whitespaces)
        let accessLevel = modifiers.isEmpty ? "" : modifiers + " "
        let providerName = className.prefix(1).lowercased() + className.dropFirst() + "Provider"

        return [
            "\(raw: accessLevel)let \(raw: providerName) = NotifierProvider { \(raw: className)() }"
        ]
    }
}
