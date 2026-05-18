import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @MappedAtom: Transforms a source value using a mapping function.
///
/// Generates a `SKValueAtom` conformance with `Value` typealias inferred from
/// `transform(...)`. Also synthesizes `value(context:)` that chains
/// `transform(source(context: context))`, and adds `Hashable`.
///
/// ## Generated Members
/// - `func value(context:) -> Value` — returns `transform(source(context: context))`
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func source(context: SKAtomTransactionContext) -> T` providing the source value.
/// - A method `func transform(_ input: T) -> U` mapping the source to the target type.
///
/// ## Behavior
/// - Access level propagates from the struct to both the generated typealias and method.
/// - `@MainActor` is automatically added to both `source(context:)` and `transform(_:)` unless already present.
public struct MappedAtomMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // MemberMacro: generates value(context:) = transform(source(context:))
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Propagate the struct's access level to the generated method
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: func value(context:) -> Value { transform(source(context: context)) }
        let valueMethod: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func value(context: SKAtomTransactionContext) -> Value {
            transform(source(context: context))
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
        // Extract the return type from transform(...) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "transform")
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKValueAtom { typealias Value = U }
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKValueAtom {
            \(raw: accessPrefix)typealias Value = \(raw: returnType.trimmedDescription)
        }
        """)
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to source(context:) and transform(_:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to source(context:) or transform(_:) methods
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              ["source", "transform"].contains(funcDecl.name.text) else {
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
