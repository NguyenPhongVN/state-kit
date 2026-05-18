import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @AtomFamily: Declares a parameterized state atom family.
///
/// Like @StateAtom but accepts parameters (stored as `let` properties on the struct)
/// to create a family of atom instances. Generates a `SKStateAtom` conformance with
/// `Value` typealias inferred from `defaultValue(context:)`.
/// Also synthesizes `Hashable` using the struct's stored properties.
///
/// ## Generated Conformances
/// - `SKStateAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - One or more `let` properties serving as family parameters (automatically included in `Hashable`).
/// - A method `func defaultValue(context: SKAtomTransactionContext) -> T` returning the atom's value.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias.
/// - `@MainActor` is automatically added to `defaultValue(context:)` unless the struct or method already has it.
public struct AtomFamilyMacro: ExtensionMacro, MemberAttributeMacro {
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

        // Generate: extension UserAtom: SKStateAtom { typealias Value = T }
        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKStateAtom {
            \(raw: accessPrefix)typealias Value = \(raw: typeName)
        }
        """)
        
        // Generate: extension UserAtom: Hashable {}
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
