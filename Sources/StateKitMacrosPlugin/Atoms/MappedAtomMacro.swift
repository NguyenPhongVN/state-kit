import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @MappedAtom: Auto-generates mapped atom from transform function
/// Transforms values from a source atom
public struct MappedAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
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
        let valueMethod: DeclSyntax = """
        @MainActor
        func value(context: SKAtomTransactionContext) -> Value {
            // Placeholder implementation
            fatalError("value(context:) must be implemented by user")
        }
        """

        return [typealiasDecl, valueMethod]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): SKValueAtom {}")
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "transform" else {
            return []
        }

        if !funcDecl.attributes.contains(where: { attr in
            attr.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "MainActor"
        }) {
            return ["@MainActor "]
        }

        return []
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }
        let className = structDecl.name.text
        let atomName = className.prefix(1).lowercased() + className.dropFirst()
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        return ["@MainActor \(raw: staticKeyword)let \(raw: atomName) = \(raw: className)()"]
    }
}
