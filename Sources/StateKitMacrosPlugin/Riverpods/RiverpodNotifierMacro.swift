import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RiverpodNotifierMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration as? ClassDeclSyntax else {
            throw MacroError.onlyApplicableToClasses
        }

        let className = classDecl.name.text
        let providerName = lowercaseFirstChar(className) + "Provider"

        // Detect base class: Notifier or AsyncNotifier
        let baseClass: String
        if hasBaseClass(classDecl, named: "AsyncNotifier") {
            baseClass = "AsyncNotifierProvider"
        } else if hasBaseClass(classDecl, named: "Notifier") {
            baseClass = "NotifierProvider"
        } else {
            throw MacroError.missingBaseClass
        }

        let providerDecl: DeclSyntax = "public let \(raw: providerName) = \(raw: baseClass) { \(raw: className)() }"

        return [providerDecl]
    }

    private static func hasBaseClass(_ classDecl: ClassDeclSyntax, named: String) -> Bool {
        guard let inheritanceClause = classDecl.inheritanceClause else { return false }

        for inherited in inheritanceClause.inheritedTypes {
            if let identifierType = inherited.type.as(IdentifierTypeSyntax.self),
               identifierType.name.text == named {
                return true
            }
            if inherited.type.description.contains("\(named)<") {
                return true
            }
        }
        return false
    }

    private static func lowercaseFirstChar(_ str: String) -> String {
        guard !str.isEmpty else { return str }
        return String(str.first!).lowercased() + String(str.dropFirst())
    }
}
