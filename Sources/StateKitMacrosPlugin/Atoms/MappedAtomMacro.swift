import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @MappedAtom: Auto-generates mapped atom from transform function
/// Transforms values from a source atom
public struct MappedAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "transform") != nil else {
            throw MacroError.custom("@MappedAtom requires a 'transform(_:)' method")
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "transform")
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        return [typealiasDecl]
    }
}
