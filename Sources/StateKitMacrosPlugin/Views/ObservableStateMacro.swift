import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @ObservableState: Integrates with Swift's Observation framework
/// Generates Observable conformance helpers and state tracking properties
public struct ObservableStateMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Support both struct and class
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            throw MacroError.custom("@ObservableState can only be applied to structs or classes")
        }

        return [
            "private let _observationRegistrar = ObservationRegistrar()",
            """
            nonisolated public func withObserver<V>(_ body: () -> V) -> V {
                _observe { body() }
            }
            """,
            """
            nonisolated private func _observe<V>(_ body: () -> V) -> V {
                _observationRegistrar.withMutation(of: self, keyPath: \\.self) { body() }
            }
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let observableExtension: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Observable {}")
        return [observableExtension]
    }
}
