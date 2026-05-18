import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodFamily: Declares a family of notifier providers keyed by the `build()` parameter.
///
/// Attached to a class extending `Notifier<T>` with a `build(_:)` method that takes a key
/// parameter. Generates a peer `let` initialized with `NotifierProvider.family { ... }`.
///
/// ## Generated Members
/// - `let <ClassName>Family = NotifierProvider.family { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The class must inherit from `Notifier<T>`.
/// - The class must have a `build` method whose first parameter is the family key.
///
/// ## Behavior
/// - Access level propagates from the class to the generated constant (via `AttributeHelper.accessLevel(from:)`).
/// - `@MainActor` is automatically added unless the class already has it.
/// - If the class is nested inside another type, the generated constant is marked `static`.
/// - The key type is inferred from the first parameter of the `build` method (defaults to `String`).
public struct RiverpodFamilyMacro: PeerMacro {
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
        let familyName = className + "Family"

        // Propagate access level from the class to the generated constant
        let accessPrefix = AttributeHelper.accessLevel(from: classDecl)

        // Determine if the generated constant needs `static` (nested types do)
        let isNested = context.lexicalContext.count > 0
        let staticKeyword = isNested ? "static " : ""

        // Only add @MainActor prefix if the class itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: classDecl) ? "" : "@MainActor\n"

        // Extract the key type from the build method's first parameter
        var argType = "String"
        for member in classDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.name.text == "build" {
                if let firstParam = funcDecl.signature.parameterClause.parameters.first {
                    argType = firstParam.type.trimmedDescription
                }
            }
        }

        // Generate: [@MainActor] [access] [static] let <name>Family = NotifierProvider.family { ... }
        let familyDecl: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)\(raw: staticKeyword)let \(raw: familyName) = NotifierProvider.family { (arg: \(raw: argType)) in
            \(raw: className)()
        }
        """

        return [familyDecl]
    }
}
