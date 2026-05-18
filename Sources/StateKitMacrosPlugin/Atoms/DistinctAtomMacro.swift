import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @DistinctAtom: Wraps a source atom and only emits distinct/unique values.
///
/// Generates a `SKValueAtom` conformance with `Value` typealias inferred from
/// `source(context:)`. Also synthesizes `value(context:)` that delegates to
/// `source(context:)`, and adds `Hashable`.
/// The runtime filters out consecutive duplicate values automatically.
///
/// ## Generated Members
/// - `func value(context:) -> Value` — delegates to `source(context:)`
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func source(context: SKAtomTransactionContext) -> T` providing the source value.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias and method.
/// - `@MainActor` is automatically added to `source(context:)` unless the struct or method already has it.
public struct DistinctAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // MemberMacro: generates value(context:) that delegates to source(context:)
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Propagate the struct's access level to the generated method
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: func value(context:) -> Value { source(context: context) }
        let valueMethod: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func value(context: SKAtomTransactionContext) -> Value {
            source(context: context)
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
        // Extract the return type from source(context:) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "source")
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

    // MemberAttributeMacro: adds @MainActor to source(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the source(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "source" else {
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
