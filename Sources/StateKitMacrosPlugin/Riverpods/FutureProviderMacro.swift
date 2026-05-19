import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @FutureProvider: Declares an async provider that produces a single value.
///
/// Attached to an `async` function. Generates a peer `let` initialized with
/// `FutureProvider { ... }` that calls the annotated function with `await`.
///
/// ## Generated Members
/// - `let <functionName>Provider = FutureProvider { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must be marked `async`.
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
public struct FutureProviderMacro: PeerMacro {
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

        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let tryKeyword = isThrowing ? "try " : ""

        let isNested = context.lexicalContext.count > 0

        if isNested {
            let providerDecl: DeclSyntax = """
            @MainActor
            \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = FutureProvider { _ in
                \(raw: tryKeyword)await \(raw: functionName)()
            }
            """
            return [providerDecl]
        } else {
            let providerDecl: DeclSyntax = """
            extension RProvider {
                @MainActor \(raw: accessPrefix)static let \(raw: providerName) = FutureProvider { _ in
                    \(raw: tryKeyword)await \(raw: functionName)()
                }
            }
            """
            return [providerDecl]
        }
    }
}
