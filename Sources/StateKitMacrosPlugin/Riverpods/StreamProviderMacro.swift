import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @StreamProvider: Declares a streaming provider from a publisher-returning function.
///
/// Attached to a synchronous function that returns a publisher (e.g. `AnyPublisher`).
/// Generates a peer `let` initialized with `StreamProvider { ... }` that calls the
/// annotated function.
///
/// ## Generated Members
/// - `let <functionName>Provider = StreamProvider { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must return a publisher type (e.g. `AnyPublisher<T, E>`).
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
public struct StreamProviderMacro: PeerMacro {
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
            \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = StreamProvider { _ in
                \(raw: functionName)()
            }
            """
            return [providerDecl]
        } else {
            let providerDecl: DeclSyntax = """
            extension RProvider {
                @MainActor \(raw: accessPrefix)static let \(raw: providerName) = StreamProvider { _ in
                    \(raw: functionName)()
                }
            }
            """
            return [providerDecl]
        }
    }
}
