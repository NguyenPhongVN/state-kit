import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FlatMapAtom: Flattens a nested async/atom chain into a single value.
///
/// Generates a `SKValueAtom` conformance with `Value` typealias inferred from
/// `flatMap(context:)`. Also synthesizes `value(context:)` that delegates to
/// `flatMap(context:)`, and adds `Hashable`.
/// Use this to compose atoms where one atom depends on another's async result.
///
/// ## Generated Members
/// - `func value(context:) -> Value` — delegates to `flatMap(context:)`
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func flatMap(context: SKAtomTransactionContext) -> T` performing the flat-map logic.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias and method.
/// - `@MainActor` is automatically added to `flatMap(context:)` unless the struct or method already has it.
public struct FlatMapAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // MemberMacro: generates value(context:) that delegates to flatMap(context:)
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Propagate the struct's access level to the generated method
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: func value(context:) -> Value { flatMap(context: context) }
        let valueMethod: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func value(context: SKAtomTransactionContext) -> Value {
            flatMap(context: context)
        }
        """

        return [valueMethod]
    }

    // ExtensionMacro: adds SKValueAtom conformance with Value typealias
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the return type from flatMap(context:) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "flatMap")
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKValueAtom { typealias Value = T }
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKValueAtom {
            \(raw: accessPrefix)typealias Value = \(raw: returnType.trimmedDescription)
        }
        """)
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to flatMap(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the flatMap(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "flatMap" else {
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
