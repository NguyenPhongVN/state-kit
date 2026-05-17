import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TaskAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
        
        let typealiasDecl: DeclSyntax = "typealias TaskSuccess = \(returnType)"
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
        let isThrowing = node.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "ThrowingTaskAtom"
        let taskProtocol = isThrowing ? "SKThrowingTaskAtom" : "SKTaskAtom"

        let taskAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): \(raw: taskProtocol) {}")
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [taskAtomExtension, hashableExtension]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "task" else {
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
