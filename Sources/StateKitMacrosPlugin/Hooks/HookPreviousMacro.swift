import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookPreviousMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        guard properties.count == 1 else {
            throw MacroError.custom("HookPrevious requires exactly one stored property")
        }

        let prop = properties[0]
        let className = structDecl.name.text
        let hookName = "use" + className
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        let hookDecl: DeclSyntax = """
        @MainActor
        \(raw: staticKeyword)func \(raw: hookName)(\(raw: prop.name): \(raw: prop.typeName)) -> \(raw: prop.typeName)? {
            let ref = useRef(\(raw: prop.typeName)?.none)
            let previous = ref.value
            useEffect(updateStrategy: .preserved(by: \(raw: prop.name))) {
                ref.value = \(raw: prop.name)
                return nil
            }
            return previous
        }
        """

        return [hookDecl]
    }
}
