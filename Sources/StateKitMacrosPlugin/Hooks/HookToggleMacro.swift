import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @HookToggle: Simple boolean toggle helper
/// Generates a hook that returns (value, toggle) for boolean state
public struct HookToggleMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let structName = structDecl.name.text
        let hookName = "use" + structName

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)() -> (Bool, () -> Void) {
            let (value, setValue) = useState(false)
            let toggle = { setValue(!value) }
            return (value, toggle)
        }
        """

        return [hookFunction]
    }
}
