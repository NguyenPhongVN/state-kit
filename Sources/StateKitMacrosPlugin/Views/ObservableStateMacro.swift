import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @ObservableState: Integrates with Swift's Observation framework
/// Generates Observable conformance helpers and state tracking properties.
/// For classes, it automatically tracks property mutations.
public struct ObservableStateMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Support both struct and class
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            throw MacroError.custom("@ObservableState can only be applied to structs or classes")
        }

        var members: [DeclSyntax] = [
            "private let _observationRegistrar = ObservationRegistrar()"
        ]

        if declaration.is(StructDeclSyntax.self) {
            members.append(contentsOf: [
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
            ])
        }

        return members
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

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // For classes, we want to add @ObservationTracked to stored properties
        guard declaration.is(ClassDeclSyntax.self) else {
            return []
        }

        guard let varDecl = member.as(VariableDeclSyntax.self),
              !varDecl.modifiers.contains(where: { $0.name.text == "static" }),
              !varDecl.modifiers.contains(where: { $0.name.text == "private" }) else {
            return []
        }

        // Only track stored properties (no accessors)
        for binding in varDecl.bindings {
            if binding.accessorBlock != nil {
                return []
            }
        }

        // We use @ObservationTracked which is the standard way Observation works
        return [AttributeSyntax("@ObservationTracked")]
    }
}
