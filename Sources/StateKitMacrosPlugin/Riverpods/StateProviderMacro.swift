import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StateProviderMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        // Extract initial value from 'initial' property if it exists
        var initialValue = "initial"
        for member in structDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       pattern.identifier.text == "initial",
                       let initializer = binding.initializer?.value {
                        initialValue = initializer.trimmedDescription
                    }
                }
            }
        }

        let providerDecl: DeclSyntax = """
        @MainActor
        public static let provider = StateProvider { _ in
            \(raw: initialValue)
        }
        """

        return [providerDecl]
    }
}
