import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @SelectorFamily: Declares a parameterized derived-value atom family.
///
/// Like @ValueAtom but accepts parameters (stored as `let` properties) to create
/// a family of derived atom instances. Generates a `SKValueAtom` conformance with
/// `Value` typealias inferred from `value(context:)`.
/// Also synthesizes `Hashable` using the struct's stored properties.
///
/// ## Generated Conformances
/// - `SKValueAtom` with `Value` typealias
/// - `Hashable`
///
/// ## User Requirements
/// - One or more `let` properties serving as family parameters.
/// - A method `func value(context: SKAtomTransactionContext) -> T` returning the derived value.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated typealias.
/// - `@MainActor` is automatically added to `value(context:)` unless the struct or method already has it.
public struct SelectorFamilyMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the return type from value(context:) to determine Value
        let returnType = try ReturnTypeExtractor.extract(from: declaration, methodName: "value")
        let typeName = returnType.trimmedDescription
        // Propagate the struct's access level to the generated typealias
        let accessPrefix = AttributeHelper.accessLevel(from: declaration)

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        // Generate: extension UserSelector: SKValueAtom { typealias Value = T }
        let valueAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKValueAtom {
            \(raw: accessPrefix)typealias Value = \(raw: typeName)
        }
        """)
        
        // Generate: extension UserSelector: Hashable {}
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [valueAtomExtension, hashableExtension]
    }

    // MemberAttributeMacro: adds @MainActor to value(context:) if needed
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to the value(context:) method
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              funcDecl.name.text == "value" else {
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
