import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Computed: Declares a derived atom whose value is computed on demand.
///
/// Generates a `SKValueAtom` conformance with `Value` typealias inferred from
/// `compute(context:)`. Also synthesizes `value(context:)` that delegates to
/// `compute(context:)`, and adds `Hashable`.
///
/// ## Generated Members
/// - `func value(context:) -> Value` — delegates to `compute(context:)`
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func compute(context: SKAtomTransactionContext) -> T` performing the computation.
///
/// ## Behavior
/// - Access level propagates from the struct to both the generated typealias and method.
/// - `@MainActor` is automatically added to `compute(context:)` unless the struct or method already has it.
public struct ComputedMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // MemberMacro: generates value(context:) that delegates to compute(context:)
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Ensure this macro is only applied to structs
        guard let _ = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        // Propagate the struct's access level to the generated method
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: func value(context:) -> Value { compute(context: context) }
        let valueMethod: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func value(context: SKAtomTransactionContext) -> Value {
            compute(context: context)
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
        // Extract the return type from compute(context:) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "compute")
        let typeName = returnType.trimmedDescription
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKValueAtom { typealias Value = T }
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKValueAtom {
            \(raw: accessPrefix)typealias Value = \(raw: typeName)
        }
        """)
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to compute(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the compute(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "compute" else {
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
