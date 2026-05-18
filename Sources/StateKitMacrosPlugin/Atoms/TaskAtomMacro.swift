import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @TaskAtom / @ThrowingTaskAtom: Declares an async task atom for one-shot async work.
///
/// Generates a `SKTaskAtom` (or `SKThrowingTaskAtom`) conformance extension with a
/// `TaskSuccess` typealias inferred from the return type of `task(context:)`.
/// Also synthesizes `Hashable`.
///
/// The macro auto-detects `@ThrowingTaskAtom` vs `@TaskAtom` from the attribute name
/// to select the correct protocol conformance.
///
/// ## Generated Conformances
/// - `SKTaskAtom` (for `@TaskAtom`) or `SKThrowingTaskAtom` (for `@ThrowingTaskAtom`) with `TaskSuccess` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - A method `func task(context: SKAtomTransactionContext) async -> T` (or `async throws -> T` for ThrowingTaskAtom).
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias.
/// - `@MainActor` is automatically added to `task(context:)` unless the struct or method already has it.
public struct TaskAtomMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the return type from task(context:) to determine TaskSuccess
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "task")
        let typeName = returnType.trimmedDescription
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Detect whether @TaskAtom or @ThrowingTaskAtom was used
        let isThrowing = node.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "ThrowingTaskAtom"
        let taskProtocol = isThrowing ? "SKThrowingTaskAtom" : "SKTaskAtom"

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension MyAtom: SKTaskAtom { typealias TaskSuccess = T }
        let taskAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): \(raw: taskProtocol) {
            \(raw: accessPrefix)typealias TaskSuccess = \(raw: typeName)
        }
        """)
        
        // Generate: extension MyAtom: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [taskAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to task(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the task(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "task" else {
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
