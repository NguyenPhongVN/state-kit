import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Adds typealias Value inferred from defaultValue(context:) return type
/// and provides SKStateAtom and Hashable conformances.
/// Also ensures defaultValue(context:) is @MainActor isolated.
public struct StateAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")

        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        let sharedDecl: DeclSyntax = "@MainActor public static let shared = \(raw: structDecl.name.text)()"

        return [typealiasDecl, sharedDecl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): SKStateAtom {}")
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [stateAtomExtension, hashableExtension]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "defaultValue" else {
            return []
        }

        if !funcDecl.attributes.contains(where: { attr in
            attr.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "MainActor"
        }) {
            return [AttributeSyntax("@MainActor\n")]
        }

        return []
    }
}
