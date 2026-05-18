import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @StateAtom: Declares a read-write state atom backed by a default value.
///
/// Generates an `SKStateAtom` conformance extension with a `Value` typealias inferred
/// from the return type of `defaultValue(context:)`. Also synthesizes `Hashable`.
///
/// ## Generated Conformances
/// - `SKStateAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func defaultValue(context: SKAtomTransactionContext) -> T` where `T` is the atom's state type.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias.
/// - `@MainActor` is automatically added to `defaultValue(context:)` unless the struct or method already has it.
/// - Structs without explicit `@MainActor` get it added automatically for safe main-thread access.
public struct StateAtomMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the return type from defaultValue(context:) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "defaultValue")
        let typeName = returnType.trimmedDescription
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKStateAtom { typealias Value = T }
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKStateAtom {
            \(raw: accessPrefix)typealias Value = \(raw: typeName)
        }
        """)
        
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [stateAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to defaultValue(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the defaultValue(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "defaultValue" else {
            return []
        }

        // Skip if the struct already has @MainActor
        if AttributeHelper.hasAttribute("MainActor", on: declaration) {
            return []
        }

        // Add @MainActor if the method doesn't already have it
        if !AttributeHelper.hasAttribute("MainActor", on: funcDecl) {
            return [AttributeHelper.mainActorNewline]
        }

        return []
    }
}
