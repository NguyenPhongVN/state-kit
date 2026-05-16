import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TaskAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
        let typealiasDecl: DeclSyntax = "typealias TaskSuccess = \(returnType)"

        return [typealiasDecl]
    }
}
