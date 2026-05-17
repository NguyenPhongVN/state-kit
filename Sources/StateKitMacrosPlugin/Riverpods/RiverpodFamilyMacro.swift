import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RiverpodFamilyMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }

        let className = classDecl.name.text

        // Find the build method and its parameters
        var argType = "String"
        for member in classDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.name.text == "build" {
                if let firstParam = funcDecl.signature.parameterClause.parameters.first {
                    argType = firstParam.type.trimmedDescription
                }
            }
        }

        let familyDecl: DeclSyntax = """
        @MainActor
        public static let family = NotifierProvider.family { (arg: \(raw: argType)) in
            \(raw: className)()
        }
        """

        return [familyDecl]
    }
}
