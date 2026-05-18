import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @RiverpodStreamFamily: Declares a family of streaming providers keyed by a parameter.
///
/// Attached to a function returning a publisher, whose first non-`ProviderRef` parameter
/// acts as the family key. Generates a peer `let` initialized with `StreamProvider.family`.
///
/// ## Generated Members
/// - `let <functionName>Family = StreamProvider.family { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must return a publisher type (e.g. `AnyPublisher<T, E>`).
/// - At least one non-`ProviderRef` parameter to serve as the family key.
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
/// - The first non-`ProviderRef` parameter is used as the family key; its type is inferred
///   and the generated closure passes it as `arg`.
public struct RiverpodStreamFamilyMacro: PeerMacro {
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
        let familyName = functionName + "Family"

        // Extract access level and static from the function's modifiers
        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: funcDecl)

        // Find the first non-ProviderRef parameter — that's the family key
        guard let keyParam = funcDecl.signature.parameterClause.parameters.first(where: { $0.type.trimmedDescription != "ProviderRef" }) else {
            throw MacroError.custom("@RiverpodStreamFamily requires at least one non-ProviderRef parameter to serve as the family key")
        }
        let argType = keyParam.type.trimmedDescription
        let argName = keyParam.firstName.text

        // Generate: @MainActor [access] [static] let <name>Family = StreamProvider.family { ... }
        let familyDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: familyName) = StreamProvider.family { (ref: ProviderRef, arg: \(raw: argType)) in
            \(raw: functionName)(\(raw: argName): arg)
        }
        """

        return [familyDecl]
    }
}
