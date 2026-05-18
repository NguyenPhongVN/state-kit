import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodNotifier: Declares a notifier provider from a class extending `Notifier` or `AsyncNotifier`.
///
/// Attached to a class that inherits from `Notifier<T>` or `AsyncNotifier<T>`. Generates a
/// peer `let` initialized with the corresponding `NotifierProvider` or `AsyncNotifierProvider`.
///
/// ## Generated Members
/// - `let <ClassName>Provider = NotifierProvider { <ClassName>() }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The class must inherit from `Notifier<T>` or `AsyncNotifier<T>`.
///
/// ## Behavior
/// - Access level propagates from the class to the generated constant (via `AttributeHelper.accessLevel(from:)`).
/// - `@MainActor` is automatically added unless the class already has it.
/// - If the class is nested inside another type, the generated constant is marked `static`.
public struct RiverpodNotifierMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only apply to classes
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }

        let className = classDecl.name.text
        let providerName = className + "Provider"

        // Select the correct base provider class based on inheritance
        let baseClass: String
        if hasBaseClass(classDecl, named: "AsyncNotifier") {
            baseClass = "AsyncNotifierProvider"
        } else if hasBaseClass(classDecl, named: "Notifier") {
            baseClass = "NotifierProvider"
        } else {
            throw MacroError.missingBaseClass
        }

        // Propagate access level from the class to the generated constant
        let accessPrefix = AttributeHelper.accessLevel(from: classDecl)

        // Determine if the generated constant needs `static` (nested types do)
        let isNested = context.lexicalContext.count > 0
        let staticKeyword = isNested ? "static " : ""

        // Only add @MainActor prefix if the class itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: classDecl) ? "" : "@MainActor\n"

        // Generate: [@MainActor] [access] [static] let <name>Provider = <baseClass> { ... }
        let providerDecl: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = \(raw: baseClass) { \(raw: className)() }
        """

        return [providerDecl]
    }

    // Check whether the class inherits from a given base class name
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
