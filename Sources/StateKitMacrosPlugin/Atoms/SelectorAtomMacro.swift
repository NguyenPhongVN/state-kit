import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @SelectorAtom: Generates derived state from select(context:) method
/// More semantic than @ValueAtom for explicitly selected/filtered values
public struct SelectorAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "select")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        return [typealiasDecl]
    }
}
