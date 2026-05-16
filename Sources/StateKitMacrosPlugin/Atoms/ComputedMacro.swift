import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Computed: Generates a derived atom from a struct with compute(context:) method
/// Creates: `typealias Computed = <ReturnType>`
public struct ComputedMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "compute")
        let typealiasDecl: DeclSyntax = "typealias Computed = \(returnType)"
        return [typealiasDecl]
    }
}
