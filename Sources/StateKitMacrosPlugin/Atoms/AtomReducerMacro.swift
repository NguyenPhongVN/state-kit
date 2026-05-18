import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @AtomReducer: Declares a state atom managed by a unidirectional reducer.
///
/// Implements the Elm/Redux pattern: state is mutated through actions dispatched
/// to a `reduce(_:action:)` method rather than through direct mutation.
/// Generates a `SKStateAtom` conformance and a `defaultValue(context:)` method
/// that creates the initial state via `Value()`.
///
/// ## Generated Members
/// - `func defaultValue(context:) -> Value` — returns `Value()` (requires `State` to provide `init()`)
///
/// ## Generated Conformances
/// - `SKStateAtom` with `Value` typealias (bound to the struct's `State` typealias)
/// - `Hashable`
///
/// ## User Requirements
/// - A `typealias State = T` declaring the state type (must provide `init()`).
/// - A `typealias Action = A` declaring the action type.
/// - A method `func reduce(_ state: inout State, action: Action)` implementing the reducer logic.
///
/// ## Behavior
/// - Access level propagates from the struct to both the generated method and typealias.
/// - `@MainActor` is added to `defaultValue(context:)` unless the struct already has it.
public struct AtomReducerMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let _ = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor\n"

        let atomStruct: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)func defaultValue(context: SKAtomTransactionContext) -> Value {
            Value()
        }
        """

        return [atomStruct]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        var stateType: String = "Any"
        for member in declaration.memberBlock.members {
            if let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self),
               typealiasDecl.name.text == "State" {
                stateType = typealiasDecl.initializer.value.trimmedDescription
            }
        }

        let accessPrefix = AttributeHelper.accessLevel(from: declaration)
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: declaration) ? "" : "@MainActor "

        let stateAtomExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("""
        \(raw: mainActorAttr)extension \(type.trimmed): SKStateAtom {
            \(raw: accessPrefix)typealias Value = \(raw: stateType)
        }
        """)
        let hashableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")

        return [stateAtomExtension, hashableExtension]
    }
}
