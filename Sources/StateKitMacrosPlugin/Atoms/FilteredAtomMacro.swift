import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FilteredAtom: Auto-generates filtered atom from predicate
/// Applies filtering to a source atom's list values
public struct FilteredAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        guard PropertyExtractor.function(in: structDecl, named: "predicate") != nil else {
            throw MacroError.custom("@FilteredAtom requires a 'predicate(_:) -> Bool' method")
        }

        // For filtered atoms, Value is typically [Any] unless specific inference is added
        let typealiasDecl: DeclSyntax = "typealias Value = [Any]"
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
              funcDecl.name.text == "predicate" else {
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
