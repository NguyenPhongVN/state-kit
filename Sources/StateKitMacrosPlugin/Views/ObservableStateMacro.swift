import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @ObservableState: Integrates with Swift's Observation framework
/// Generates Observable conformance helpers and state tracking properties
public struct ObservableStateMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: DeclGroupSyntax,
        conformingTo protocols: [IdentifierTypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)

        if properties.isEmpty {
            throw MacroError.custom("@ObservableState requires at least one stored property")
        }

        var members: [DeclSyntax] = []

        let obsRegistrationCode: DeclSyntax = """
        nonisolated(unsafe) private let _observationRegistrar = ObservationRegistrar<Self>()
        """
        members.append(obsRegistrationCode)

        let withObserverCode: DeclSyntax = """
        nonisolated public func withObserver<V>(_ body: () -> V) -> V {
            _observe { body() }
        }
        """
        members.append(withObserverCode)

        let observeCode: DeclSyntax = """
        nonisolated private func _observe<V>(_ body: () -> V) -> V {
            _observationRegistrar.withMutation(of: self) { body() }
        }
        """
        members.append(observeCode)

        return members
    }
}
