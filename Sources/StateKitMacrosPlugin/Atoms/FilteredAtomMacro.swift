import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FilteredAtom: Auto-generates filtered atom from predicate
/// Applies filtering to a source atom's list values
public struct FilteredAtomMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "predicate") != nil else {
            throw MacroError.custom("@FilteredAtom requires a 'predicate(_:) -> Bool' method")
        }

        let predicateFunc = try ReturnTypeExtractor.extract(from: declaration, methodName: "predicate")

        // For filtered atoms, Value is typically [Element] where Element is from source
        let typealiasDecl: DeclSyntax = "typealias Value = [T] where T: Equatable"
        return [typealiasDecl]
    }
}
