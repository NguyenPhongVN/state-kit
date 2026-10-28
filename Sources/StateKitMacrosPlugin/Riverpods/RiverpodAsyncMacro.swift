import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodAsync: Declares an async provider with automatic `ProviderRef` passing.
///
/// Attached to an `async` function. Generates a peer `let` initialized with
/// `FutureProvider { ref in ... }` that delegates to the annotated function.
/// Unlike @FutureProvider, this macro passes `ref` to the function call.
///
/// ## Generated Members
/// - `let <functionName>Provider = FutureProvider { ref in ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must be marked `async`.
/// - The function should not take a `ProviderRef` parameter (ref is injected by the closure).
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
/// - Supports `throws` — the generated code prepends `try` when the function is throwing.
public struct RiverpodAsyncMacro: PeerMacro {
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
        // Overload-safe generated name: `fetch()` and `fetch(id:)` both became
        // `fetchProvider` and collided. Zero-parameter functions keep the bare
        // `xProvider` name (docs and existing code); parameterized ones gain an
        // arity suffix (`fetchProvider1`) so overloads disambiguate.
        // The framework-provided `ref: ProviderRef` is not a user parameter:
        // `currentHeader(ref:)` stays `currentHeaderProvider`.
        let arity = funcDecl.signature.parameterClause.parameters.filter {
            !$0.type.trimmedDescription.contains("ProviderRef")
        }.count
        let providerName = arity == 0
            ? functionName + "Provider"
            : functionName + "Provider" + String(arity)

        // Extract access level from the function's modifiers
        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: funcDecl)

        let isNested = context.lexicalContext.count > 0

        // Check if the function is throwing — need to prepend try if so
        let tryKeyword = funcDecl.signature.effectSpecifiers?.throwsClause != nil ? "try " : ""

        if isNested {
            let asyncProvider: DeclSyntax = """
            @MainActor
            \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = FutureProvider { ref in
                \(raw: tryKeyword)await \(raw: functionName)()
            }
            """
            return [asyncProvider]
        } else {
            let asyncProvider: DeclSyntax = """
            extension RProvider {
                @MainActor \(raw: accessPrefix)static let \(raw: providerName) = FutureProvider { ref in
                    \(raw: tryKeyword)await \(raw: functionName)()
                }
            }
            """
            return [asyncProvider]
        }
    }
}
