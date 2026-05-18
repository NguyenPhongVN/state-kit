import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FilteredAtom: Filters elements from a source array using a predicate.
///
/// Generates a `SKValueAtom` conformance with `Value` typealias inferred from
/// `source(context:)` (expected to return `[Element]`). Also synthesizes
/// `value(context:)` that filters the source array using the `predicate` function,
/// and adds `Hashable`.
///
/// ## Generated Members
/// - `func value(context:) -> Value` — returns `source(context: context).filter(predicate)`
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func source(context: SKAtomTransactionContext) -> [Element]` providing the source array.
/// - A method `func predicate(_ element: Element) -> Bool` filtering array elements.
///
/// ## Behavior
/// - Access level propagates from the struct to both the generated typealias and method.
/// - `@MainActor` is automatically added to both `source(context:)` and `predicate(_:)` unless already present.
public struct FilteredAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // MemberMacro: generates value(context:) = source().filter(predicate)
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Propagate the struct's access level to the generated method
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: func value(context:) -> Value { source(context: context).filter(predicate) }
        let valueMethod: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func value(context: SKAtomTransactionContext) -> Value {
            source(context: context).filter(predicate)
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

        // Generate: extension MyAtom: SKValueAtom { typealias Value = [Element] }
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKValueAtom {
            \(raw: accessPrefix)typealias Value = \(raw: returnType.trimmedDescription)
        }
        """)
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to source(context:) and predicate(_:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to source(context:) or predicate(_:) methods
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              ["source", "predicate"].contains(funcDecl.name.text) else {
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
