import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookStateMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.methodNotFound("stored properties")
        }

        let structName = structDecl.name.text
        let hookName = "use" + structName

        let isStatic = structDecl.modifiers.contains(where: { $0.name.text == "static" })
        let staticModifier = isStatic ? "static " : ""

        var returnTupleElements: [String] = []
        var functionBody: [String] = []

        for prop in properties {
            let propName = prop.name
            let defaultVal = prop.defaultValue ?? "nil"

            returnTupleElements.append("\(propName): Binding<\(prop.typeName)>")
            functionBody.append("            \(propName): useBinding(\(defaultVal))")
        }

        let hookFunction: DeclSyntax
        if properties.count == 1 {
            let prop = properties[0]
            let defaultVal = prop.defaultValue ?? "nil"
            hookFunction = """
            @MainActor
            \(raw: staticModifier)func \(raw: hookName)() -> Binding<\(raw: prop.typeName)> {
                return useBinding(\(raw: defaultVal))
            }
            """
        } else {
            let returnTuple = "(" + returnTupleElements.joined(separator: ", ") + ")"
            let bodyContent = "(\n" + functionBody.joined(separator: ",\n") + "\n        )"

            hookFunction = """
            @MainActor
            \(raw: staticModifier)func \(raw: hookName)() -> \(raw: returnTuple) {
                return \(raw: bodyContent)
            }
            """
        }

        return [hookFunction]
    }
}
