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

        // Propagate access level from the struct to the generated constant
        let accessPrefix = AttributeHelper.accessLevel(from: structDecl)

        // Check if the struct is nested inside another type
        let isNested = context.lexicalContext.count > 0

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

        // Generate extension (file scope) or static let member (nested)
        if isNested {
            let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: structDecl) ? "" : "@MainActor\n"
            let providerDecl: DeclSyntax = """
            \(raw: mainActorAttr)\(raw: accessPrefix)static let \(raw: className)Provider = StateProvider { _ in
                \(raw: initialValue)
            }
            """
            return [providerDecl]
        } else {
            let mainActorAttr = AttributeHelper.hasAttribute("MainActor", on: structDecl) ? "" : "@MainActor "
            let providerDecl: DeclSyntax = """
            extension \(raw: className) {
                \(raw: mainActorAttr)\(raw: accessPrefix)static let provider = StateProvider { _ in
                    \(raw: initialValue)
                }
            }
            """
            return [providerDecl]
        }
    }
}
