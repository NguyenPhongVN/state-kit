import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @ProviderFamily: Declares a family of read-only synchronous providers keyed by an argument.
///
/// Attached to a function that receives a `ProviderRef` + one or more key parameters and
/// returns a value. Generates a peer `let` initialized with `Provider.family { ... }`.
///
/// ## Generated Members
/// - `let <functionName>Provider = Provider.family { ... }` — a peer constant at the same scope.
///
/// ## User Requirements
/// - The function must accept `ProviderRef` as a parameter (typically first).
/// - The remaining parameters define the family key(s).
/// - The return type must be concrete (not `some` opaque type).
///
/// ## Behavior
/// - `static` propagates from the annotated function to the generated constant.
/// - Access level propagates from the function to the generated constant.
/// - Opaque return types (`some`) are rejected with a descriptive error.
public struct ProviderFamilyMacro: PeerMacro {
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

        // Validate that the return type is concrete (not opaque/some)
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }
        let returnTypeDescription = returnType.trimmedDescription
        guard !returnTypeDescription.hasPrefix("some ") else {
            throw MacroError.custom("Method '\(functionName)' returns an opaque type ('some') — providers require a concrete return type")
        }

        // Extract all parameters preserving labels and types
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

        let paramList = paramDecls.joined(separator: ", ")
        let argList = callArgs.joined(separator: ", ")

        if isNested {
            let providerDecl: DeclSyntax = """
            @MainActor
            \(raw: accessPrefix)\(raw: staticKeyword)let \(raw: providerName) = Provider.family { (\(raw: paramList)) -> \(raw: returnTypeDescription) in
                \(raw: functionName)(\(raw: argList))
            }
            """
            return [providerDecl]
        } else {
            let providerDecl: DeclSyntax = """
            extension RProvider {
                @MainActor \(raw: accessPrefix)static let \(raw: providerName) = Provider.family { (\(raw: paramList)) -> \(raw: returnTypeDescription) in
                    \(raw: functionName)(\(raw: argList))
                }
            }
            """
            return [providerDecl]
        }
    }
}
