import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RiverpodNotifierMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }

        let className = classDecl.name.text

        let baseClass: String
        if hasBaseClass(classDecl, named: "AsyncNotifier") {
            baseClass = "AsyncNotifierProvider"
        } else if hasBaseClass(classDecl, named: "Notifier") {
            baseClass = "NotifierProvider"
        } else {
            throw MacroError.missingBaseClass
        }

        let providerDecl: DeclSyntax = """
        @MainActor
        public static let provider = \(raw: baseClass) { \(raw: className)() }
        """

        return [providerDecl]
    }

    private static func hasBaseClass(_ classDecl: ClassDeclSyntax, named: String) -> Bool {
        guard let inheritance = classDecl.inheritanceClause else { return false }
        for type in inheritance.inheritedTypes {
            if let ident = type.type.as(IdentifierTypeSyntax.self),
               ident.name.text == named {
                return true
            }
        }
        return false
    }
}
