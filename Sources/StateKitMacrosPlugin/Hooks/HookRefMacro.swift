import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookRefMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        let className = structDecl.name.text
        let hookName = "use" + className
        
        let modifiers = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers
        let isStatic = modifiers?.contains { $0.name.text == "static" } ?? false
        let staticKeyword = isStatic ? "static " : ""

        if properties.count == 1 {
            let prop = properties[0]
            let initialValue = prop.defaultValue ?? "\(prop.typeName)()"
            let hookDecl: DeclSyntax = """
            @MainActor
            \(raw: staticKeyword)func \(raw: hookName)() -> StateKit.StateRef<\(raw: prop.typeName)> {
                return useRef(\(raw: initialValue))
            }
            """
            return [hookDecl]
        } else {
            let hookDecl: DeclSyntax = """
            @MainActor
            \(raw: staticKeyword)func \(raw: hookName)() -> (\(raw: properties.map { "StateKit.StateRef<\($0.typeName)>" }.joined(separator: ", "))) {
                return (\(raw: properties.map { "useRef(\($0.defaultValue ?? "\($0.typeName)()") )" }.joined(separator: ", ")))
            }
            """
            return [hookDecl]
        }
    }
}
