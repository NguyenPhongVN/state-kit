import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @Provider: Declares a read-only synchronous provider.
///
/// Attached to a function that receives `ProviderRef` and returns a value.
/// Generates a peer `let` constant initialized with `Provider { ... }` that
/// delegates to the annotated function.
///
/// ## Generated Members
/// - `let <functionName>Provider = Provider { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must accept `ProviderRef` as its first parameter.
/// - The return type must be concrete (not `some` opaque type).
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
/// - Opaque return types (`some`) are rejected with a descriptive error.
public struct ProviderMacro: PeerMacro {
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

        // Extract access level and static from the function's modifiers
        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: funcDecl)

        // Validate that the return type is concrete (not opaque/some)
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }
        let returnTypeDescription = returnType.trimmedDescription
        guard !returnTypeDescription.hasPrefix("some ") else {
            throw MacroError.custom("Method '\(functionName)' returns an opaque type ('some') — providers require a concrete return type")
        }

        // Extract parameters to preserve labels and types in the closure signature
        var paramDecls: [String] = []
        var callArgs: [String] = []

        for param in funcDecl.signature.parameterClause.parameters {
            let typeStr = param.type.trimmedDescription
            let label = param.firstName.text
            let internalName = param.secondName?.text ?? label

            paramDecls.append("\(label): \(typeStr)")

            if label == "_" {
                callArgs.append(internalName)
            } else {
                callArgs.append("\(label): \(internalName)")
            }
        }

        let paramList = paramDecls.isEmpty ? "ref" : paramDecls.joined(separator: ", ")
        let argList = callArgs.isEmpty ? "ref" : callArgs.joined(separator: ", ")

        // Generate: @MainActor [access] [static] let <name>Provider = Provider { ... }
        let providerDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = Provider { (\(raw: paramList)) -> \(raw: returnTypeDescription) in
            \(raw: functionName)(\(raw: argList))
        }
        """

        return [providerDecl]
    }
}
