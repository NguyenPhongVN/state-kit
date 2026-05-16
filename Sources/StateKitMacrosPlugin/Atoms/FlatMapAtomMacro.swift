import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FlatMapAtom: Flattens nested async values
/// Maps and flattens async chains for cleaner composition
public struct FlatMapAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "flatMap")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        return [typealiasDecl]
    }
}
