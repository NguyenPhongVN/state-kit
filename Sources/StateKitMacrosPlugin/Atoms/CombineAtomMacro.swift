import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @CombineAtom: Combines multiple atoms into a single tuple value
/// Watches multiple atoms and emits combined result
public struct CombineAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "combine")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        return [typealiasDecl]
    }
}
