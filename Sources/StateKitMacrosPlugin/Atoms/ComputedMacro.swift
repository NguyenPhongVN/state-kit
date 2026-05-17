import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Computed: Generates a derived atom from a struct with compute(context:) method
/// Creates: `typealias Value = <ReturnType>`
public struct ComputedMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "compute")
        
        let typealiasDecl: DeclSyntax = "typealias Value = \(returnType)"
        let valueMethod: DeclSyntax = """
        @MainActor
        func value(context: SKAtomTransactionContext) -> Value {
            compute(context: context)
        }
        """
        let sharedDecl: DeclSyntax = "@MainActor public static let shared = \(raw: structDecl.name.text)()"

        return [typealiasDecl, valueMethod, sharedDecl]
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
              funcDecl.name.text == "compute" else {
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
