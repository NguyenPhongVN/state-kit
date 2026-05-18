import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookMemoMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that wraps useMemo().
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookMemo struct Title {
//       func compute() -> String { "Dashboard" }
//   }
//
// Expands to:
//   struct Title { func compute() -> String { "Dashboard" } }
//
//   @MainActor
//   func useTitle() -> String {
//       StateKit.useMemo(updateStrategy: .once) {
//           Title().compute()
//       }
//   }
//
// Usage:
//   let title = useTitle()   // "Dashboard", cached via useMemo

public struct HookMemoMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let className = structDecl.name.text
        let funcName = "use" + className

        let (accessPrefix, staticKeyword) = AttributeHelper.modifierPrefixes(from: structDecl)

        // Extract return type from the compute() method.
        var returnType = "Any"
        for member in structDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self), funcDecl.name.text == "compute" {
                if let type = funcDecl.signature.returnClause?.type {
                    returnType = type.trimmedDescription
                }
            }
        }

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> \(raw: returnType) {
            StateKit.useMemo(updateStrategy: .once) {
                \(raw: className)().compute()
            }
        }
        """
        return [hookDecl]
    }
}
