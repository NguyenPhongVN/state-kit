import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// HookToggleMacro: @attached(peer, names: prefixed(use))
//
// Generates a peer function named "use<StructName>" that returns a
// (Bool, () -> Void) tuple: the current toggle value + a closure that
// flips it.
//
// Unlike HookRef/HookState, HookToggle ignores stored properties.
// The struct serves purely as a namespace anchor for the generated name.
//
// ── Example ──────────────────────────────────────────────────────────
//   @HookToggle struct EditMode {}
//
// Expands to:
//   struct EditMode {}
//
//   @MainActor
//   func useEditMode() -> (Bool, () -> Void) {
//       let (value, setValue) = StateKit.useState(false)
//       let toggle = { setValue(!value) }
//       return (value, toggle)
//   }
//
// Usage:
//   let (isEditing, toggle) = useEditMode()
//   toggle()           // isEditing → true
//   toggle()           // isEditing → false

public struct HookToggleMacro: PeerMacro {
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

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: accessPrefix)\(raw: staticKeyword)func \(raw: funcName)() -> (Bool, () -> Void) {
            let (value, setValue) = StateKit.useState(false)
            let toggle = {
                setValue(!value)
            }
            return (value, toggle)
        }
        """

        return [hookDecl]
    }
}
