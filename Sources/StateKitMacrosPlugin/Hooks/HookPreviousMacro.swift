import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @HookPrevious: Tracks the previous value of a state
/// Useful for animations, comparisons, and detecting changes
public struct HookPreviousMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedVars(from: structDecl)
        let structName = structDecl.name.text
        let hookName = "use" + structName

        guard !properties.isEmpty else {
            throw MacroError.custom("@HookPrevious requires at least one stored property (the value to track)")
        }

        let prop = properties[0]
        let paramList = "\(prop.name): \(prop.typeName)"

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: paramList)) -> \(raw: prop.typeName)? {
            let ref = useRef(\(raw: prop.typeName)?.none)
            let previous = ref.value
            useEffect(updateStrategy: .preserved(by: \(raw: prop.name))) {
                ref.value = \(raw: prop.name)
                return nil
            }
            return previous
        }
        """

        return [hookFunction]
    }
}
