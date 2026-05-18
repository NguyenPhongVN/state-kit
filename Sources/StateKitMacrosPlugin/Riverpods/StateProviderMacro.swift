import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @StateProvider: Declares a read-write state provider backed by a struct's initial value.
///
/// Attached to a struct with an `initial` property. Generates a peer `let` initialized
/// with `StateProvider { ... }` that returns the struct's initial value.
///
/// ## Generated Members
/// - `let <StructName>Provider = StateProvider { _ in <initial> }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The struct must have a property `initial` that provides the default state value.
///
/// ## Behavior
/// - Access level propagates from the struct to the generated constant (via `AttributeHelper.accessLevel(from:)`).
/// - `@MainActor` is automatically added unless the struct already has it.
/// - If the struct is nested inside another type, the generated constant is marked `static`.
public struct StateProviderMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only apply to structs
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let providerName = className + "Provider"

        // Propagate access level from the struct to the generated constant
        let accessPrefix = AttributeHelper.accessLevel(from: structDecl)

        // Determine if the generated constant needs `static` (nested types do)
        let isNested = context.lexicalContext.count > 0
        let staticKeyword = isNested ? "static " : ""

        // Only add @MainActor prefix if the struct itself doesn't already have it
        let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: structDecl) ? "" : "@MainActor\n"

        // Extract the initial value expression from the struct's `initial` property
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

        // Generate: [@MainActor] [access] [static] let <name>Provider = StateProvider { _ in ... }
        let providerDecl: DeclSyntax = """
        \(raw: mainActorAttr)\(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = StateProvider { _ in
            \(raw: initialValue)
        }
        """

        return [providerDecl]
    }
}
