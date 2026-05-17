import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StateViewMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.onlyApplicableToStructs
        }

        // Check that stateBody exists
        guard hasProperty(in: declaration, named: "stateBody") else {
            throw MacroError.methodNotFound("stateBody")
        }

        // Check that body doesn't already exist
        if hasProperty(in: declaration, named: "body") {
            return []
        }

        // Generate: var body: some View { StateScope { stateBody } }
        let bodyDecl: DeclSyntax = """
        var body: some View {
            StateScope { stateBody }
        }
        """

        return [bodyDecl]
    }

    private static func hasProperty(in decl: DeclGroupSyntax, named: String) -> Bool {
        for member in decl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                       name == named {
                        return true
                    }
                }
            }
        }
        return false
    }
}
