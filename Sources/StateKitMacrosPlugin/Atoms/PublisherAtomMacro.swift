import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct PublisherAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "publisher")

        let publisherOutputTypeAlias: DeclSyntax = "typealias PublisherOutput = Never"
        let atomPublisherTypeAlias: DeclSyntax = "typealias AtomPublisher = \(returnType)"

        return [publisherOutputTypeAlias, atomPublisherTypeAlias]
    }
}
