import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @AsyncTaskFamily: Declares a parameterized async task atom family.
///
/// Like @TaskAtom but accepts parameters (stored as `let` properties) to create
/// a family of async task atom instances. Generates a `SKTaskAtom` conformance with
/// `TaskSuccess` typealias inferred from `task(context:)`.
/// Also synthesizes `Hashable` using the struct's stored properties.
///
/// ## Generated Conformances
/// - `SKTaskAtom` with `TaskSuccess` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - One or more `let` properties serving as family parameters.
/// - A method `func task(context: SKAtomTransactionContext) async -> T` returning the task result type.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias.
/// - `@MainActor` is automatically added to `task(context:)` unless the struct or method already has it.
public struct AsyncTaskFamilyMacro: ExtensionMacro, MemberAttributeMacro {
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

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension UserTask: SKTaskAtom { typealias TaskSuccess = T }
        let taskAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKTaskAtom {
            \(raw: accessPrefix)typealias TaskSuccess = \(raw: typeName)
        }
        """)
        
        // Generate: extension UserTask: Hashable {}
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
