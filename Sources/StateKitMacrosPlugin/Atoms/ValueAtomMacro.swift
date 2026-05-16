import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ValueAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"

        return [typealiasDecl]
    }
}
