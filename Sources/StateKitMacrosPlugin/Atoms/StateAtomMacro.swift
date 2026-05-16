import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Adds typealias Value inferred from defaultValue(context:) return type
public struct StateAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        return [typealiasDecl]
    }
}
