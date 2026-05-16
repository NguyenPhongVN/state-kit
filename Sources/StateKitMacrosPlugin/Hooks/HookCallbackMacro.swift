import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HookCallbackMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStructs
        }

        let callFn = PropertyExtractor.function(in: structDecl, named: "call")
            ?? PropertyExtractor.function(in: structDecl, named: "handle")

        guard let callFn = callFn else {
            throw MacroError.methodNotFound("call() or handle() method")
        }

        guard let returnType = callFn.signature.returnClause?.type else {
            throw MacroError.invalidReturnType
        }

        let properties = PropertyExtractor.storedProperties(from: structDecl)
        let structName = structDecl.name.text
        let hookName = "use" + structName + "Callback"
        let methodName = callFn.name.text

        var paramList: [String] = []
        var depsList: [String] = []
        var instanceInit: [String] = []

        for prop in properties {
            paramList.append("\(prop.name): \(prop.typeName)")
            depsList.append(prop.name)
            instanceInit.append("    \(prop.name): \(prop.name)")
        }

        let params = paramList.joined(separator: ", ")
        let deps = depsList.isEmpty ? ".once" : ".preserved(by: \(depsList.joined(separator: ", ")))"
        let initCode = instanceInit.isEmpty ? "()" : "(\n" + instanceInit.joined(separator: ",\n") + "\n    )"

        let hookFunction: DeclSyntax = """
        @MainActor
        public func \(raw: hookName)(\(raw: params)) -> \(returnType) {
            useCallback(updateStrategy: \(raw: deps)) {
                \(raw: structName)\(raw: initCode).\(raw: methodName)
            }
        }
        """

        return [hookFunction]
    }
}
