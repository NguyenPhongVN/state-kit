import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Validates that `@Hook` is applied to a function whose name starts with `use`.
/// Generates no additional code — purely a compile-time validation marker.
public struct CheckHookFunctionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToFunctions
        }

        let funcName = funcDecl.name.text

        guard funcName.hasPrefix("use") && funcName.count > 3 else {
            throw MacroError.invalidHookName(funcName)
        }

        return []
    }
}
