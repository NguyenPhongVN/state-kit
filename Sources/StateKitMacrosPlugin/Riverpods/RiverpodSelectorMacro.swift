import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodSelector: Declares a read-only selected/dependent provider.
///
/// Attached to a function that takes `ProviderRef` and returns a derived value.
/// Generates a peer `let` initialized with `Provider(<functionName>)` — a direct
/// reference-style provider that re-evaluates when its dependencies change.
///
/// ## Generated Members
/// - `let <functionName>Provider = Provider(<functionName>)` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must accept `ProviderRef` as its first parameter.
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
public struct RiverpodSelectorMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only apply to functions
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let functionName = funcDecl.name.text
        let providerName = functionName + "Provider"

        // Extract access level from the function's modifiers
        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: funcDecl)

        let isNested = context.lexicalContext.count > 0

        if isNested {
            let providerDecl: DeclSyntax = """
            @MainActor
            \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = Provider(\(raw: functionName))
            """
            return [providerDecl]
        } else {
            let providerDecl: DeclSyntax = """
            extension RProvider {
                @MainActor \(raw: accessPrefix)static let \(raw: providerName) = Provider(\(raw: functionName))
            }
            """
            return [providerDecl]
        }
    }
}
