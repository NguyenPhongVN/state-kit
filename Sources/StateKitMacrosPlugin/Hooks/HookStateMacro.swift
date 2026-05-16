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

        let properties = PropertyExtractor.storedVars(from: structDecl)
        guard !properties.isEmpty else {
            throw MacroError.methodNotFound("stored properties")
        }

        let structName = structDecl.name.text
        let hookName = "use" + structName

        var returnTupleElements: [String] = []
        var functionBody: [String] = []

        for prop in properties {
            let propName = prop.name
            let defaultVal = prop.defaultValue ?? "nil"

            returnTupleElements.append("\(propName): Binding<\(prop.typeName)>")
            functionBody.append("    \(propName): useBinding(\(defaultVal))")
        }

        let returnTuple = "(" + returnTupleElements.joined(separator: ", ") + ")"
        let bodyContent = "(\n" + functionBody.joined(separator: ",\n") + "\n    )"

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)() -> \(raw: returnTuple) {
            return \(raw: bodyContent)
        }
        """

        return [hookFunction]
    }
}
