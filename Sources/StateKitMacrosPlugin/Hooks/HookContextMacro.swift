import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookContextMacro: @attached(peer, names: prefixed(use), named(_hookContext))
//
// Generates TWO peer declarations:
//   1. A static let `_hookContext` – a StateKit.HookContext instance.
//   2. A function `use<StructName>()` that reads the context via useContext().
//
// The struct's stored properties define the default context value.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookContext struct AppInfo {
//       var version: String = "1.0"
//   }
//
// Expands to:
//   struct AppInfo { var version: String = "1.0" }
//
//   @MainActor
//   static let _hookContext = StateKit.HookContext<AppInfo>(AppInfo())
//
//   @MainActor
//   func useAppInfo() -> AppInfo {
//       useContext(_hookContext)
//   }
//
// Usage:
//   let info = useAppInfo()
//   // Or override the context value higher in the tree via HookContext's API.

public struct HookContextMacro: PeerMacro {
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

        let contextInstanceDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)let _hookContext = StateKit.HookContext<\(raw: className)>(\(raw: className)())
        """

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> \(raw: className) {
            useContext(_hookContext)
        }
        """

        return [contextInstanceDecl, hookDecl]
    }
}
